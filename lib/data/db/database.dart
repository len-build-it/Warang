import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/ids.dart';
import 'daos.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Profiles, Trips, Moments, Photos, AppMeta],
  daos: [ProfilesDao, TripsDao, MomentsDao, PhotosDao, AppMetaDao, SearchDao],
)
class WarangDatabase extends _$WarangDatabase {
  WarangDatabase(super.e);

  WarangDatabase.memory() : this(NativeDatabase.memory());

  factory WarangDatabase.open(File file) =>
      WarangDatabase(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 1) await m.createAll();
      await _createSearchIndex();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
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
        await appMetaDao.writeValue('activeProfileId', profileId, now);
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
        await appMetaDao.writeValue('everydayTripId', everydayId, now);
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

  Future<void> _createSearchIndex() async {
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
        VALUES ('moment', new.id, '', coalesce(new.place_label, ''), coalesce(new.caption, ''));
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS moments_search_au AFTER UPDATE ON moments BEGIN
        DELETE FROM warang_search WHERE entity_type = 'moment' AND entity_id = old.id;
        INSERT INTO warang_search(entity_type, entity_id, title, place, caption)
        VALUES ('moment', new.id, '', coalesce(new.place_label, ''), coalesce(new.caption, ''));
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS moments_search_ad AFTER DELETE ON moments BEGIN
        DELETE FROM warang_search WHERE entity_type = 'moment' AND entity_id = old.id;
      END
    ''');
  }
}
