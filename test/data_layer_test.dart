import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:warang/core/ids.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
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

  test('UUID v4 identifiers are unique across ten thousand values', () {
    final ids = {for (var index = 0; index < 10000; index++) newId()};
    expect(ids, hasLength(10000));
  });
}

Future<Trip> _insertTrip(WarangRepository repository, String title) async {
  await repository.addTrip(title, null, null, null);
  return repository.trips.firstWhere((trip) => trip.title == title);
}
