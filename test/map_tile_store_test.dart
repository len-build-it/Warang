import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart' show TileCoordinates, TileLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/core/models.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('warang-tile-test-');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('cache hits return bytes and stale tiles remain usable', () async {
    final store = MapTileStore(
      databasePath: p.join(directory.path, 'tiles.db'),
    );
    final bytes = Uint8List.fromList([1, 2, 3]);
    final fetchedAt = DateTime.now().subtract(const Duration(days: 31));
    await store.put(
      MapTileRecord(
        z: 4,
        x: 5,
        y: 6,
        layerId: 'osm',
        bytes: bytes,
        fetchedAt: fetchedAt,
      ),
    );
    DateTime? staleAt;
    final provider = CachedTileProvider(
      store: store,
      layerId: 'osm',
      onStaleTile: (value) => staleAt = value,
    );

    final loaded = await provider.loadBytes(
      z: 4,
      x: 5,
      y: 6,
      url: 'http://127.0.0.1:1/never-requested.png',
    );

    expect(loaded, bytes);
    expect(staleAt?.millisecondsSinceEpoch, fetchedAt.millisecondsSinceEpoch);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await store.close();
  });

  test(
    'an unreachable tile shows blank and is fetched again next time',
    () async {
      final store = MapTileStore(
        databasePath: p.join(directory.path, 'tiles.db'),
      );
      final provider = CachedTileProvider(store: store, layerId: 'osm');
      final image = provider.getImage(
        const TileCoordinates(1, 2, 3),
        TileLayer(urlTemplate: 'http://127.0.0.1:1/{z}/{x}/{y}.png'),
      );
      final cache = PaintingBinding.instance.imageCache;
      final done = Completer<ImageInfo>();
      image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (info, _) => done.complete(info),
              onError: (error, _) => done.completeError(error),
            ),
          );
      final info = await done.future.timeout(const Duration(seconds: 20));
      // The placeholder is a real image, not a decode error.
      expect(info.image.width, 1);
      // It is not kept, so the real tile loads once the phone is online.
      expect(
        cache.containsKey(await image.obtainKey(ImageConfiguration.empty)),
        isFalse,
      );
      await store.close();
    },
  );

  test('LRU eviction removes the oldest tile first', () async {
    final store = MapTileStore(
      databasePath: p.join(directory.path, 'tiles.db'),
    );
    final now = DateTime.now();
    await store.put(
      MapTileRecord(
        z: 1,
        x: 1,
        y: 1,
        layerId: 'osm',
        bytes: Uint8List.fromList([1, 2, 3]),
        fetchedAt: now.subtract(const Duration(minutes: 2)),
      ),
    );
    await store.put(
      MapTileRecord(
        z: 1,
        x: 1,
        y: 2,
        layerId: 'osm',
        bytes: Uint8List.fromList([4, 5, 6]),
        fetchedAt: now,
      ),
    );

    await store.evictToLimit(3);
    expect(await store.get(z: 1, x: 1, y: 1, layerId: 'osm'), isNull);
    expect(await store.get(z: 1, x: 1, y: 2, layerId: 'osm'), isNotNull);
    await store.close();
  });

  test('moments without coordinates are excluded from map markers', () {
    final moments = [
      Moment(
        id: 'with-coordinate',
        tripId: 'trip',
        capturedAt: DateTime(2026),
        latitude: 11.5,
        longitude: 122,
      ),
      Moment(
        id: 'without-coordinate',
        tripId: 'trip',
        capturedAt: DateTime(2026),
      ),
    ];

    expect(momentsWithMapCoordinates(moments).map((moment) => moment.id), [
      'with-coordinate',
    ]);
  });

  test(
    'opens legacy database with only tiles table and persists camera',
    () async {
      final dbPath = p.join(directory.path, 'legacy_tiles.db');
      final raw = await sqflite.openDatabase(
        dbPath,
        singleInstance: false,
        onOpen: (db) async {
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
        },
      );
      await raw.close();

      final store = MapTileStore(databasePath: dbPath);
      await store.saveCamera(const LatLng(11.9686, 121.918), 14.5);
      final loaded = await store.loadCamera();

      expect(loaded, isNotNull);
      expect(loaded!.center.latitude, 11.9686);
      expect(loaded.center.longitude, 121.918);
      expect(loaded.zoom, 14.5);
      await store.close();
    },
  );

  test(
    'evictToLimit evicts oldest tiles until total is at or below limit',
    () async {
      final store = MapTileStore(
        databasePath: p.join(directory.path, 'evict_five.db'),
      );
      final base = DateTime(2026, 11, 21, 12);
      for (var i = 0; i < 5; i++) {
        await store.put(
          MapTileRecord(
            z: 2,
            x: i,
            y: 0,
            layerId: 'osm',
            bytes: Uint8List(100),
            fetchedAt: base.add(Duration(minutes: i)),
          ),
        );
      }

      await store.evictToLimit(250);

      expect(await store.totalBytes(), lessThanOrEqualTo(250));
      expect(await store.get(z: 2, x: 0, y: 0, layerId: 'osm'), isNull);
      expect(await store.get(z: 2, x: 1, y: 0, layerId: 'osm'), isNull);
      expect(await store.get(z: 2, x: 2, y: 0, layerId: 'osm'), isNull);
      expect(await store.get(z: 2, x: 3, y: 0, layerId: 'osm'), isNotNull);
      expect(await store.get(z: 2, x: 4, y: 0, layerId: 'osm'), isNotNull);
      await store.close();
    },
  );

  test('fresh cache hit triggers zero HTTP requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((req) {
      requests++;
      req.response
        ..statusCode = HttpStatus.ok
        ..add([9, 9, 9])
        ..close();
    });
    addTearDown(() => server.close(force: true));

    final store = MapTileStore(
      databasePath: p.join(directory.path, 'fresh_hit.db'),
    );
    final bytes = Uint8List.fromList([7, 8, 9]);
    await store.put(
      MapTileRecord(
        z: 10,
        x: 1,
        y: 2,
        layerId: 'osm',
        bytes: bytes,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttpOverrides());
    addTearDown(() => client.close(force: true));
    final provider = CachedTileProvider(
      store: store,
      layerId: 'osm',
      client: client,
    );
    final loaded = await provider.loadBytes(
      z: 10,
      x: 1,
      y: 2,
      url: 'http://${server.address.address}:${server.port}/10/1/2.png',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(loaded, bytes);
    expect(requests, 0);
    provider.dispose();
    await store.close();
  });

  test('stale cache hit with HTTP 304 refreshes metadata in place', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    String? receivedIfNoneMatch;
    server.listen((req) {
      requests++;
      receivedIfNoneMatch = req.headers.value(HttpHeaders.ifNoneMatchHeader);
      req.response
        ..statusCode = HttpStatus.notModified
        ..headers.set(HttpHeaders.etagHeader, '"etag-v2"')
        ..close();
    });
    addTearDown(() => server.close(force: true));

    final store = MapTileStore(
      databasePath: p.join(directory.path, 'not_modified.db'),
    );
    final bytes = Uint8List.fromList([11, 22, 33]);
    final oldTime = DateTime.now().subtract(const Duration(days: 35));
    await store.put(
      MapTileRecord(
        z: 8,
        x: 3,
        y: 4,
        layerId: 'osm',
        bytes: bytes,
        fetchedAt: oldTime,
        etag: '"etag-v1"',
      ),
    );
    final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttpOverrides());
    addTearDown(() => client.close(force: true));
    final provider = CachedTileProvider(
      store: store,
      layerId: 'osm',
      client: client,
    );
    final loaded = await provider.loadBytes(
      z: 8,
      x: 3,
      y: 4,
      url: 'http://${server.address.address}:${server.port}/8/3/4.png',
    );
    expect(loaded, bytes);

    // Wait for background revalidation to finish.
    for (var i = 0; i < 20; i++) {
      final updated = await store.get(z: 8, x: 3, y: 4, layerId: 'osm');
      if (updated != null && updated.etag == '"etag-v2"') break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final updated = await store.get(z: 8, x: 3, y: 4, layerId: 'osm');
    expect(requests, 1);
    expect(receivedIfNoneMatch, '"etag-v1"');
    expect(updated, isNotNull);
    expect(updated!.bytes, bytes);
    expect(updated.etag, '"etag-v2"');
    expect(updated.fetchedAt.isAfter(oldTime), isTrue);

    provider.dispose();
    await store.close();
  });

  test('request timeout returns placeholder and malformed rows return null', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pendingResponses = <HttpResponse>[];
    server.listen((req) {
      pendingResponses.add(req.response);
    });
    addTearDown(() async {
      for (final res in pendingResponses) {
        await res.close();
      }
      await server.close(force: true);
    });

    final dbPath = p.join(directory.path, 'timeout_malformed.db');
    final store = MapTileStore(databasePath: dbPath);
    final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttpOverrides());
    addTearDown(() => client.close(force: true));
    final provider = CachedTileProvider(
      store: store,
      layerId: 'osm',
      client: client,
      requestTimeout: const Duration(milliseconds: 150),
    );
    final bytes = await provider.loadBytes(
      z: 5,
      x: 5,
      y: 5,
      url: 'http://${server.address.address}:${server.port}/5/5/5.png',
    );
    expect(bytes.length, greaterThan(0));
    expect(await store.get(z: 5, x: 5, y: 5, layerId: 'osm'), isNull);
    provider.dispose();
    await store.close();

    // Inject a malformed row directly and confirm get returns null cleanly.
    final raw = await sqflite.openDatabase(dbPath, singleInstance: false);
    await raw.rawInsert(
      'INSERT INTO tiles (z, x, y, layerId, bytes, fetchedAt) '
      "VALUES (9, 9, 9, 'osm', 'not-a-blob', 'bad-timestamp')",
    );
    await raw.close();

    final reopened = MapTileStore(databasePath: dbPath);
    expect(await reopened.get(z: 9, x: 9, y: 9, layerId: 'osm'), isNull);
    await reopened.close();
  });

  test('upgrades legacy tile database without lastAccessedAt column', () async {
    final dbPath = p.join(directory.path, 'legacy_upgrade.db');
    final fetchedMs = DateTime(2026, 1, 10).millisecondsSinceEpoch;
    final raw = await sqflite.openDatabase(
      dbPath,
      singleInstance: false,
      onOpen: (db) async {
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
        await db.insert('tiles', {
          'z': 3,
          'x': 2,
          'y': 1,
          'layerId': 'osm',
          'bytes': Uint8List.fromList([4, 5, 6]),
          'fetchedAt': fetchedMs,
        });
      },
    );
    await raw.close();

    final store = MapTileStore(databasePath: dbPath);
    final tile = await store.get(z: 3, x: 2, y: 1, layerId: 'osm');
    expect(tile, isNotNull);
    expect(tile!.bytes, Uint8List.fromList([4, 5, 6]));
    expect(tile.lastAccessedAt?.millisecondsSinceEpoch, fetchedMs);
    await store.close();

    final verifyDb = await sqflite.openDatabase(dbPath, singleInstance: false);
    final columns = await verifyDb.rawQuery('PRAGMA table_info(tiles)');
    expect(columns.any((c) => c['name'] == 'lastAccessedAt'), isTrue);
    await verifyDb.close();
  });

  test('serialized LRU eviction removes least-recently-accessed tile first', () async {
    final store = MapTileStore(
      databasePath: p.join(directory.path, 'lru_serialized.db'),
    );
    final base = DateTime(2026, 11, 20, 12);
    // Tile A was fetched earlier, but accessed more recently.
    await store.put(
      MapTileRecord(
        z: 1,
        x: 0,
        y: 0,
        layerId: 'osm',
        bytes: Uint8List(100),
        fetchedAt: base,
        lastAccessedAt: base.add(const Duration(days: 5)),
      ),
    );
    // Tile B was fetched later, but accessed earlier.
    await store.put(
      MapTileRecord(
        z: 1,
        x: 1,
        y: 0,
        layerId: 'osm',
        bytes: Uint8List(100),
        fetchedAt: base.add(const Duration(days: 1)),
        lastAccessedAt: base.add(const Duration(days: 1)),
      ),
    );

    await Future.wait([store.evictToLimit(120), store.evictToLimit(120)]);

    expect(await store.totalBytes(), lessThanOrEqualTo(120));
    expect(await store.get(z: 1, x: 1, y: 0, layerId: 'osm'), isNull);
    expect(await store.get(z: 1, x: 0, y: 0, layerId: 'osm'), isNotNull);
    await store.close();
  });
}
