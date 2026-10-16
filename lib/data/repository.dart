import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../core/ids.dart';
import '../core/models.dart';
import '../core/trip_rules.dart';
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

  /// The trip a capture at [at] is saved into: a dated trip covering that
  /// day, otherwise Everyday.
  Trip tripForCapture(DateTime at) => activeTripFor(at, _trips) ?? everyday;

  /// Stores [photo] and records it as a new moment.
  ///
  /// If recording fails after the photo is stored, the stored files are
  /// removed so no orphan is left behind, and the error is rethrown.
  Future<Moment> captureMoment({
    required File photo,
    String? caption,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
  }) async {
    final stored = await photoStore.importPhotoAsset(photo);
    try {
      return await addMoment(
        caption: caption,
        latitude: latitude,
        longitude: longitude,
        relPath: stored.relPath,
        thumbRelPath: stored.thumbRelPath,
        width: stored.width,
        height: stored.height,
        bytes: stored.bytes,
        capturedAt: capturedAt,
      );
    } catch (_) {
      await photoStore.discard(stored);
      rethrow;
    }
  }

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
    _checkTripFields(title, start, end);
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

  /// Changes a user trip's details. Everyday cannot be edited.
  Future<void> updateTrip(
    String id, {
    required String title,
    String? place,
    DateTime? start,
    DateTime? end,
  }) async {
    _userTrip(id);
    _checkTripFields(title, start, end);
    final cleanPlace = place?.trim();
    await database.tripsDao.updateTrip(
      id,
      TripsCompanion(
        title: Value(title.trim()),
        place: Value(
          cleanPlace == null || cleanPlace.isEmpty ? null : cleanPlace,
        ),
        startDate: Value(start),
        endDate: Value(end),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  /// Soft-deletes a user trip and moves its moments to Everyday, so no
  /// photograph is lost with the trip.
  Future<void> deleteTrip(String id) async {
    _userTrip(id);
    final now = DateTime.now();
    final everydayId = everyday.id;
    await database.transaction(() async {
      await database.momentsDao.reassignTrip(id, everydayId, now);
      await database.tripsDao.softDelete(id, now);
    });
    await _refreshAll();
  }

  Trip _userTrip(String id) {
    final trip = _trips.where((trip) => trip.id == id).firstOrNull;
    if (trip == null) throw ArgumentError.value(id, 'id', 'Unknown trip');
    if (trip.isEveryday) {
      throw ArgumentError.value(id, 'id', 'Everyday cannot be changed');
    }
    return trip;
  }

  void _checkTripFields(String title, DateTime? start, DateTime? end) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Trip name is required');
    }
    if ((start == null) != (end == null)) {
      throw ArgumentError('A trip needs both dates or neither');
    }
    if (start != null && end != null && end.isBefore(start)) {
      throw ArgumentError('A trip cannot end before it starts');
    }
  }

  Future<void> softDeleteMoment(String id) async {
    await database.momentsDao.softDelete(id, DateTime.now());
    await _refreshAll();
  }

  /// Brings back a moment deleted earlier in this session. Photos stay on
  /// disk until the next launch's orphan sweep, so an undo is lossless.
  Future<void> restoreMoment(String id) async {
    await database.momentsDao.updateMoment(
      id,
      MomentsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  /// Replaces the editable text and trip of a moment. Blank text clears the
  /// field.
  Future<void> updateMoment(
    String id, {
    required String caption,
    required String placeLabel,
    required String tripId,
  }) async {
    if (!_trips.any((trip) => trip.id == tripId)) {
      throw ArgumentError.value(tripId, 'tripId', 'Unknown trip');
    }
    String? clean(String value) => value.trim().isEmpty ? null : value.trim();
    await database.momentsDao.updateMoment(
      id,
      MomentsCompanion(
        caption: Value(clean(caption)),
        placeLabel: Value(clean(placeLabel)),
        tripId: Value(tripId),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  /// Pins a moment to a manually chosen spot.
  Future<void> setMomentLocation(
    String id,
    double latitude,
    double longitude,
  ) async {
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw RangeError('Coordinates out of range: $latitude, $longitude');
    }
    await database.momentsDao.updateMoment(
      id,
      MomentsCompanion(
        latitude: Value(latitude),
        longitude: Value(longitude),
        accuracyM: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
