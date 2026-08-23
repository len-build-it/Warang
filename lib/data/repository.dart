import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../core/ids.dart';
import '../core/models.dart';
import 'db/database.dart';
import 'files/photo_store.dart';

/// UI-facing compatibility façade over the Drift data layer.
///
/// The database and DAOs own persistence and query semantics. This façade keeps
/// the existing screens simple while exposing cached snapshots and notifying
/// them whenever a reactive DAO stream changes.
class WarangRepository extends ChangeNotifier {
  WarangRepository(this.database, {PhotoStore? photoStore})
    : photoStore = photoStore ?? PhotoStore();

  final WarangDatabase database;
  final PhotoStore photoStore;
  late Profile _profile;
  List<Trip> _trips = const [];
  List<Moment> _moments = const [];
  StreamSubscription<ProfileRow?>? _profileSubscription;
  StreamSubscription<List<TripRow>>? _tripsSubscription;
  StreamSubscription<List<MomentRow>>? _momentsSubscription;
  bool _isDisposed = false;

  Future<void> initialize() async {
    await database.seedDefaults();
    await _refreshAll();
    await _profileSubscription?.cancel();
    await _tripsSubscription?.cancel();
    await _momentsSubscription?.cancel();
    _profileSubscription = database.profilesDao.watchActive().listen((row) {
      if (_isDisposed) return;
      if (row == null) return;
      _profile = _profileFromRow(row);
      notifyListeners();
    });
    _tripsSubscription = database.tripsDao.watchActive().listen((rows) {
      if (_isDisposed) return;
      _trips = rows.map(_tripFromRow).toList(growable: false);
      notifyListeners();
    });
    _momentsSubscription = database.momentsDao.watchActive().listen((rows) {
      if (_isDisposed) return;
      unawaited(_refreshMoments(rows));
    });
  }

  Profile get profile => _profile;

  List<Trip> get trips => List.unmodifiable(_trips);

  List<Moment> get moments => List.unmodifiable(_moments);

  Trip get everyday => _trips.firstWhere((trip) => trip.isEveryday);

  Future<void> setName(String name) async {
    final now = DateTime.now();
    await database.profilesDao.updateProfile(
      _profile.id,
      ProfilesCompanion(name: Value(name.trim()), updatedAt: Value(now)),
    );
    await _refreshAll();
  }

  Future<void> setAvatar(File source) async {
    final relativePath = await photoStore.importAvatar(source);
    await database.profilesDao.updateProfile(
      _profile.id,
      ProfilesCompanion(
        avatarRelPath: Value(relativePath),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  Future<Moment> addMoment({
    String? caption,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? placeLabel,
    String? relPath,
    String? thumbRelPath,
    int width = 0,
    int height = 0,
    int bytes = 0,
    DateTime? capturedAt,
  }) async {
    final captured = capturedAt ?? DateTime.now();
    final active =
        await database.tripsDao.findActiveFor(captured) ??
        await database.tripsDao.getEveryday();
    if (active == null) {
      throw StateError('Everyday trip has not been seeded');
    }
    final id = newId();
    final now = DateTime.now();
    final normalizedCaption = caption?.trim();
    await database.transaction(() async {
      await database.momentsDao.insertMoment(
        MomentsCompanion.insert(
          id: id,
          tripId: active.id,
          caption: normalizedCaption == null || normalizedCaption.isEmpty
              ? const Value.absent()
              : Value(normalizedCaption),
          capturedAt: captured,
          latitude: Value(latitude),
          longitude: Value(longitude),
          accuracyM: Value(accuracyM),
          placeLabel: Value(placeLabel),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (relPath != null) {
        final validatedRelPath = PhotoStore.validateRelativePath(relPath);
        final validatedThumbPath = PhotoStore.validateRelativePath(
          thumbRelPath ?? relPath,
        );
        await database.photosDao.insertPhoto(
          PhotosCompanion.insert(
            id: newId(),
            momentId: id,
            relPath: validatedRelPath,
            thumbRelPath: validatedThumbPath,
            width: width,
            height: height,
            bytes: bytes,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
    await _refreshAll();
    return _moments.firstWhere((moment) => moment.id == id);
  }

  Future<void> addTrip(
    String title,
    String? place,
    DateTime? start,
    DateTime? end,
  ) async {
    final now = DateTime.now();
    await database.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: newId(),
        title: title.trim(),
        place: Value(place?.trim().isEmpty == true ? null : place?.trim()),
        startDate: Value(start),
        endDate: Value(end),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _refreshAll();
  }

  Future<void> softDeleteMoment(String id) async {
    await database.momentsDao.softDelete(id, DateTime.now());
    await _refreshAll();
  }

  Future<void> upsertImportedTrip(
    Trip trip,
    List<Moment> importedMoments,
  ) async {
    final now = DateTime.now();
    await database.transaction(() async {
      final tripValues = TripsCompanion(
        id: Value(trip.id),
        title: Value(trip.title),
        place: Value(trip.place),
        description: Value(trip.description),
        startDate: Value(trip.startDate),
        endDate: Value(trip.endDate),
        coverMomentId: Value(trip.coverMomentId),
        isEveryday: Value(trip.isEveryday),
        tagsJson: Value(trip.tagsJson),
        createdAt: Value(trip.createdAt ?? now),
        updatedAt: Value(now),
      );
      if (await database.tripsDao.byId(trip.id) == null) {
        await database.tripsDao.insertTrip(tripValues);
      } else {
        await database.tripsDao.updateTrip(trip.id, tripValues);
      }
      for (final moment in importedMoments) {
        final existing = await database.momentsDao.byId(moment.id);
        final values = MomentsCompanion(
          id: Value(moment.id),
          tripId: Value(moment.tripId),
          caption: Value(moment.caption),
          capturedAt: Value(moment.capturedAt),
          latitude: Value(moment.latitude),
          longitude: Value(moment.longitude),
          accuracyM: Value(moment.accuracyM),
          placeLabel: Value(moment.placeLabel),
          sortIndex: Value(moment.sortIndex),
          createdAt: Value(moment.createdAt ?? now),
          updatedAt: Value(now),
        );
        if (existing == null) {
          await database.momentsDao.insertMoment(values);
        } else {
          await database.momentsDao.updateMoment(moment.id, values);
        }
        if (moment.relPath != null &&
            await database.photosDao.firstForMoment(moment.id) == null) {
          await database.photosDao.insertPhoto(
            PhotosCompanion.insert(
              id: newId(),
              momentId: moment.id,
              relPath: PhotoStore.validateRelativePath(moment.relPath!),
              thumbRelPath: PhotoStore.validateRelativePath(
                moment.thumbRelPath ?? moment.relPath!,
              ),
              width: moment.width,
              height: moment.height,
              bytes: moment.bytes,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    });
    await _refreshAll();
  }

  /// Synchronous snapshot search retained for existing export/UI callers.
  List<Moment> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return moments;
    return moments.where((moment) {
      final trip = _trips.firstWhere(
        (item) => item.id == moment.tripId,
        orElse: () => everyday,
      );
      return [
        moment.caption,
        moment.placeLabel,
        trip.title,
        trip.place,
      ].whereType<String>().any((text) => text.toLowerCase().contains(needle));
    }).toList();
  }

  Future<List<Moment>> searchAsync(String query) async {
    final hits = await database.searchDao.search(query);
    if (hits.isEmpty) return query.trim().isEmpty ? moments : const [];
    final momentIds = hits
        .where((hit) => hit.entityType == 'moment')
        .map((hit) => hit.entityId)
        .toSet();
    final direct = _moments.where((moment) => momentIds.contains(moment.id));
    final tripIds = hits
        .where((hit) => hit.entityType == 'trip')
        .map((hit) => hit.entityId)
        .toSet();
    final fromTrips = _moments.where(
      (moment) => tripIds.contains(moment.tripId),
    );
    return {...direct, ...fromTrips}.toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_profileSubscription?.cancel());
    unawaited(_tripsSubscription?.cancel());
    unawaited(_momentsSubscription?.cancel());
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (_isDisposed) return;
    final profile = await database.profilesDao.getActive();
    if (_isDisposed) return;
    if (profile == null) throw StateError('Active profile is missing');
    _profile = _profileFromRow(profile);
    _trips = (await database.tripsDao.getActive())
        .map(_tripFromRow)
        .toList(growable: false);
    await _refreshMoments(await database.momentsDao.getActive(), notify: false);
    notifyListeners();
  }

  Future<void> _refreshMoments(
    List<MomentRow> rows, {
    bool notify = true,
  }) async {
    if (_isDisposed) return;
    _moments = (await Future.wait(
      rows.map(_momentFromRow),
    )).toList(growable: false);
    if (notify && !_isDisposed) notifyListeners();
  }

  Future<Moment> _momentFromRow(MomentRow row) async {
    final photo = await database.photosDao.firstForMoment(row.id);
    return Moment(
      id: row.id,
      tripId: row.tripId,
      capturedAt: row.capturedAt,
      caption: row.caption,
      latitude: row.latitude,
      longitude: row.longitude,
      accuracyM: row.accuracyM,
      placeLabel: row.placeLabel,
      sortIndex: row.sortIndex,
      relPath: photo?.relPath,
      thumbRelPath: photo?.thumbRelPath,
      width: photo?.width ?? 0,
      height: photo?.height ?? 0,
      bytes: photo?.bytes ?? 0,
      deletedAt: row.deletedAt,
      authorId: row.authorId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Profile _profileFromRow(ProfileRow row) => Profile(
    id: row.id,
    name: row.name,
    avatarRelPath: row.avatarRelPath,
    bio: row.bio,
    authorId: row.authorId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  Trip _tripFromRow(TripRow row) => Trip(
    id: row.id,
    title: row.title,
    place: row.place,
    description: row.description,
    startDate: row.startDate,
    endDate: row.endDate,
    coverMomentId: row.coverMomentId,
    isEveryday: row.isEveryday,
    tagsJson: row.tagsJson,
    deletedAt: row.deletedAt,
    updatedAt: row.updatedAt,
    authorId: row.authorId,
    createdAt: row.createdAt,
  );
}
