import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

const mapTileMaxAge = Duration(days: 30);
const mapTileMaxBytes = 200 * 1024 * 1024;

class MapTileRecord {
  const MapTileRecord({
    required this.z,
    required this.x,
    required this.y,
    required this.layerId,
    required this.bytes,
    required this.fetchedAt,
    this.etag,
  });

  final int z;
  final int x;
  final int y;
  final String layerId;
  final Uint8List bytes;
  final DateTime fetchedAt;
  final String? etag;

  bool get isStale => DateTime.now().difference(fetchedAt) > mapTileMaxAge;
}

abstract interface class TileCache {
  Future<MapTileRecord?> get({
    required int z,
    required int x,
    required int y,
    required String layerId,
  });

  Future<void> put(MapTileRecord tile);

  Future<void> evictOlderThan(DateTime cutoff);

  Future<int> totalBytes();

  Future<void> clear();
}

class MapTileStore implements TileCache {
  MapTileStore({this.databasePath});
  final String? databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final path = databasePath ??
        p.join(await sqflite.getDatabasesPath(), 'warang_map_tiles.sqlite');
    return _database ??= await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tiles (
            z INTEGER NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            layerId TEXT NOT NULL,
            bytes BLOB NOT NULL,
            fetchedAt INTEGER NOT NULL,
            etag TEXT,
            PRIMARY KEY (z, x, y, layerId)
          )
        ''');
        await db.execute(
          'CREATE INDEX tiles_fetched_at ON tiles (fetchedAt)',
        );
      },
    );
  }

  @override
  Future<MapTileRecord?> get({
    required int z,
    required int x,
    required int y,
    required String layerId,
  }) async {
    final rows = await (await _db).query(
      'tiles',
      where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
      whereArgs: [z, x, y, layerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return MapTileRecord(
      z: row['z']! as int,
      x: row['x']! as int,
      y: row['y']! as int,
      layerId: row['layerId']! as String,
      bytes: Uint8List.fromList((row['bytes']! as List<int>)),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetchedAt']! as int),
      etag: row['etag'] as String?,
    );
  }

  @override
  Future<void> put(MapTileRecord tile) async {
    await (await _db).insert(
      'tiles',
      {
        'z': tile.z,
        'x': tile.x,
        'y': tile.y,
        'layerId': tile.layerId,
        'bytes': tile.bytes,
        'fetchedAt': tile.fetchedAt.millisecondsSinceEpoch,
        'etag': tile.etag,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
    await evictToLimit(mapTileMaxBytes);
  }

  @override
  Future<void> evictOlderThan(DateTime cutoff) async {
    await (await _db).delete(
      'tiles',
      where: 'fetchedAt < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<void> evictToLimit(int maxBytes) async {
    final db = await _db;
    final total = await totalBytes();
    if (total <= maxBytes) return;
    final rows = await db.query(
      'tiles',
      columns: ['z', 'x', 'y', 'layerId', 'bytes'],
      orderBy: 'fetchedAt ASC',
    );
    var remaining = total;
    for (final row in rows) {
      if (remaining <= maxBytes) break;
      final bytes = (row['bytes']! as List<int>).length;
      await db.delete(
        'tiles',
        where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
        whereArgs: [row['z'], row['x'], row['y'], row['layerId']],
      );
      remaining -= bytes;
    }
  }

  @override
  Future<int> totalBytes() async {
    final rows = await (await _db).rawQuery(
      'SELECT COALESCE(SUM(length(bytes)), 0) AS total FROM tiles',
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> clear() async => (await _db).delete('tiles');

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}

class CachedTileProvider extends TileProvider {
  CachedTileProvider({
    required this.store,
    required this.layerId,
    this.client,
    super.headers,
  });

  final TileCache store;
  final String layerId;
  final HttpClient? client;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      provider: this,
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
      url: getTileUrl(coordinates, options),
    );
  }

  Future<Uint8List> loadBytes({
    required int z,
    required int x,
    required int y,
    required String url,
  }) async {
    final cached = await store.get(z: z, x: x, y: y, layerId: layerId);
    if (cached != null) {
      unawaited(_revalidate(z: z, x: x, y: y, url: url, cached: cached));
      return cached.bytes;
    }
    try {
      return await _fetchAndStore(z: z, x: x, y: y, url: url, cached: null);
    } catch (_) {
      return _placeholderBytes;
    }
  }

  Future<void> _revalidate({
    required int z,
    required int x,
    required int y,
    required String url,
    required MapTileRecord cached,
  }) async {
    try {
      await _fetchAndStore(z: z, x: x, y: y, url: url, cached: cached);
    } catch (_) {
      // Stale bytes remain available when the device is offline.
    }
  }

  Future<Uint8List> _fetchAndStore({
    required int z,
    required int x,
    required int y,
    required String url,
    required MapTileRecord? cached,
  }) async {
    final httpClient = client ?? HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      headers.forEach(request.headers.set);
      if (cached?.etag != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, cached!.etag!);
      }
      final response = await request.close();
      if (response.statusCode == HttpStatus.notModified && cached != null) {
        await store.put(
          MapTileRecord(
            z: z,
            x: x,
            y: y,
            layerId: layerId,
            bytes: cached.bytes,
            fetchedAt: DateTime.now(),
            etag: cached.etag,
          ),
        );
        return cached.bytes;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Tile request failed: ${response.statusCode}');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      await store.put(
        MapTileRecord(
          z: z,
          x: x,
          y: y,
          layerId: layerId,
          bytes: bytes,
          fetchedAt: DateTime.now(),
          etag: response.headers.value(HttpHeaders.etagHeader),
        ),
      );
      return bytes;
    } finally {
      if (client == null) httpClient.close(force: true);
    }
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({
    required this.provider,
    required this.z,
    required this.x,
    required this.y,
    required this.url,
  });

  final CachedTileProvider provider;
  final int z;
  final int x;
  final int y;
  final String url;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: provider
          .loadBytes(z: z, x: x, y: y, url: url)
          .then((bytes) => ImmutableBuffer.fromUint8List(bytes))
          .then(decode),
      scale: 1,
      debugLabel: url,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage &&
      other.provider.layerId == provider.layerId &&
      other.z == z &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(provider.layerId, z, x, y);
}

final _placeholderBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/9B1sVwAAAABJRU5ErkJggg==',
  ),
);
