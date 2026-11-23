import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/repository.dart';

/// Builds a real SQLite database file at schema 1 or schema 2 using sqflite_ffi,
/// then opens it with [WarangDatabase.open] to test the live Drift migration.
Future<void> _seedLegacyDatabase(File file, {required int version}) async {
  final db = await databaseFactoryFfi.openDatabase(
    file.path,
    options: OpenDatabaseOptions(version: version, singleInstance: false),
  );
  try {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        avatar_rel_path TEXT NULL,
        bio TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        author_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');
    final colorCol = version >= 2 ? 'color_key TEXT NULL,' : '';
    await db.execute('''
      CREATE TABLE trips (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        place TEXT NULL,
        description TEXT NULL,
        start_date INTEGER NULL,
        end_date INTEGER NULL,
        cover_moment_id TEXT NULL,
        is_everyday INTEGER NOT NULL DEFAULT 0,
        tags_json TEXT NOT NULL DEFAULT '[]',
        $colorCol
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        author_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');
    await db.execute('''
      CREATE TABLE moments (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips(id),
        caption TEXT NULL,
        captured_at INTEGER NOT NULL,
        latitude REAL NULL,
        longitude REAL NULL,
        accuracy_m REAL NULL,
        place_label TEXT NULL,
        sort_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        author_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');
    await db.execute('''
      CREATE TABLE photos (
        id TEXT NOT NULL PRIMARY KEY,
        moment_id TEXT NOT NULL REFERENCES moments(id),
        rel_path TEXT NOT NULL,
        thumb_rel_path TEXT NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        bytes INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        author_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');
    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        author_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE warang_search USING fts5(
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        title,
        place,
        caption,
        tokenize = 'unicode61'
      )
    ''');
    await db.execute('''
      CREATE TRIGGER moments_search_ai AFTER INSERT ON moments BEGIN
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES ('moment', new.id, '', coalesce(new.place_label, ''), coalesce(new.caption, ''));
      END
    ''');
    await db.execute('''
      CREATE TRIGGER moments_search_au AFTER UPDATE ON moments BEGIN
        DELETE FROM warang_search WHERE entity_type = 'moment' AND entity_id = old.id;
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES ('moment', new.id, '', coalesce(new.place_label, ''), coalesce(new.caption, ''));
      END
    ''');

    final t1 = DateTime(2026, 9, 1, 9, 0).millisecondsSinceEpoch ~/ 1000;
    final t2 = DateTime(2026, 9, 2, 10, 0).millisecondsSinceEpoch ~/ 1000;
    final t3 = DateTime(2026, 9, 3, 11, 0).millisecondsSinceEpoch ~/ 1000;

    await db.insert('profiles', {
      'id': 'prof-1',
      'name': 'Len',
      'created_at': t1,
      'updated_at': t1,
      'author_id': 'local',
    });
    await db.insert('trips', {
      'id': 'trip-everyday',
      'title': 'Everyday',
      'is_everyday': 1,
      if (version >= 2) 'color_key': null,
      'created_at': t1,
      'updated_at': t1,
      'author_id': 'local',
    });
    await db.insert('trips', {
      'id': 'trip-aklan',
      'title': 'Aklan Weekend',
      'place': 'Aklan',
      'is_everyday': 0,
      if (version >= 2) 'color_key': 'dagat',
      'created_at': t1,
      'updated_at': t1,
      'author_id': 'local',
    });

    // REQ-010 fixture: "Kape ni Juan" (newer), "kape ni juan " (older),
    // "Boracay", and one unlabelled moment.
    await db.insert('moments', {
      'id': 'm-1',
      'trip_id': 'trip-aklan',
      'caption': 'Morning pour-over',
      'captured_at': t2,
      'latitude': 11.7086,
      'longitude': 122.3643,
      'place_label': 'Kape ni Juan',
      'created_at': t2,
      'updated_at': t3,
      'author_id': 'local',
    });
    await db.insert('moments', {
      'id': 'm-2',
      'trip_id': 'trip-everyday',
      'caption': 'Afternoon iced latte',
      'captured_at': t1,
      'latitude': 11.7086,
      'longitude': 122.3643,
      'place_label': 'kape ni juan ',
      'created_at': t1,
      'updated_at': t1,
      'author_id': 'local',
    });
    await db.insert('moments', {
      'id': 'm-3',
      'trip_id': 'trip-aklan',
      'caption': 'Sunset swim',
      'captured_at': t2,
      'latitude': 11.9618,
      'longitude': 121.9242,
      'place_label': 'Boracay',
      'created_at': t2,
      'updated_at': t2,
      'author_id': 'local',
    });
    await db.insert('moments', {
      'id': 'm-4',
      'trip_id': 'trip-everyday',
      'caption': 'Window seat',
      'captured_at': t3,
      'place_label': null,
      'created_at': t3,
      'updated_at': t3,
      'author_id': 'local',
    });
    await db.insert('photos', {
      'id': 'ph-1',
      'moment_id': 'm-1',
      'rel_path': 'photos/m1.jpg',
      'thumb_rel_path': 'thumbs/m1.jpg',
      'width': 1200,
      'height': 900,
      'bytes': 42000,
      'position': 0,
      'created_at': t2,
      'updated_at': t2,
      'author_id': 'local',
    });
    await db.execute('PRAGMA user_version = $version');
  } finally {
    await db.close();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Schema 3 migration', () {
    test(
      'migrates schema 2 database to schema 3 without data loss (REQ-010)',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('warang_mig_v2_');
        final dbFile = File(p.join(tempDir.path, 'warang.sqlite'));
        await _seedLegacyDatabase(dbFile, version: 2);

        final db = WarangDatabase.open(dbFile);
        final repo = WarangRepository(
          db,
          photoStore: PhotoStore(documentsDirectory: tempDir),
        );
        addTearDown(() async {
          repo.dispose();
          await db.close();
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await repo.initialize();

        // No place_label column remains on moments.
        final cols = await db.customSelect('PRAGMA table_info(moments)').get();
        final colNames = cols.map((row) => row.read<String>('name')).toList();
        expect(colNames, contains('place_id'));
        expect(colNames, isNot(contains('place_label')));

        // Exactly two user places created from the three labels.
        expect(repo.places, hasLength(2));
        expect(
          repo.places.map((p) => p.name).toSet(),
          equals({'Kape ni Juan', 'Boracay'}),
        );
        expect(repo.places.every((p) => p.source == 'user'), isTrue);

        // Moments, photos, and trip colours are preserved.
        expect(repo.moments, hasLength(4));
        final m1 = repo.moments.firstWhere((m) => m.id == 'm-1');
        final m2 = repo.moments.firstWhere((m) => m.id == 'm-2');
        final m3 = repo.moments.firstWhere((m) => m.id == 'm-3');
        final m4 = repo.moments.firstWhere((m) => m.id == 'm-4');
        expect(m1.placeId, isNotNull);
        expect(m1.placeId, equals(m2.placeId));
        expect(m1.placeLabel, 'Kape ni Juan');
        expect(m2.placeLabel, 'Kape ni Juan');
        expect(m1.relPath, 'photos/m1.jpg');
        expect(m3.placeLabel, 'Boracay');
        expect(m4.placeId, isNull);
        expect(m4.placeLabel, isNull);

        final aklan = repo.trips.firstWhere((t) => t.id == 'trip-aklan');
        expect(aklan.colorKey, 'dagat');

        // Search index was rebuilt and finds migrated places.
        final kapeHits = await repo.searchAsync('Kape');
        expect(kapeHits.map((m) => m.id), containsAll(['m-1', 'm-2']));
      },
    );

    test('migrates schema 1 database directly to schema 3', () async {
      final tempDir = await Directory.systemTemp.createTemp('warang_mig_v1_');
      final dbFile = File(p.join(tempDir.path, 'warang.sqlite'));
      await _seedLegacyDatabase(dbFile, version: 1);

      final db = WarangDatabase.open(dbFile);
      final repo = WarangRepository(
        db,
        photoStore: PhotoStore(documentsDirectory: tempDir),
      );
      addTearDown(() async {
        repo.dispose();
        await db.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await repo.initialize();

      expect(repo.places, hasLength(2));
      expect(repo.moments, hasLength(4));
      final aklan = repo.trips.firstWhere((t) => t.id == 'trip-aklan');
      expect(aklan.colorKey, isNotNull);
    });
  });

  group('Places repository and search triggers', () {
    late Directory tempDir;
    late WarangDatabase db;
    late WarangRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('warang_places_repo_');
      db = WarangDatabase.memory();
      repo = WarangRepository(
        db,
        photoStore: PhotoStore(documentsDirectory: tempDir),
      );
      await repo.initialize();
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'attachBookPlace reuses one Places row per sourceRef (REQ-011)',
      () async {
        const bookCafe = BookPlace(
          osmRef: 'n1001',
          name: 'Kape ni Juan',
          category: 'cafe',
          latitude: 11.7086,
          longitude: 122.3643,
          town: 'Kalibo',
          province: 'Aklan',
        );
        final m1 = await repo.addMoment(caption: 'First cup');
        final m2 = await repo.addMoment(caption: 'Second cup');

        final p1 = await repo.attachBookPlace(m1.id, bookCafe);
        final p2 = await repo.attachBookPlace(m2.id, bookCafe);

        expect(p1.id, equals(p2.id));
        expect(p1.source, 'book');
        expect(p1.sourceRef, 'n1001');
        expect(repo.places, hasLength(1));

        final refreshed1 = repo.moments.firstWhere((m) => m.id == m1.id);
        final refreshed2 = repo.moments.firstWhere((m) => m.id == m2.id);
        expect(refreshed1.placeId, p1.id);
        expect(refreshed2.placeId, p1.id);
        expect(refreshed1.placeCategory, 'cafe');
      },
    );

    test(
      'setPlaceCategory updates all moments there and reindexes search (REQ-013, REQ-021)',
      () async {
        final m1 = await repo.addMoment();
        final m2 = await repo.addMoment();

        final place = await repo.attachUserPlace(m1.id, 'Hidden Roastery');
        expect(place, isNotNull);
        await repo.attachUserPlace(m2.id, '  hidden roastery ');
        expect(repo.places, hasLength(1));

        await repo.setPlaceCategory(place!.id, 'cafe');

        expect(
          repo.moments.where((m) => m.placeCategory == 'cafe'),
          hasLength(2),
        );

        // Searching by category name finds moments with no caption.
        final byCategory = await repo.searchAsync('cafe');
        expect(byCategory.map((m) => m.id), containsAll([m1.id, m2.id]));

        // Renaming the place in Places reindexes its moments via places_search_au.
        await db.placesDao.updatePlace(
          place.id,
          PlacesCompanion(
            name: const Value('Kalibo Coffee Lab'),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final byNewName = await repo.searchAsync('Coffee Lab');
        expect(byNewName.map((m) => m.id), containsAll([m1.id, m2.id]));
        final byOldName = await repo.searchAsync('Hidden Roastery');
        expect(byOldName, isEmpty);

        // Clearing place detaches moment.
        await repo.clearPlace(m2.id);
        expect(repo.moments.firstWhere((m) => m.id == m2.id).placeId, isNull);
      },
    );
  });
}
