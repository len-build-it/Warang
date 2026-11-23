import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/core/ids.dart';
import 'package:warang/core/models.dart';
import 'package:warang/core/trip_rules.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  test('insert, read, and soft-delete round trip', () async {
    final moment = await repository.addMoment(
      caption: 'A quiet morning',
      placeLabel: 'Malay, Aklan',
    );

    expect(repository.moments, hasLength(1));
    expect(repository.moments.single.caption, 'A quiet morning');
    expect(repository.moments.single.tripId, repository.everyday.id);

    await repository.softDeleteMoment(moment.id);

    expect(repository.moments, isEmpty);
    expect(await database.momentsDao.getActive(), isEmpty);
    expect(await database.momentsDao.byId(moment.id), isNull);
  });

  test(
    'deleted rows are excluded from active profile, trip, moment, and search reads',
    () async {
      final trip = await _insertTrip(repository, 'Bohol Summer');
      final moment = await repository.addMoment(
        caption: 'Blue water',
        placeLabel: 'Bohol',
      );

      expect(await repository.searchAsync('Blue'), hasLength(1));
      expect(await repository.searchAsync('Bohol'), isNotEmpty);

      await database.tripsDao.softDelete(trip.id, DateTime.now());
      await repository.softDeleteMoment(moment.id);
      await database.profilesDao.updateProfile(
        repository.profile.id,
        ProfilesCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      expect(await database.profilesDao.getActive(), isNull);
      expect(await database.tripsDao.getActive(), isNot(isEmpty));
      expect(
        (await database.tripsDao.getActive()).where(
          (item) => item.id == trip.id,
        ),
        isEmpty,
      );
      expect(await database.momentsDao.getActive(), isEmpty);
      expect(await repository.searchAsync('Blue'), isEmpty);
    },
  );

  test(
    'Everyday is seeded exactly once across repeated initialization',
    () async {
      await repository.initialize();
      final secondRepository = WarangRepository(database);
      await secondRepository.initialize();

      final everyday = (await database.tripsDao.getActive())
          .where((trip) => trip.isEveryday)
          .toList();
      expect(everyday, hasLength(1));
      expect(repository.everyday.id, everyday.single.id);
      expect(secondRepository.everyday.id, everyday.single.id);

      secondRepository.dispose();
    },
  );

  test('dated trips receive captures through their whole last day', () async {
    await repository.addTrip(
      'Boracay',
      null,
      DateTime(2026, 3, 12),
      DateTime(2026, 3, 19),
    );
    final trip = repository.trips.firstWhere((item) => item.title == 'Boracay');

    final first = await repository.addMoment(capturedAt: DateTime(2026, 3, 12));
    final last = await repository.addMoment(
      capturedAt: DateTime(2026, 3, 19, 23, 59),
    );
    final after = await repository.addMoment(capturedAt: DateTime(2026, 3, 20));

    expect(first.tripId, trip.id);
    expect(last.tripId, trip.id);
    expect(after.tripId, repository.everyday.id);
    expect(repository.tripForCapture(DateTime(2026, 3, 19, 18)).id, trip.id);
    expect(
      repository.tripForCapture(DateTime(2026, 3, 20)).id,
      repository.everyday.id,
    );
  });

  test('captureMoment removes stored files when recording fails', () async {
    final documents = Directory.systemTemp.createTempSync('warang_capture_');
    addTearDown(() => documents.deleteSync(recursive: true));
    // A second, separate in-memory database is deliberate here; each has its
    // own executor, so drift's shared-executor warning does not apply.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final failingDatabase = WarangDatabase.memory();
    final failing = WarangRepository(
      failingDatabase,
      photoStore: PhotoStore(documentsDirectory: documents),
    );
    await failing.initialize();
    final source = File(p.join(documents.path, 'source.jpg'))
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
    await failingDatabase.close();

    await expectLater(
      failing.captureMoment(photo: source, caption: 'Lost'),
      throwsA(anything),
    );

    final photos = Directory(p.join(documents.path, 'warang', 'photos'));
    final leftovers = photos.existsSync()
        ? photos.listSync(recursive: true).whereType<File>().toList()
        : const <File>[];
    expect(leftovers, isEmpty);
    expect(source.existsSync(), isTrue);
    failing.dispose();
  });

  test('updateMoment edits text and trip, clearing blanks to null', () async {
    final moment = await repository.addMoment(caption: 'Old caption');
    final trip = await _insertTrip(repository, 'Antique');

    await repository.updateMoment(
      moment.id,
      caption: '  New caption ',
      tripId: trip.id,
    );
    await repository.attachUserPlace(moment.id, 'White Beach');
    var saved = repository.moments.single;
    expect(saved.caption, 'New caption');
    expect(saved.placeLabel, 'White Beach');
    expect(saved.tripId, trip.id);
    expect(await repository.searchAsync('White'), hasLength(1));

    await repository.updateMoment(
      moment.id,
      caption: ' ',
      tripId: repository.everyday.id,
    );
    await repository.clearPlace(moment.id);
    saved = repository.moments.single;
    expect(saved.caption, isNull);
    expect(saved.placeLabel, isNull);
    expect(saved.tripId, repository.everyday.id);

    await expectLater(
      repository.updateMoment(moment.id, caption: '', tripId: 'missing'),
      throwsArgumentError,
    );
  });

  test('setMomentLocation pins a moment and rejects bad values', () async {
    final moment = await repository.addMoment();
    await repository.setMomentLocation(moment.id, 11.9686, 121.918);
    expect(repository.moments.single.latitude, 11.9686);
    expect(repository.moments.single.longitude, 121.918);

    await expectLater(
      repository.setMomentLocation(moment.id, 91, 0),
      throwsRangeError,
    );
  });

  test('restoreMoment undoes a soft delete', () async {
    final moment = await repository.addMoment(caption: 'Keep me');
    await repository.softDeleteMoment(moment.id);
    expect(repository.moments, isEmpty);

    await repository.restoreMoment(moment.id);

    expect(repository.moments.single.id, moment.id);
    expect(repository.moments.single.caption, 'Keep me');
    expect(await repository.searchAsync('Keep'), hasLength(1));
  });

  test('trip fields are validated', () async {
    await expectLater(
      repository.addTrip(' ', null, null, null),
      throwsArgumentError,
    );
    await expectLater(
      repository.addTrip(
        'Backwards',
        null,
        DateTime(2026, 3, 9),
        DateTime(2026, 3, 1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.addTrip('Half', null, DateTime(2026, 3, 1), null),
      throwsArgumentError,
    );
  });

  test('updateTrip changes details and Everyday stays fixed', () async {
    final trip = await _insertTrip(repository, 'Draft');
    await repository.updateTrip(
      trip.id,
      title: 'Iloilo food crawl',
      place: ' Iloilo ',
      start: DateTime(2026, 5, 1),
      end: DateTime(2026, 5, 3),
    );
    final saved = repository.trips.firstWhere((item) => item.id == trip.id);
    expect(saved.title, 'Iloilo food crawl');
    expect(saved.place, 'Iloilo');
    expect(saved.endDate, DateTime(2026, 5, 3));
    expect(
      (await repository.addMoment(capturedAt: DateTime(2026, 5, 3, 20))).tripId,
      trip.id,
    );

    await expectLater(
      repository.updateTrip(repository.everyday.id, title: 'Renamed'),
      throwsArgumentError,
    );
    await expectLater(
      repository.deleteTrip(repository.everyday.id),
      throwsArgumentError,
    );
  });

  test('deleteTrip moves its moments to Everyday', () async {
    await repository.addTrip(
      'Guimaras',
      null,
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 2),
    );
    final trip = repository.trips.firstWhere(
      (item) => item.title == 'Guimaras',
    );
    final moment = await repository.addMoment(
      caption: 'Mango farm',
      capturedAt: DateTime(2026, 4, 1, 9),
    );
    expect(moment.tripId, trip.id);

    await repository.deleteTrip(trip.id);

    expect(repository.trips.where((item) => item.id == trip.id), isEmpty);
    expect(repository.moments.single.tripId, repository.everyday.id);
    expect(repository.moments.single.caption, 'Mango farm');
  });

  group('trip colours (FEAT-003 D-1)', () {
    test(
      'a fresh database is at schema 3 and Everyday has no colour',
      () async {
        expect(database.schemaVersion, 3);
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 3);
        expect(repository.everyday.colorKey, isNull);
        expect(tripColorKey(repository.everyday), isNull);
      },
    );

    test('new trips get the next colour after the last one made', () async {
      for (final title in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
        await repository.addTrip(title, null, null, null);
      }
      final byTitle = {
        for (final trip in repository.trips) trip.title: trip.colorKey,
      };
      expect(
        [
          for (final title in ['A', 'B', 'C', 'D', 'E', 'F', 'G'])
            byTitle[title],
        ],
        [...tripColorKeys, tripColorKeys.first],
      );
      // A deleted trip still counts as the last one made.
      final g = repository.trips.firstWhere((trip) => trip.title == 'G');
      await repository.deleteTrip(g.id);
      await repository.addTrip('H', null, null, null);
      expect(
        repository.trips.firstWhere((trip) => trip.title == 'H').colorKey,
        tripColorKeys[1],
      );
    });

    test('a chosen colour is kept and can be changed', () async {
      await repository.addTrip('Siargao', null, null, null, colorKey: 'langit');
      final trip = repository.trips.firstWhere((t) => t.title == 'Siargao');
      expect(trip.colorKey, 'langit');
      await repository.updateTrip(trip.id, title: 'Siargao', colorKey: 'ube');
      expect(
        repository.trips.firstWhere((t) => t.id == trip.id).colorKey,
        'ube',
      );
      // Editing other details keeps the colour.
      await repository.updateTrip(trip.id, title: 'Siargao surf');
      expect(
        repository.trips.firstWhere((t) => t.id == trip.id).colorKey,
        'ube',
      );
      expect(
        () => repository.addTrip('Bad', null, null, null, colorKey: 'amber'),
        throwsArgumentError,
      );
    });

    test('a trip without a colour gets a steady one from its id', () {
      const trip = Trip(id: 'trip-123', title: 'Old');
      expect(tripColorKey(trip), isIn(tripColorKeys));
      expect(tripColorKey(trip), tripColorKey(trip));
    });

    test(
      'a schema 1 database upgrades and colours trips in creation order',
      () async {
        final directory = Directory.systemTemp.createTempSync('warang_schema_');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File(p.join(directory.path, 'warang.sqlite'));

        // Build a schema 1 database: today's tables without the new column.
        final old = WarangDatabase(NativeDatabase(file));
        final oldRepository = WarangRepository(old);
        await oldRepository.initialize();
        final created = DateTime(2026, 1, 1);
        for (final (index, title) in ['Third', 'First', 'Second'].indexed) {
          final order = {'First': 0, 'Second': 1, 'Third': 2}[title]!;
          await old.tripsDao.insertTrip(
            TripsCompanion.insert(
              id: 'trip-$index',
              title: title,
              createdAt: created.add(Duration(days: order)),
              updatedAt: created,
            ),
          );
        }
        oldRepository.dispose();
        await old.close();
        sqfliteFfiInit();
        final raw = await databaseFactoryFfi.openDatabase(file.path);
        await raw.execute('ALTER TABLE trips DROP COLUMN color_key');
        await raw.execute('PRAGMA user_version = 1');
        await raw.close();

        final upgraded = WarangDatabase(NativeDatabase(file));
        final upgradedRepository = WarangRepository(upgraded);
        await upgradedRepository.initialize();
        final colours = {
          for (final trip in upgradedRepository.trips)
            trip.title: trip.colorKey,
        };
        expect(colours['First'], tripColorKeys[0]);
        expect(colours['Second'], tripColorKeys[1]);
        expect(colours['Third'], tripColorKeys[2]);
        expect(colours['Everyday'], isNull);
        // The next trip continues the sequence.
        await upgradedRepository.addTrip('Fourth', null, null, null);
        expect(
          upgradedRepository.trips
              .firstWhere((trip) => trip.title == 'Fourth')
              .colorKey,
          tripColorKeys[3],
        );
        upgradedRepository.dispose();
        await upgraded.close();
      },
    );
  });

  test('UUID v4 identifiers are unique across ten thousand values', () {
    final ids = {for (var index = 0; index < 10000; index++) newId()};
    expect(ids, hasLength(10000));
  });
}

Future<Trip> _insertTrip(WarangRepository repository, String title) async {
  await repository.addTrip(title, null, null, null);
  return repository.trips.firstWhere((trip) => trip.title == title);
}
