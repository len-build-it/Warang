import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../core/ids.dart';
import '../core/milestones.dart';
import '../core/models.dart';
import '../core/stamps.dart';
import '../core/trip_rules.dart';
import '../features/stamps/stamp_titles.dart';
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
  int _revision = 0;

  /// Monotonically incremented whenever repository state changes.
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

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
    final previousAvatar = _profile.avatarRelPath;
    final relativePath = await photoStore.importAvatar(source);
    try {
      await database.profilesDao.updateProfile(
        _profile.id,
        ProfilesCompanion(
          avatarRelPath: Value(relativePath),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (_) {
      await _deleteAvatarBestEffort(relativePath);
      rethrow;
    }
    await _refreshAll();
    if (previousAvatar != null &&
        previousAvatar.isNotEmpty &&
        previousAvatar != relativePath) {
      await _deleteAvatarBestEffort(previousAvatar);
    }
  }

  Future<void> _deleteAvatarBestEffort(String relativePath) async {
    try {
      final file = await photoStore.resolve(relativePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best-effort cleanup of superseded or uncommitted avatar files.
    } on ArgumentError {
      // Ignore malformed stored paths during cleanup.
    }
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
    final attached = _placesById[placeId];
    if (attached == null) {
      throw StateError('Book place $placeId missing after refresh');
    }
    return attached;
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

  /// Updates caption, trip, place, and place category for [momentId] in one
  /// transaction so partial edits never persist on failure.
  Future<void> editMomentDetails(
    String momentId, {
    String? caption,
    String? tripId,
    bool clearPlace = false,
    BookPlace? bookPlace,
    String? userPlaceName,
    String? initialPlaceId,
    String? categoryKey,
    bool updateCategory = false,
  }) async {
    final now = DateTime.now();
    final normalizedCaption = caption?.trim();
    await database.transaction(() async {
      String? targetPlaceId = initialPlaceId;
      Value<String?> placeIdValue = const Value.absent();
      if (clearPlace) {
        placeIdValue = const Value(null);
        targetPlaceId = null;
      } else if (bookPlace != null) {
        targetPlaceId = await _ensureBookPlace(bookPlace, now);
        placeIdValue = Value(targetPlaceId);
      } else if (userPlaceName != null) {
        final trimmed = userPlaceName.trim();
        if (trimmed.isEmpty) {
          placeIdValue = const Value(null);
          targetPlaceId = null;
        } else {
          targetPlaceId = await _ensureUserPlace(trimmed, now);
          placeIdValue = Value(targetPlaceId);
        }
      }
      await database.momentsDao.updateMoment(
        momentId,
        MomentsCompanion(
          caption: caption == null
              ? const Value.absent()
              : Value(normalizedCaption!.isEmpty ? null : normalizedCaption),
          tripId: tripId == null ? const Value.absent() : Value(tripId),
          placeId: placeIdValue,
          updatedAt: Value(now),
        ),
      );
      if (updateCategory && targetPlaceId != null) {
        await database.placesDao.updatePlace(
          targetPlaceId,
          PlacesCompanion(
            categoryKey: Value(categoryKey),
            updatedAt: Value(now),
          ),
        );
      }
    });
    await _refreshAll();
  }

  /// Sets [momentId]'s map coordinates and optional book place in one
  /// transaction.
  Future<void> placeMoment(
    String momentId,
    double latitude,
    double longitude, {
    BookPlace? place,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      Value<String?> placeIdValue = const Value.absent();
      if (place != null) {
        final placeId = await _ensureBookPlace(place, now);
        placeIdValue = Value(placeId);
      }
      await database.momentsDao.updateMoment(
        momentId,
        MomentsCompanion(
          latitude: Value(latitude),
          longitude: Value(longitude),
          placeId: placeIdValue,
          updatedAt: Value(now),
        ),
      );
    });
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

  /// Milestones [moment] reaches, if they have not been shown before: the
  /// FEAT-003 milestone first, then any newly reached category stamp tiers
  /// (`stamp:<category>:<tier>`). Each key is recorded as shown so it fires
  /// once (FEAT-003 REQ-020, FEAT-004 REQ-025).
  Future<List<Milestone>> claimMilestone(
    Moment moment, {
    Map<String, List<String>>? stampTitles,
  }) async {
    final trip = _trips.where((trip) => trip.id == moment.tripId).firstOrNull;
    final milestone = milestoneFor(moment, _moments, trip);
    return _claimMilestones(baseMilestone: milestone, stampTitles: stampTitles);
  }

  /// Newly reached category stamp tiers after editing a moment's place or
  /// category (FEAT-004 F7, REQ-025).
  Future<List<Milestone>> claimCategoryStamps({
    Map<String, List<String>>? stampTitles,
  }) => _claimMilestones(stampTitles: stampTitles);

  Future<List<Milestone>> _claimMilestones({
    Milestone? baseMilestone,
    Map<String, List<String>>? stampTitles,
  }) async {
    final raw = await database.appMetaDao.readValue(_milestonesKey);
    final shown = <String>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is String) shown.add(item);
          }
        }
      } on FormatException {
        // Corrupt milestone JSON resets to an empty set.
      }
    }
    final shownSet = shown.toSet();
    final claimed = <Milestone>[];
    final newKeys = <String>[];

    if (baseMilestone != null && shownSet.add(baseMilestone.key)) {
      claimed.add(baseMilestone);
      newKeys.add(baseMilestone.key);
    }

    Map<String, List<String>> titles;
    if (stampTitles != null) {
      titles = stampTitles;
    } else {
      try {
        titles = await StampTitles.load();
      } on Exception catch (_) {
        titles = const {};
      }
    }

    final stamps = computeCategoryStamps(
      moments: _moments,
      places: _places,
      titles: titles,
    );
    for (final stamp in stamps) {
      if (shownSet.add(stamp.milestoneKey)) {
        claimed.add(
          Milestone(
            MilestoneKind.categoryStamp,
            stamp.milestoneKey,
            '${stamp.title}!',
          ),
        );
        newKeys.add(stamp.milestoneKey);
      }
    }

    if (newKeys.isNotEmpty) {
      await database.appMetaDao.writeValue(
        _milestonesKey,
        jsonEncode([...shown, ...newKeys]),
        DateTime.now(),
      );
    }
    return claimed;
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
        place: Value(
          (place?.trim().isEmpty ?? false) ? null : place?.trim(),
        ),
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

  /// Replaces the editable caption and trip of a moment. Blank text clears the
  /// caption.
  Future<void> updateMoment(
    String id, {
    required String caption,
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
