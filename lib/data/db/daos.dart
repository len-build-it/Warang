import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfilesDao extends DatabaseAccessor<WarangDatabase>
    with _$ProfilesDaoMixin {
  ProfilesDao(super.attachedDatabase);

  Future<ProfileRow?> getActive() =>
      (select(profiles)
            ..where((profile) => profile.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Stream<ProfileRow?> watchActive() =>
      (select(profiles)
            ..where((profile) => profile.deletedAt.isNull())
            ..limit(1))
          .watchSingleOrNull();

  Future<int> insertProfile(ProfilesCompanion entry) =>
      into(profiles).insert(entry);

  Future<int> updateProfile(String id, ProfilesCompanion entry) => (update(
    profiles,
  )..where((profile) => profile.id.equals(id))).write(entry);
}

@DriftAccessor(tables: [Trips])
class TripsDao extends DatabaseAccessor<WarangDatabase> with _$TripsDaoMixin {
  TripsDao(super.attachedDatabase);

  Future<TripRow?> getEveryday() =>
      (select(trips)
            ..where(
              (trip) => trip.isEveryday.equals(true) & trip.deletedAt.isNull(),
            )
            ..limit(1))
          .getSingleOrNull();

  Stream<List<TripRow>> watchActive() =>
      (select(trips)
            ..where((trip) => trip.deletedAt.isNull())
            ..orderBy([
              (trip) => OrderingTerm(
                expression: trip.isEveryday,
                mode: OrderingMode.desc,
              ),
              (trip) => OrderingTerm(
                expression: trip.updatedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<List<TripRow>> getActive() =>
      (select(trips)..where((trip) => trip.deletedAt.isNull())).get();

  Future<TripRow?> byId(String id) =>
      (select(trips)
            ..where((trip) => trip.id.equals(id) & trip.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Future<TripRow?> findActiveFor(DateTime date) =>
      (select(trips)
            ..where(
              (trip) =>
                  trip.isEveryday.equals(false) &
                  trip.deletedAt.isNull() &
                  trip.startDate.isNotNull() &
                  trip.endDate.isNotNull() &
                  trip.startDate.isSmallerOrEqualValue(date) &
                  trip.endDate.isBiggerOrEqualValue(date),
            )
            ..orderBy([
              (trip) => OrderingTerm(
                expression: trip.updatedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertTrip(TripsCompanion entry) => into(trips).insert(entry);

  Future<int> updateTrip(String id, TripsCompanion entry) =>
      (update(trips)..where((trip) => trip.id.equals(id))).write(entry);

  Future<int> softDelete(String id, DateTime deletedAt) => updateTrip(
    id,
    TripsCompanion(deletedAt: Value(deletedAt), updatedAt: Value(deletedAt)),
  );
}

@DriftAccessor(tables: [Moments])
class MomentsDao extends DatabaseAccessor<WarangDatabase>
    with _$MomentsDaoMixin {
  MomentsDao(super.attachedDatabase);

  Stream<List<MomentRow>> watchActive() =>
      (select(moments)
            ..where((moment) => moment.deletedAt.isNull())
            ..orderBy([
              (moment) => OrderingTerm(expression: moment.sortIndex),
              (moment) => OrderingTerm(
                expression: moment.capturedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Stream<List<MomentRow>> watchMapPins() =>
      (select(moments)
            ..where(
              (moment) =>
                  moment.deletedAt.isNull() &
                  moment.latitude.isNotNull() &
                  moment.longitude.isNotNull(),
            )
            ..orderBy([
              (moment) => OrderingTerm(
                expression: moment.capturedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<List<MomentRow>> getActive() =>
      (select(moments)
            ..where((moment) => moment.deletedAt.isNull())
            ..orderBy([
              (moment) => OrderingTerm(expression: moment.sortIndex),
              (moment) => OrderingTerm(
                expression: moment.capturedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  Future<MomentRow?> byId(String id) =>
      (select(moments)
            ..where(
              (moment) => moment.id.equals(id) & moment.deletedAt.isNull(),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertMoment(MomentsCompanion entry) =>
      into(moments).insert(entry);

  Future<int> updateMoment(String id, MomentsCompanion entry) =>
      (update(moments)..where((moment) => moment.id.equals(id))).write(entry);

  Future<int> softDelete(String id, DateTime deletedAt) => updateMoment(
    id,
    MomentsCompanion(deletedAt: Value(deletedAt), updatedAt: Value(deletedAt)),
  );
}

@DriftAccessor(tables: [Photos])
class PhotosDao extends DatabaseAccessor<WarangDatabase> with _$PhotosDaoMixin {
  PhotosDao(super.attachedDatabase);

  Future<PhotoRow?> firstForMoment(String momentId) =>
      (select(photos)
            ..where(
              (photo) =>
                  photo.momentId.equals(momentId) & photo.deletedAt.isNull(),
            )
            ..orderBy([(photo) => OrderingTerm(expression: photo.position)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertPhoto(PhotosCompanion entry) => into(photos).insert(entry);

  Future<List<PhotoRow>> getOrphans() async {
    final rows = await customSelect(
      '''SELECT p.* FROM photos p
         LEFT JOIN moments m ON m.id = p.moment_id
         WHERE p.deleted_at IS NULL AND (m.id IS NULL OR m.deleted_at IS NOT NULL)''',
      readsFrom: {photos, moments},
    ).get();
    return rows
        .map(
          (row) => PhotoRow(
            id: row.read<String>('id'),
            momentId: row.read<String>('moment_id'),
            relPath: row.read<String>('rel_path'),
            thumbRelPath: row.read<String>('thumb_rel_path'),
            width: row.read<int>('width'),
            height: row.read<int>('height'),
            bytes: row.read<int>('bytes'),
            position: row.read<int>('position'),
            createdAt: row.read<DateTime>('created_at'),
            updatedAt: row.read<DateTime>('updated_at'),
            deletedAt: row.readNullable<DateTime>('deleted_at'),
            authorId: row.read<String>('author_id'),
          ),
        )
        .toList();
  }
}

@DriftAccessor(tables: [AppMeta])
class AppMetaDao extends DatabaseAccessor<WarangDatabase>
    with _$AppMetaDaoMixin {
  AppMetaDao(super.attachedDatabase);

  Future<String?> readValue(String key) async =>
      (select(appMeta)
            ..where((meta) => meta.key.equals(key) & meta.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull()
          .then((row) => row?.value);

  Future<void> writeValue(String key, String value, DateTime now) async {
    await into(appMeta).insertOnConflictUpdate(
      AppMetaCompanion.insert(
        key: key,
        value: value,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class SearchHit {
  const SearchHit({required this.entityType, required this.entityId});
  final String entityType;
  final String entityId;
}

@DriftAccessor(tables: [Trips, Moments])
class SearchDao extends DatabaseAccessor<WarangDatabase> with _$SearchDaoMixin {
  SearchDao(super.attachedDatabase);

  Future<List<SearchHit>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final rows = await customSelect(
      '''SELECT s.entity_type, s.entity_id
         FROM warang_search s
         LEFT JOIN trips t ON s.entity_type = 'trip' AND t.id = s.entity_id
         LEFT JOIN moments m ON s.entity_type = 'moment' AND m.id = s.entity_id
         WHERE warang_search MATCH ?
           AND ((s.entity_type = 'trip' AND t.deleted_at IS NULL)
             OR (s.entity_type = 'moment' AND m.deleted_at IS NULL))
         ORDER BY rank''',
      variables: [Variable.withString(value)],
      readsFrom: {trips, moments},
    ).get();
    return rows
        .map(
          (row) => SearchHit(
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
          ),
        )
        .toList();
  }
}
