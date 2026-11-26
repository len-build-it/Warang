import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

const mapTileMaxAge = Duration(days: 30);
const mapTileMaxBytes = 200 * 1024 * 1024;
const _tileAccessTouchInterval = Duration(days: 1);
const _tileConnectTimeout = Duration(seconds: 10);
const _tileRequestTimeout = Duration(seconds: 15);

/// Slippy-map Web Mercator tile coordinates for [point] at zoom [z].
({int x, int y}) tileCoordsForLatLng(LatLng point, int z) {
  final n = 1 << z;
  final latRad = point.latitude * math.pi / 180.0;
  final x = ((point.longitude + 180.0) / 360.0 * n).floor().clamp(0, n - 1);
  final y =
      ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
              2.0 *
              n)
          .floor()
          .clamp(0, n - 1);
  return (x: x, y: y);
}

class MapTileRecord {
  const MapTileRecord({
    required this.z,
    required this.x,
    required this.y,
    required this.layerId,
    required this.bytes,
    required this.fetchedAt,
    this.lastAccessedAt,
    this.etag,
  });

  final int z;
  final int x;
  final int y;
  final String layerId;
  final Uint8List bytes;
  final DateTime fetchedAt;
  final DateTime? lastAccessedAt;
  final String? etag;

  bool get isStale => DateTime.now().difference(fetchedAt) >= mapTileMaxAge;
}

class MapTileStore {
  MapTileStore({this.databasePath});
  final String? databasePath;
  sqflite.Database? _database;
  Future<sqflite.Database>? _opening;
  Future<void>? _evicting;

  bool _closed = false;

  Future<sqflite.Database> get _db {
    if (_closed) {
      return Future.error(StateError('MapTileStore is closed'));
    }
    final existing = _database;
    if (existing != null && existing.isOpen) return Future.value(existing);
    return _opening ??= _open();
  }

  Future<sqflite.Database> _open() async {
    try {
      final path =
          databasePath ??
          p.join(await sqflite.getDatabasesPath(), 'warang_map_tiles.sqlite');
      return _database = await sqflite.openDatabase(
        path,
        singleInstance: false,
        onOpen: (db) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tiles (
              z INTEGER NOT NULL,
              x INTEGER NOT NULL,
              y INTEGER NOT NULL,
              layerId TEXT NOT NULL,
              bytes BLOB NOT NULL,
              fetchedAt INTEGER NOT NULL,
              lastAccessedAt INTEGER,
              etag TEXT,
              PRIMARY KEY (z, x, y, layerId)
            )
          ''');
          final columns = await db.rawQuery('PRAGMA table_info(tiles)');
          final hasLastAccessed = columns.any(
            (col) => col['name'] == 'lastAccessedAt',
          );
          if (!hasLastAccessed) {
            await db.execute(
              'ALTER TABLE tiles ADD COLUMN lastAccessedAt INTEGER',
            );
            await db.execute('UPDATE tiles SET lastAccessedAt = fetchedAt');
          }
          await db.execute(
            'CREATE INDEX IF NOT EXISTS tiles_fetched_at ON tiles (fetchedAt)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS tiles_last_accessed_at '
            'ON tiles (lastAccessedAt)',
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS map_camera (
              id INTEGER PRIMARY KEY,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              zoom REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS map_location (
              id INTEGER PRIMARY KEY,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL,
              updatedAt INTEGER NOT NULL
            )
          ''');
        },
      );
    } finally {
      _opening = null;
    }
  }

  Future<bool> hasTile(
    int z,
    int x,
    int y, {
    String layerId = 'osm-standard',
  }) async {
    if (_closed) return false;
    try {
      final rows = await (await _db).query(
        'tiles',
        columns: const ['z'],
        where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
        whereArgs: [z, x, y, layerId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } on Exception catch (e) {
      if (!_closed && kDebugMode) debugPrint('MapTileStore.hasTile failed: $e');
      return false;
    }
  }

  Future<MapTileRecord?> get({
    required int z,
    required int x,
    required int y,
    required String layerId,
  }) async {
    if (_closed) return null;
    try {
      final db = await _db;
      final rows = await db.query(
        'tiles',
        where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
        whereArgs: [z, x, y, layerId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      if (row case {
        'z': final int tileZ,
        'x': final int tileX,
        'y': final int tileY,
        'layerId': final String tileLayerId,
        'bytes': final List<int> rawBytes,
        'fetchedAt': final int fetchedMs,
      }) {
        final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedMs);
        final lastAccessedMs = row['lastAccessedAt'] as int?;
        final lastAccessedAt = lastAccessedMs == null
            ? fetchedAt
            : DateTime.fromMillisecondsSinceEpoch(lastAccessedMs);
        final now = DateTime.now();
        if (lastAccessedMs == null ||
            now.difference(lastAccessedAt) > _tileAccessTouchInterval) {
          unawaited(
            _touchLastAccessed(
              db,
              z: tileZ,
              x: tileX,
              y: tileY,
              layerId: tileLayerId,
              at: now,
            ),
          );
        }
        return MapTileRecord(
          z: tileZ,
          x: tileX,
          y: tileY,
          layerId: tileLayerId,
          bytes: Uint8List.fromList(rawBytes),
          fetchedAt: fetchedAt,
          lastAccessedAt: lastAccessedAt,
          etag: row['etag'] as String?,
        );
      }
      return null;
    } on Exception catch (e) {
      if (!_closed && kDebugMode) debugPrint('MapTileStore.get failed: $e');
      return null;
    }
  }

  Future<void> _touchLastAccessed(
    sqflite.Database db, {
    required int z,
    required int x,
    required int y,
    required String layerId,
    required DateTime at,
  }) async {
    if (_closed || !db.isOpen) return;
    try {
      await db.update(
        'tiles',
        {'lastAccessedAt': at.millisecondsSinceEpoch},
        where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
        whereArgs: [z, x, y, layerId],
      );
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('MapTileStore._touchLastAccessed failed: $e');
    }
  }

  Future<void> put(MapTileRecord tile) async {
    final fetchedMs = tile.fetchedAt.millisecondsSinceEpoch;
    final accessedMs =
        (tile.lastAccessedAt ?? tile.fetchedAt).millisecondsSinceEpoch;
    await (await _db).insert('tiles', {
      'z': tile.z,
      'x': tile.x,
      'y': tile.y,
      'layerId': tile.layerId,
      'bytes': tile.bytes,
      'fetchedAt': fetchedMs,
      'lastAccessedAt': accessedMs,
      'etag': tile.etag,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    await evictToLimit(mapTileMaxBytes);
  }

  Future<void> refreshMetadata({
    required int z,
    required int x,
    required int y,
    required String layerId,
    required DateTime fetchedAt,
    String? etag,
  }) async {
    if (_closed) return;
    final ms = fetchedAt.millisecondsSinceEpoch;
    await (await _db).update(
      'tiles',
      {'fetchedAt': ms, 'lastAccessedAt': ms, 'etag': etag},
      where: 'z = ? AND x = ? AND y = ? AND layerId = ?',
      whereArgs: [z, x, y, layerId],
    );
  }

  Future<void> evictToLimit(int maxBytes) async {
    final pending = _evicting;
    if (pending != null) {
      await pending;
    }
    final task = _evictToLimitSerialized(maxBytes);
    _evicting = task;
    try {
      await task;
    } finally {
      if (identical(_evicting, task)) {
        _evicting = null;
      }
    }
  }

  Future<void> _evictToLimitSerialized(int maxBytes) async {
    if (_closed) return;
    final db = await _db;
    await db.transaction((txn) async {
      final totalRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(length(bytes)), 0) AS total FROM tiles',
      );
      var remaining = (totalRows.single['total'] as num?)?.toInt() ?? 0;
      if (remaining <= maxBytes) return;
      final rows = await txn.rawQuery(
        'SELECT rowid, length(bytes) AS size FROM tiles '
        'ORDER BY COALESCE(lastAccessedAt, fetchedAt) ASC, fetchedAt ASC',
      );
      for (final row in rows) {
        if (remaining <= maxBytes) break;
        await txn.delete(
          'tiles',
          where: 'rowid = ?',
          whereArgs: [row['rowid']],
        );
        remaining -= (row['size'] as num?)?.toInt() ?? 0;
      }
    });
  }

  Future<int> totalBytes() async {
    final rows = await (await _db).rawQuery(
      'SELECT COALESCE(SUM(length(bytes)), 0) AS total FROM tiles',
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> clear() async => (await _db).delete('tiles');

  Future<MapCameraSnapshot?> loadCamera() async {
    if (_closed) return null;
    try {
      final rows = await (await _db).query('map_camera', limit: 1);
      if (rows.isEmpty) return null;
      final row = rows.single;
      if (row case {
        'latitude': final num lat,
        'longitude': final num lon,
        'zoom': final num zoom,
      }) {
        return MapCameraSnapshot(
          center: LatLng(lat.toDouble(), lon.toDouble()),
          zoom: zoom.toDouble(),
        );
      }
      return null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('MapTileStore.loadCamera failed: $e');
      return null;
    }
  }

  Future<void> saveCamera(LatLng center, double zoom) async {
    if (_closed) return;
    try {
      await (await _db).insert('map_camera', {
        'id': 1,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': zoom,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('MapTileStore.saveCamera failed: $e');
    }
  }

  Future<MapLocationSnapshot?> loadLocation() async {
    if (_closed) return null;
    try {
      final rows = await (await _db).query('map_location', limit: 1);
      if (rows.isEmpty) return null;
      final row = rows.single;
      if (row case {
        'latitude': final num lat,
        'longitude': final num lon,
        'updatedAt': final int updatedMs,
      }) {
        return MapLocationSnapshot(
          center: LatLng(lat.toDouble(), lon.toDouble()),
          accuracy: (row['accuracy'] as num?)?.toDouble(),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
        );
      }
      return null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('MapTileStore.loadLocation failed: $e');
      return null;
    }
  }

  Future<void> saveLocation({
    required LatLng center,
    required double? accuracy,
  }) async {
    if (_closed) return;
    try {
      await (await _db).insert('map_location', {
        'id': 1,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'accuracy': accuracy,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('MapTileStore.saveLocation failed: $e');
    }
  }

  Future<void> close() async {
    _closed = true;
    final pending = _evicting;
    if (pending != null) {
      try {
        await pending;
      } on Exception catch (_) {}
    }
    final db = _database ?? await _opening;
    _database = null;
    _opening = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

class MapCameraSnapshot {
  const MapCameraSnapshot({required this.center, required this.zoom});
  final LatLng center;
  final double zoom;
}

class MapLocationSnapshot {
  const MapLocationSnapshot({
    required this.center,
    required this.accuracy,
    required this.updatedAt,
  });
  final LatLng center;
  final double? accuracy;
  final DateTime updatedAt;
}

class CachedTileProvider extends TileProvider {
  CachedTileProvider({
    required this.store,
    required this.layerId,
    this.client,
    this.onStaleTile,
    this.requestTimeout = _tileRequestTimeout,
    super.headers,
  });

  final MapTileStore store;
  final String layerId;
  final HttpClient? client;
  final ValueChanged<DateTime>? onStaleTile;
  final Duration requestTimeout;

  HttpClient? _httpClient;

  HttpClient _ensureHttpClient() {
    if (client != null) return client!;
    return _httpClient ??= HttpClient()
      ..connectionTimeout = _tileConnectTimeout;
  }

  @override
  void dispose() {
    _httpClient?.close(force: true);
    _httpClient = null;
    super.dispose();
  }

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
      if (DateTime.now().difference(cached.fetchedAt) >= mapTileMaxAge) {
        onStaleTile?.call(cached.fetchedAt);
        unawaited(_revalidate(z: z, x: x, y: y, url: url, cached: cached));
      }
      return cached.bytes;
    }
    try {
      return await _fetchAndStore(z: z, x: x, y: y, url: url, cached: null);
    } on Exception catch (_) {
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
    } on Exception catch (_) {
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
    final httpClient = _ensureHttpClient();
    final request = await httpClient
        .getUrl(Uri.parse(url))
        .timeout(requestTimeout);
    headers.forEach(request.headers.set);
    if (cached?.etag != null) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, cached!.etag!);
    }
    final response = await request.close().timeout(requestTimeout);
    if (response.statusCode == HttpStatus.notModified && cached != null) {
      await response.drain<void>().timeout(requestTimeout);
      await store.refreshMetadata(
        z: z,
        x: x,
        y: y,
        layerId: layerId,
        fetchedAt: DateTime.now(),
        etag: response.headers.value(HttpHeaders.etagHeader) ?? cached.etag,
      );
      return cached.bytes;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(requestTimeout);
      throw HttpException('Tile request failed: ${response.statusCode}');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(requestTimeout)) {
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
      codec: provider.loadBytes(z: z, x: x, y: y, url: url).then((bytes) {
        // A blank stand-in for a tile that could not be fetched is not
        // cached, so the real tile loads once the phone is online again.
        if (identical(bytes, _placeholderBytes)) {
          PaintingBinding.instance.imageCache.evict(key);
        }
        return ImmutableBuffer.fromUint8List(bytes).then(decode);
      }),
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

/// A transparent 1 by 1 PNG.
final _placeholderBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNgYGBgAAAABQABeqhXUAAAAABJRU5ErkJggg==',
  ),
);
