/// Coordinates in the mono metadata voice, e.g. `11.969°N · 121.918°E`.
///
/// Three decimals place a pin to roughly 100 metres, which is as precise as
/// a one-shot phone fix deserves.
String formatCoordinates(double latitude, double longitude) {
  final lat =
      '${latitude.abs().toStringAsFixed(3)}°${latitude < 0 ? 'S' : 'N'}';
  final lng =
      '${longitude.abs().toStringAsFixed(3)}°${longitude < 0 ? 'W' : 'E'}';
  return '$lat · $lng';
}
