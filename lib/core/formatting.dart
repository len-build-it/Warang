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

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// A compact trip range in the metadata voice, with a plain dash:
/// `MAR 12-19`, `MAR 30 - APR 4`, or `DEC 30, 2026 - JAN 2, 2027`.
String formatTripRange(DateTime start, DateTime end) {
  String day(DateTime date) => '${_months[date.month - 1]} ${date.day}';
  if (start.year != end.year) {
    return '${day(start)}, ${start.year} - ${day(end)}, ${end.year}';
  }
  if (start.month != end.month) return '${day(start)} - ${day(end)}';
  if (start.day == end.day) return day(start);
  return '${day(start)}-${end.day}';
}
