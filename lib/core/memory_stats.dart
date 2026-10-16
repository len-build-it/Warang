import 'formatting.dart';
import 'models.dart';

/// Number of distinct non-blank place names the user has written.
int distinctPlaces(Iterable<Moment> moments) => moments
    .map((moment) => moment.placeLabel?.trim().toLowerCase())
    .whereType<String>()
    .where((place) => place.isNotEmpty)
    .toSet()
    .length;

/// Plain counts for the Home summaries. Neutral totals only: no streaks,
/// goals, or anything that asks the user to keep up.
class MemoryStats {
  const MemoryStats({
    required this.moments,
    required this.places,
    required this.days,
    required this.monthlyMoments,
    required this.cumulativeTrips,
    required this.monthLabels,
    required this.ready,
  });

  factory MemoryStats.from(
    List<Moment> moments, {
    required String everydayId,
    required DateTime now,
  }) {
    final starts = [
      for (var index = 5; index >= 0; index--)
        DateTime(now.year, now.month - index),
    ];
    final monthlyMoments = [
      for (final start in starts)
        moments
            .where(
              (moment) =>
                  moment.capturedAt.year == start.year &&
                  moment.capturedAt.month == start.month,
            )
            .length,
    ];
    final cumulativeTrips = [
      for (final start in starts)
        moments
            .where(
              (moment) =>
                  moment.tripId != everydayId &&
                  !DateTime(
                    moment.capturedAt.year,
                    moment.capturedAt.month,
                  ).isAfter(start),
            )
            .map((moment) => moment.tripId)
            .toSet()
            .length,
    ];
    final days = moments
        .map(
          (moment) => DateTime(
            moment.capturedAt.year,
            moment.capturedAt.month,
            moment.capturedAt.day,
          ),
        )
        .toSet();
    final sorted = [...moments.map((moment) => moment.capturedAt)]..sort();
    final span = sorted.isEmpty
        ? Duration.zero
        : sorted.last.difference(sorted.first);
    return MemoryStats(
      moments: moments.length,
      places: distinctPlaces(moments),
      days: days.length,
      monthlyMoments: monthlyMoments,
      cumulativeTrips: cumulativeTrips,
      monthLabels: [for (final start in starts) monthLabel(start)],
      ready: sorted.length >= 2 && span.inDays >= 7,
    );
  }

  final int moments;
  final int places;

  /// Distinct calendar days with at least one capture.
  final int days;
  final List<int> monthlyMoments;
  final List<int> cumulativeTrips;
  final List<String> monthLabels;

  /// True once there is enough history for the charts to mean something.
  final bool ready;
}
