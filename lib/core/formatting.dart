import 'package:intl/intl.dart';

/// Coordinates in the metadata voice, e.g. `11.969°N · 121.918°E`.
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

/// Short month name in sentence case, e.g. `Mar`.
String monthLabel(DateTime date) => DateFormat('MMM').format(date);

/// A clock time with a lowercase marker, e.g. `4:42 pm`.
String formatTime(DateTime date) =>
    DateFormat('h:mm a').format(date).toLowerCase();

/// A calendar date, e.g. `14 Mar 2026`.
String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// When a moment was captured, e.g. `Sat 14 Mar, 4:42 pm`.
///
/// The year is added only when it is not the current year.
String formatMomentTime(DateTime date, {DateTime? now}) {
  final thisYear = (now ?? DateTime.now()).year == date.year;
  final day = DateFormat(thisYear ? 'EEE d MMM' : 'EEE d MMM yyyy');
  return '${day.format(date)}, ${formatTime(date)}';
}

/// A compact trip range with a plain dash:
/// `12-19 Mar`, `30 Mar - 4 Apr`, or `30 Dec 2026 - 2 Jan 2027`.
String formatTripRange(DateTime start, DateTime end) {
  final day = DateFormat('d MMM');
  if (start.year != end.year) {
    return '${formatDate(start)} - ${formatDate(end)}';
  }
  if (start.month != end.month) {
    return '${day.format(start)} - ${day.format(end)}';
  }
  if (start.day == end.day) return day.format(start);
  return '${start.day}-${day.format(end)}';
}

/// A count with its noun, e.g. `1 moment` or `2 moments`.
String countLabel(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';
