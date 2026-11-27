import 'models.dart';

/// The six trip colours of FEAT-003 V2, in the order trips receive them.
/// Amber is the action colour and never a trip's.
const tripColorKeys = [
  'gumamela',
  'dagat',
  'kalamansi',
  'ube',
  'langit',
  'santan',
];

/// The colour after [previous] in [tripColorKeys], starting over at the end.
String nextTripColorKey(String? previous) =>
    tripColorKeys[(tripColorKeys.indexOf(previous ?? '') + 1) %
        tripColorKeys.length];

/// A trip's colour key: its own, or for a trip without one, a key picked
/// from its id so it stays the same. Null for Everyday.
String? tripColorKey(Trip trip) {
  if (trip.isEveryday) return null;
  final own = trip.colorKey;
  if (own != null && tripColorKeys.contains(own)) return own;
  var hash = 0;
  for (final unit in trip.id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return tripColorKeys[hash % tripColorKeys.length];
}

DateTime _day(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// True when [at] falls on any calendar day from [start] through [end].
///
/// Both ends are whole days: a trip ending on the 19th still receives a photo
/// taken at 23:59 on the 19th.
bool coversDay(DateTime start, DateTime end, DateTime at) {
  final localAt = at.toLocal();
  final from = _day(start);
  final endDay = _day(end);
  final until = DateTime(endDay.year, endDay.month, endDay.day + 1);
  return !localAt.isBefore(from) && localAt.isBefore(until);
}

/// The dated trip that a capture at [at] belongs to, or null for Everyday.
///
/// When dated trips overlap, the most recently updated one wins.
Trip? activeTripFor(DateTime at, Iterable<Trip> trips) {
  Trip? best;
  for (final trip in trips) {
    final start = trip.startDate;
    final end = trip.endDate;
    if (trip.isEveryday || trip.deletedAt != null) continue;
    if (start == null || end == null || !coversDay(start, end, at)) continue;
    final updated = trip.updatedAt ?? DateTime(0);
    if (best == null || updated.isAfter(best.updatedAt ?? DateTime(0))) {
      best = trip;
    }
  }
  return best;
}
