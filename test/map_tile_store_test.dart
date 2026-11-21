import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/core/models.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

void main() {
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
}
