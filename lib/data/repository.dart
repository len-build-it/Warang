import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../core/ids.dart';
import '../core/milestones.dart';
import '../core/models.dart';
import '../core/trip_rules.dart';
import 'db/database.dart';
import 'files/photo_store.dart';
import 'places/place_book.dart';

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
  List<Place> _places = const [];
  Map<String, Place> _placesById = const {};
  List<Moment> _moments = const [];
  StreamSubscription<ProfileRow?>? _profileSubscription;
  StreamSubscription<List<TripRow>>? _tripsSubscription;
  StreamSubscription<List<PlaceRow>>? _placesSubscription;
  StreamSubscription<List<MomentRow>>? _momentsSubscription;
  bool _isDisposed = false;

  Future<void> initialize() async {
    await database.seedDefaults();
    await _refreshAll();
    await _profileSubscription?.cancel();
    await _tripsSubscription?.cancel();
    await _placesSubscription?.cancel();
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
    _placesSubscription = database.placesDao.watchActive().listen((rows) {
      if (_isDisposed) return;
      _setPlaces(rows);
      _remapMomentPlaces();
      notifyListeners();
    });
    _momentsSubscription = database.momentsDao.watchActive().listen((rows) {
      if (_isDisposed) return;
      unawaited(_refreshMoments(rows));
    });
  }

  Profile get profile => _profile;

  List<Trip> get trips => List.unmodifiable(_trips);

  List<Place> get places => List.unmodifiable(_places);

  Place? placeById(String? id) => id == null ? null : _placesById[id];

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
    double? accuracyM,
    BookPlace? place,
    DateTime? capturedAt,
  }) async {
    final stored = await photoStore.importPhotoAsset(photo);
    try {
      return await addMoment(
        caption: caption,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        place: place,
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
    BookPlace? place,
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
      String? placeId;
      if (place != null) {
        placeId = await _ensureBookPlace(place, now);
      } else if (placeLabel != null && placeLabel.trim().isNotEmpty) {
        placeId = await _ensureUserPlace(placeLabel, now);
      }
      await database.momentsDao.insertMoment(
        MomentsCompanion.insert(
          id: id,
          tripId: active.id,
          placeId: Value(placeId),
          caption: normalizedCaption == null || normalizedCaption.isEmpty
              ? const Value.absent()
              : Value(normalizedCaption),
          capturedAt: captured,
          latitude: Value(latitude),
          longitude: Value(longitude),
          accuracyM: Value(accuracyM),
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

  /// Copies [place] from the place book into `Places` if not already present,
  /// and attaches it to [momentId].
  Future<Place> attachBookPlace(String momentId, BookPlace place) async {
    final now = DateTime.now();
    late final String placeId;
    await database.transaction(() async {
      placeId = await _ensureBookPlace(place, now);
      await database.momentsDao.updateMoment(
        momentId,
        MomentsCompanion(placeId: Value(placeId), updatedAt: Value(now)),
      );
    });
    await _refreshAll();
    return _placesById[placeId]!;
  }

  /// Attaches a user-typed place name to [momentId], reusing any existing user
  /// place with the same trimmed lower-cased name. A blank name clears the place.
  Future<Place?> attachUserPlace(String momentId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await clearPlace(momentId);
      return null;
    }
    final now = DateTime.now();
    late final String placeId;
    await database.transaction(() async {
      placeId = await _ensureUserPlace(trimmed, now);
      await database.momentsDao.updateMoment(
        momentId,
        MomentsCompanion(placeId: Value(placeId), updatedAt: Value(now)),
      );
    });
    await _refreshAll();
    return _placesById[placeId];
  }

  /// Detaches any place from [momentId].
  Future<void> clearPlace(String momentId) async {
    await database.momentsDao.updateMoment(
      momentId,
      MomentsCompanion(
        placeId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  /// Sets or clears the category for [placeId], updating every moment there.
  Future<void> setPlaceCategory(String placeId, String? categoryKey) async {
    await database.placesDao.updatePlace(
      placeId,
      PlacesCompanion(
        categoryKey: Value(categoryKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  Future<String> _ensureBookPlace(BookPlace place, DateTime now) async {
    final existing = await database.placesDao.findBySourceRef(place.osmRef);
    if (existing != null) return existing.id;
    final placeId = newId();
    await database.placesDao.insertPlace(
      PlacesCompanion.insert(
        id: placeId,
        name: place.name.trim(),
        categoryKey: Value(place.category),
        latitude: Value(place.latitude),
        longitude: Value(place.longitude),
        source: 'book',
        sourceRef: Value(place.osmRef),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return placeId;
  }

  Future<String> _ensureUserPlace(
    String name,
    DateTime now, {
    String? categoryKey,
  }) async {
    final trimmed = name.trim();
    final existing = await database.placesDao.findUserByLowerName(
      trimmed.toLowerCase(),
    );
    if (existing != null) return existing.id;
    final placeId = newId();
    await database.placesDao.insertPlace(
      PlacesCompanion.insert(
        id: placeId,
        name: trimmed,
        categoryKey: Value(categoryKey),
        source: 'user',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return placeId;
  }

  static const _milestonesKey = 'milestonesShown';

  /// The milestone [moment] reaches, if it has not been shown before. It is
  /// recorded as shown, so each one fires once (REQ-020).
  Future<Milestone?> claimMilestone(Moment moment) async {
    final trip = _trips.where((trip) => trip.id == moment.tripId).firstOrNull;
    final milestone = milestoneFor(moment, _moments, trip);
    if (milestone == null) return null;
    final raw = await database.appMetaDao.readValue(_milestonesKey);
    final shown = raw == null
        ? <String>[]
        : (jsonDecode(raw) as List<dynamic>).cast<String>();
    if (shown.contains(milestone.key)) return null;
    await database.appMetaDao.writeValue(
      _milestonesKey,
      jsonEncode([...shown, milestone.key]),
      DateTime.now(),
    );
    return milestone;
  }

  /// The colour a new trip gets unless the user picks another: the one
  /// after the most recently created trip's.
  Future<String> nextTripColor() async =>
      nextTripColorKey(await database.tripsDao.latestColorKey());

  Future<void> addTrip(
    String title,
    String? place,
    DateTime? start,
    DateTime? end, {
    String? colorKey,
  }) async {
    _checkTripFields(title, start, end);
    _checkColorKey(colorKey);
    final now = DateTime.now();
    final colour = colorKey ?? await nextTripColor();
    await database.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: newId(),
        title: title.trim(),
        place: Value(place?.trim().isEmpty == true ? null : place?.trim()),
        startDate: Value(start),
        endDate: Value(end),
        colorKey: Value(colour),
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
    String? colorKey,
  }) async {
    _userTrip(id);
    _checkTripFields(title, start, end);
    _checkColorKey(colorKey);
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
        colorKey: colorKey == null ? const Value.absent() : Value(colorKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshAll();
  }

  void _checkColorKey(String? colorKey) {
    if (colorKey != null && !tripColorKeys.contains(colorKey)) {
      throw ArgumentError.value(colorKey, 'colorKey', 'Unknown trip colour');
    }
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
    final now = DateTime.now();
    await database.transaction(() async {
      final cleanLabel = clean(placeLabel);
      final placeId = cleanLabel == null
          ? null
          : await _ensureUserPlace(cleanLabel, now);
      await database.momentsDao.updateMoment(
        id,
        MomentsCompanion(
          caption: Value(clean(caption)),
          placeId: Value(placeId),
          tripId: Value(tripId),
          updatedAt: Value(now),
        ),
      );
    });
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
        colorKey: Value(trip.colorKey),
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
        final cleanLabel = moment.placeLabel?.trim();
        final placeId = (cleanLabel != null && cleanLabel.isNotEmpty)
            ? await _ensureUserPlace(
                cleanLabel,
                now,
                categoryKey: moment.placeCategory,
              )
            : null;
        final values = MomentsCompanion(
          id: Value(moment.id),
          tripId: Value(moment.tripId),
          placeId: Value(placeId),
          caption: Value(moment.caption),
          capturedAt: Value(moment.capturedAt),
          latitude: Value(moment.latitude),
          longitude: Value(moment.longitude),
          accuracyM: Value(moment.accuracyM),
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
    unawaited(_placesSubscription?.cancel());
    unawaited(_momentsSubscription?.cancel());
    super.dispose();
  }

  void _setPlaces(List<PlaceRow> rows) {
    final list = rows.map(_placeFromRow).toList(growable: false);
    _places = list;
    _placesById = {for (final place in list) place.id: place};
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
    _setPlaces(await database.placesDao.getActive());
    await _refreshMoments(await database.momentsDao.getActive(), notify: false);
    notifyListeners();
  }

  void _remapMomentPlaces() {
    if (_moments.isEmpty) return;
    _moments = _moments
        .map((moment) {
          final place = moment.placeId == null
              ? null
              : _placesById[moment.placeId!];
          return Moment(
            id: moment.id,
            tripId: moment.tripId,
            capturedAt: moment.capturedAt,
            placeId: place?.id,
            placeCategory: place?.categoryKey,
            caption: moment.caption,
            latitude: moment.latitude,
            longitude: moment.longitude,
            accuracyM: moment.accuracyM,
            placeLabel: place?.name,
            sortIndex: moment.sortIndex,
            relPath: moment.relPath,
            thumbRelPath: moment.thumbRelPath,
            width: moment.width,
            height: moment.height,
            bytes: moment.bytes,
            deletedAt: moment.deletedAt,
            authorId: moment.authorId,
            createdAt: moment.createdAt,
            updatedAt: moment.updatedAt,
          );
        })
        .toList(growable: false);
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
    final place = row.placeId == null ? null : _placesById[row.placeId!];
    return Moment(
      id: row.id,
      tripId: row.tripId,
      capturedAt: row.capturedAt,
      placeId: place?.id,
      placeCategory: place?.categoryKey,
      caption: row.caption,
      latitude: row.latitude,
      longitude: row.longitude,
      accuracyM: row.accuracyM,
      placeLabel: place?.name,
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
    colorKey: row.colorKey,
    deletedAt: row.deletedAt,
    updatedAt: row.updatedAt,
    authorId: row.authorId,
    createdAt: row.createdAt,
  );

  Place _placeFromRow(PlaceRow row) => Place(
    id: row.id,
    name: row.name,
    categoryKey: row.categoryKey,
    latitude: row.latitude,
    longitude: row.longitude,
    source: row.source,
    sourceRef: row.sourceRef,
    deletedAt: row.deletedAt,
    updatedAt: row.updatedAt,
    authorId: row.authorId,
    createdAt: row.createdAt,
  );
}
