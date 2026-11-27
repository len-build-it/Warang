import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/ids.dart';
import '../../core/trip_rules.dart';
import 'daos.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Profiles, Trips, Places, Moments, Photos, AppMeta],
  daos: [
    ProfilesDao,
    TripsDao,
    PlacesDao,
    MomentsDao,
    PhotosDao,
    AppMetaDao,
    SearchDao,
  ],
)
class WarangDatabase extends _$WarangDatabase {
  WarangDatabase(super.e);

  WarangDatabase.memory() : this(NativeDatabase.memory());

  factory WarangDatabase.open(File file) =>
      WarangDatabase(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 3;

  static const _categoryNameCaseSql = '''
    CASE p.category_key
      WHEN 'cafe' THEN 'Cafe'
      WHEN 'food' THEN 'Food'
      WHEN 'sweets' THEN 'Sweets and bakery'
      WHEN 'nightlife' THEN 'Nightlife'
      WHEN 'beach' THEN 'Beach'
      WHEN 'island' THEN 'Island'
      WHEN 'nature' THEN 'Mountains and falls'
      WHEN 'park' THEN 'Parks and views'
      WHEN 'church' THEN 'Churches'
      WHEN 'heritage' THEN 'Heritage and museums'
      WHEN 'market' THEN 'Markets and malls'
      WHEN 'stay' THEN 'Stays'
      WHEN 'transit' THEN 'On the way'
      WHEN 'town' THEN 'Towns and cities'
      ELSE coalesce(p.category_key, '')
    END
  ''';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createPlacesIndex();
      await _createSearchIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 1) await m.createAll();
      if (from < 2) {
        await transaction(() async {
          await m.addColumn(trips, trips.colorKey);
          await _colourExistingTrips();
        });
      }
      if (from < 3) {
        await transaction(() async {
          await _dropMomentSearchTriggers();
          await m.createTable(places);
          await _createPlacesIndex();

          // Convert existing free-text place_label values into user places,
          // preserving the most recently updated trimmed spelling per name.
          final momentCols = await customSelect(
            'PRAGMA table_info(moments)',
          ).get();
          final colNames = momentCols
              .map((row) => row.read<String>('name'))
              .toSet();
          final momentToPlaceId = <String, String>{};
          if (colNames.contains('place_label')) {
            final labelRows = await customSelect('''
              SELECT id, place_label, created_at, updated_at, author_id
              FROM moments
              WHERE place_label IS NOT NULL AND trim(place_label) != ''
              ORDER BY updated_at DESC, rowid DESC
            ''').get();

            final placeIdByKey = <String, String>{};
            for (final row in labelRows) {
              final raw = row.read<String>('place_label');
              final trimmed = raw.trim();
              if (trimmed.isEmpty) continue;
              final key = trimmed.toLowerCase();
              var placeId = placeIdByKey[key];
              if (placeId == null) {
                placeId = newId();
                placeIdByKey[key] = placeId;
                final createdAt = row.read<int>('created_at');
                final updatedAt = row.read<int>('updated_at');
                final authorId = row.read<String>('author_id');
                await customStatement(
                  '''INSERT INTO places (
                       id, name, category_key, latitude, longitude,
                       source, source_ref, created_at, updated_at, deleted_at, author_id
                     ) VALUES (?, ?, NULL, NULL, NULL, 'user', NULL, ?, ?, NULL, ?)''',
                  [placeId, trimmed, createdAt, updatedAt, authorId],
                );
              }
              momentToPlaceId[row.read<String>('id')] = placeId;
            }
          }

          if (!colNames.contains('place_id')) {
            await customStatement(
              'ALTER TABLE moments ADD COLUMN place_id TEXT REFERENCES places(id)',
            );
          }
          for (final entry in momentToPlaceId.entries) {
            await customStatement(
              'UPDATE moments SET place_id = ? WHERE id = ?',
              [entry.value, entry.key],
            );
          }

          await m.alterTable(TableMigration(moments));
          await _createSearchIndex(recreate: true);
          await _rebuildSearchIndex();
        });
      } else {
        await _createPlacesIndex();
        await _createSearchIndex();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createPlacesIndex();
      await _createSearchIndex();
    },
  );

  Future<void> seedDefaults() async {
    await transaction(() async {
      final now = DateTime.now();
      var profile = await profilesDao.getActive();
      if (profile == null) {
        final profileId = newId();
        await profilesDao.insertProfile(
          ProfilesCompanion.insert(
            id: profileId,
            name: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
        profile = await profilesDao.getActive();
      }

      var everyday = await tripsDao.getEveryday();
      if (everyday == null) {
        final everydayId = newId();
        await tripsDao.insertTrip(
          TripsCompanion.insert(
            id: everydayId,
            title: 'Everyday',
            isEveryday: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
        everyday = await tripsDao.getEveryday();
      }

      if (profile != null) {
        await appMetaDao.writeValue('activeProfileId', profile.id, now);
      }
      if (everyday != null) {
        await appMetaDao.writeValue('everydayTripId', everyday.id, now);
      }
      await appMetaDao.writeValue('schemaVersion', '$schemaVersion', now);
    });
  }

  /// Gives every trip made before colours existed one, in creation order.
  Future<void> _colourExistingTrips() async {
    final rows = await customSelect(
      'SELECT id FROM trips WHERE is_everyday = 0 ORDER BY created_at, rowid',
    ).get();
    String? previous;
    for (final row in rows) {
      previous = nextTripColorKey(previous);
      await customStatement('UPDATE trips SET color_key = ? WHERE id = ?', [
        previous,
        row.read<String>('id'),
      ]);
    }
  }

  Future<void> _createPlacesIndex() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS places_source_ref_active
      ON places(source_ref)
      WHERE source_ref IS NOT NULL AND deleted_at IS NULL
    ''');
  }

  Future<void> _dropMomentSearchTriggers() async {
    await customStatement('DROP TRIGGER IF EXISTS moments_search_ai');
    await customStatement('DROP TRIGGER IF EXISTS moments_search_au');
    await customStatement('DROP TRIGGER IF EXISTS moments_search_ad');
    await customStatement('DROP TRIGGER IF EXISTS places_search_au');
    await customStatement('DROP TRIGGER IF EXISTS places_search_ad');
  }

  Future<void> _createSearchIndex({bool recreate = false}) async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS warang_search USING fts5(
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        title,
        place,
        caption,
        tokenize = 'unicode61'
      )
    ''');
    if (recreate) {
      await _dropMomentSearchTriggers();
    }
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trips_search_ai AFTER INSERT ON trips BEGIN
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES ('trip', new.id, new.title, coalesce(new.place, ''), '');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trips_search_au AFTER UPDATE ON trips BEGIN
        DELETE FROM warang_search WHERE entity_type = 'trip' AND entity_id = old.id;
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES ('trip', new.id, new.title, coalesce(new.place, ''), '');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trips_search_ad AFTER DELETE ON trips BEGIN
        DELETE FROM warang_search WHERE entity_type = 'trip' AND entity_id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS moments_search_ai AFTER INSERT ON moments BEGIN
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES (
          'moment',
          new.id,
          '',
          coalesce((
            SELECT trim(p.name || ' ' || $_categoryNameCaseSql)
            FROM places p
            WHERE p.id = new.place_id AND p.deleted_at IS NULL
          ), ''),
          coalesce(new.caption, '')
        );
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS moments_search_au AFTER UPDATE ON moments BEGIN
        DELETE FROM warang_search WHERE entity_type = 'moment' AND entity_id = old.id;
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES (
          'moment',
          new.id,
          '',
          coalesce((
            SELECT trim(p.name || ' ' || $_categoryNameCaseSql)
            FROM places p
            WHERE p.id = new.place_id AND p.deleted_at IS NULL
          ), ''),
          coalesce(new.caption, '')
        );
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS moments_search_ad AFTER DELETE ON moments BEGIN
        DELETE FROM warang_search WHERE entity_type = 'moment' AND entity_id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS places_search_au AFTER UPDATE ON places BEGIN
        DELETE FROM warang_search
        WHERE entity_type = 'moment'
          AND entity_id IN (SELECT id FROM moments WHERE place_id = new.id);
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        SELECT
          'moment',
          m.id,
          '',
          CASE WHEN new.deleted_at IS NULL
            THEN trim(new.name || ' ' || (
              SELECT $_categoryNameCaseSql FROM places p WHERE p.id = new.id
            ))
            ELSE ''
          END,
          coalesce(m.caption, '')
        FROM moments m
        WHERE m.place_id = new.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS places_search_ad AFTER DELETE ON places BEGIN
        DELETE FROM warang_search
        WHERE entity_type = 'moment'
          AND entity_id IN (SELECT id FROM moments WHERE place_id = old.id);
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        SELECT 'moment', m.id, '', '', coalesce(m.caption, '')
        FROM moments m
        WHERE m.place_id = old.id;
      END
    ''');
  }

  Future<void> _rebuildSearchIndex() async {
    await customStatement('DELETE FROM warang_search');
    await customStatement('''
      INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
      SELECT 'trip', id, title, coalesce(place, ''), ''
      FROM trips
    ''');
    await customStatement('''
      INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
      SELECT
        'moment',
        m.id,
        '',
        coalesce((
          SELECT trim(p.name || ' ' || $_categoryNameCaseSql)
          FROM places p
          WHERE p.id = m.place_id AND p.deleted_at IS NULL
        ), ''),
        coalesce(m.caption, '')
      FROM moments m
    ''');
  }
}
