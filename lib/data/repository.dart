import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';

class WarangRepository extends ChangeNotifier {
  WarangRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _profileKey = 'warang.profile';
  static const _tripsKey = 'warang.trips';
  static const _momentsKey = 'warang.moments';
  final _uuid = const Uuid();
  late Profile _profile;
  late List<Trip> _trips;
  late List<Moment> _moments;

  Future<void> initialize() async {
    final profileJson = _preferences.getString(_profileKey);
    _profile = profileJson == null
        ? Profile(id: _uuid.v4(), name: '')
        : Profile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
    final tripsJson = _preferences.getString(_tripsKey);
    _trips = tripsJson == null
        ? []
        : (jsonDecode(tripsJson) as List<dynamic>)
              .map((item) => Trip.fromJson(item as Map<String, dynamic>))
              .toList();
    final momentsJson = _preferences.getString(_momentsKey);
    _moments = momentsJson == null
        ? []
        : (jsonDecode(momentsJson) as List<dynamic>)
              .map((item) => Moment.fromJson(item as Map<String, dynamic>))
              .toList();
    if (_trips
        .where((trip) => trip.isEveryday && trip.deletedAt == null)
        .isEmpty) {
      _trips.add(
        Trip(
          id: _uuid.v4(),
          title: 'Everyday',
          isEveryday: true,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _persist();
  }

  Profile get profile => _profile;
  List<Trip> get trips =>
      List.unmodifiable(_trips.where((trip) => trip.deletedAt == null));
  List<Moment> get moments =>
      List.unmodifiable(_moments.where((moment) => moment.deletedAt == null));
  Trip get everyday => trips.firstWhere((trip) => trip.isEveryday);

  Future<void> setName(String name) async {
    _profile = Profile(
      id: _profile.id,
      name: name.trim(),
      avatarRelPath: _profile.avatarRelPath,
    );
    await _persist();
  }

  Future<Moment> addMoment({
    String? caption,
    double? latitude,
    double? longitude,
    String? placeLabel,
    String? relPath,
    DateTime? capturedAt,
  }) async {
    final active = _activeTrip(DateTime.now()) ?? everyday;
    final moment = Moment(
      id: _uuid.v4(),
      tripId: active.id,
      caption: caption?.trim().isEmpty == true ? null : caption?.trim(),
      latitude: latitude,
      longitude: longitude,
      placeLabel: placeLabel,
      relPath: relPath,
      capturedAt: capturedAt ?? DateTime.now(),
    );
    _moments.add(moment);
    await _persist();
    return moment;
  }

  Future<void> addTrip(
    String title,
    String? place,
    DateTime? start,
    DateTime? end,
  ) async {
    _trips.add(
      Trip(
        id: _uuid.v4(),
        title: title.trim(),
        place: place?.trim().isEmpty == true ? null : place?.trim(),
        startDate: start,
        endDate: end,
        updatedAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  Future<void> softDeleteMoment(String id) async {
    final index = _moments.indexWhere((moment) => moment.id == id);
    if (index == -1) return;
    final current = _moments[index];
    _moments[index] = Moment(
      id: current.id,
      tripId: current.tripId,
      capturedAt: current.capturedAt,
      caption: current.caption,
      latitude: current.latitude,
      longitude: current.longitude,
      placeLabel: current.placeLabel,
      relPath: current.relPath,
      deletedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> upsertImportedTrip(
    Trip trip,
    List<Moment> importedMoments,
  ) async {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index == -1) {
      _trips.add(trip);
    } else {
      _trips[index] = trip;
    }
    for (final moment in importedMoments) {
      final momentIndex = _moments.indexWhere((item) => item.id == moment.id);
      if (momentIndex == -1) {
        _moments.add(moment);
      } else {
        _moments[momentIndex] = moment;
      }
    }
    await _persist();
  }

  List<Moment> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return moments;
    return moments.where((moment) {
      final trip = trips.firstWhere(
        (trip) => trip.id == moment.tripId,
        orElse: () => everyday,
      );
      return [
        moment.caption,
        moment.placeLabel,
        trip.title,
      ].whereType<String>().any((text) => text.toLowerCase().contains(needle));
    }).toList();
  }

  Trip? _activeTrip(DateTime day) {
    final candidates = trips.where(
      (trip) =>
          !trip.isEveryday &&
          trip.startDate != null &&
          trip.endDate != null &&
          !day.isBefore(trip.startDate!) &&
          !day.isAfter(trip.endDate!),
    );
    return candidates.isEmpty
        ? null
        : candidates.reduce(
            (a, b) =>
                (a.updatedAt ?? DateTime(0)).isAfter(b.updatedAt ?? DateTime(0))
                ? a
                : b,
          );
  }

  Future<void> _persist() async {
    await _preferences.setString(_profileKey, jsonEncode(_profile.toJson()));
    await _preferences.setString(
      _tripsKey,
      jsonEncode(_trips.map((trip) => trip.toJson()).toList()),
    );
    await _preferences.setString(
      _momentsKey,
      jsonEncode(_moments.map((moment) => moment.toJson()).toList()),
    );
    notifyListeners();
  }
}
