import 'models.dart';

/// Number of distinct places attached to moments.
///
/// Counts distinct non-deleted place ids when present, falling back to
/// trimmed lower-cased names for synthetic in-memory moments without a place id.
int distinctPlaces(Iterable<Moment> moments) {
  final keys = <String>{};
  for (final moment in moments) {
    final placeId = moment.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      keys.add('id:$placeId');
      continue;
    }
    final label = moment.placeLabel?.trim().toLowerCase();
    if (label != null && label.isNotEmpty) {
      keys.add('name:$label');
    }
  }
  return keys.length;
}

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
