import 'package:latlong2/latlong.dart';

import 'models.dart';

/// A moment worth a small cheer (M4). Milestones are only celebrated, never
/// counted down, chained, or shown as missed (M5).
enum MilestoneKind { firstMoment, firstInTrip, somewhereNew, categoryStamp }

class Milestone {
  const Milestone(this.kind, this.key, this.message);

  final MilestoneKind kind;

  /// Stored once shown, so the same milestone never shows twice.
  final String key;
  final String message;
}

/// How far a moment must be from every earlier one to be somewhere new.
const somewhereNewMetres = 25000.0;

/// The milestone [moment] reaches, given the moments saved before it and its
/// [trip]. It needs no network and no geocoding. The first moment ever comes
/// first, then the first in a trip, then somewhere new.
Milestone? milestoneFor(Moment moment, Iterable<Moment> earlier, Trip? trip) {
  final before = earlier.where((other) => other.id != moment.id).toList();
  if (before.isEmpty) {
    return const Milestone(
      MilestoneKind.firstMoment,
      'first-moment',
      'Your first moment!',
    );
  }
  if (trip != null &&
      !trip.isEveryday &&
      !before.any((other) => other.tripId == trip.id)) {
    return Milestone(
      MilestoneKind.firstInTrip,
      'first-in-trip:${trip.id}',
      'First moment in ${trip.title}!',
    );
  }
  final latitude = moment.latitude;
  final longitude = moment.longitude;
  if (latitude == null || longitude == null) return null;
  final placed = [
    for (final other in before)
      if (other.latitude != null && other.longitude != null)
        LatLng(other.latitude!, other.longitude!),
  ];
  if (placed.isEmpty) return null;
  const distance = Distance();
  final here = LatLng(latitude, longitude);
  final far = placed.every(
    (point) => distance.as(LengthUnit.Meter, here, point) > somewhereNewMetres,
  );
  return far
      ? Milestone(
          MilestoneKind.somewhereNew,
          'somewhere-new:${moment.id}',
          'Somewhere new!',
        )
      : null;
}
