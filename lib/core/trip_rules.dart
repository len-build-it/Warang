import 'models.dart';

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// True when [at] falls on any calendar day from [start] through [end].
///
/// Both ends are whole days: a trip ending on the 19th still receives a photo
/// taken at 23:59 on the 19th.
bool coversDay(DateTime start, DateTime end, DateTime at) {
  final from = _day(start);
  final until = _day(end).add(const Duration(days: 1));
  return !at.isBefore(from) && at.isBefore(until);
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
