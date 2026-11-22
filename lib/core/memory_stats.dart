import 'models.dart';

/// Number of distinct non-blank place names the user has written.
int distinctPlaces(Iterable<Moment> moments) => moments
    .map((moment) => moment.placeLabel?.trim().toLowerCase())
    .whereType<String>()
    .where((place) => place.isNotEmpty)
    .toSet()
    .length;

/// The plain totals on the Trips shelf's stamps. Neutral totals only: no
/// goals, or anything that asks the user to keep up.
class MemoryStats {
  const MemoryStats({
    required this.moments,
    required this.places,
    required this.days,
  });

  factory MemoryStats.from(List<Moment> moments) => MemoryStats(
    moments: moments.length,
    places: distinctPlaces(moments),
    days: moments
        .map(
          (moment) => DateTime(
            moment.capturedAt.year,
            moment.capturedAt.month,
            moment.capturedAt.day,
          ),
        )
        .toSet()
        .length,
  );

  final int moments;
  final int places;

  /// Distinct calendar days with at least one capture.
  final int days;
}
