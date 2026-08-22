import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
    final store = MapTileStore(databasePath: p.join(directory.path, 'tiles.db'));
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
    expect(
      staleAt?.millisecondsSinceEpoch,
      fetchedAt.millisecondsSinceEpoch,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await store.close();
  });

  test('LRU eviction removes the oldest tile first', () async {
    final store = MapTileStore(databasePath: p.join(directory.path, 'tiles.db'));
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
    expect(
      await store.get(z: 1, x: 1, y: 1, layerId: 'osm'),
      isNull,
    );
    expect(
      await store.get(z: 1, x: 1, y: 2, layerId: 'osm'),
      isNotNull,
    );
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

    expect(
      momentsWithMapCoordinates(moments).map((moment) => moment.id),
      ['with-coordinate'],
    );
  });
}
