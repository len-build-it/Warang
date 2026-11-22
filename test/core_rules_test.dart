import 'package:flutter_test/flutter_test.dart';
import 'package:warang/core/formatting.dart';
import 'package:warang/core/memory_stats.dart';
import 'package:warang/core/models.dart';
import 'package:warang/core/trip_rules.dart';

Trip _trip(
  String id, {
  DateTime? start,
  DateTime? end,
  DateTime? updated,
  bool everyday = false,
  DateTime? deleted,
}) => Trip(
  id: id,
  title: id,
  startDate: start,
  endDate: end,
  updatedAt: updated,
  isEveryday: everyday,
  deletedAt: deleted,
);

void main() {
  group('activeTripFor', () {
    final boracay = _trip(
      'boracay',
      start: DateTime(2026, 3, 12),
      end: DateTime(2026, 3, 19),
      updated: DateTime(2026, 3, 1),
    );

    test('includes the whole first and last day', () {
      expect(activeTripFor(DateTime(2026, 3, 12), [boracay]), boracay);
      expect(activeTripFor(DateTime(2026, 3, 19, 16, 42), [boracay]), boracay);
      expect(
        activeTripFor(DateTime(2026, 3, 19, 23, 59, 59, 999), [boracay]),
        boracay,
      );
    });

    test('excludes the days around the range', () {
      expect(activeTripFor(DateTime(2026, 3, 11, 23, 59), [boracay]), isNull);
      expect(activeTripFor(DateTime(2026, 3, 20), [boracay]), isNull);
    });

    test('ignores a start time inside the first day', () {
      final trip = _trip(
        'late start',
        start: DateTime(2026, 3, 12, 18),
        end: DateTime(2026, 3, 12, 8),
      );
      expect(activeTripFor(DateTime(2026, 3, 12, 9), [trip]), trip);
    });

    test('ignores undated, Everyday, and deleted trips', () {
      final undated = _trip('undated');
      final everyday = _trip(
        'everyday',
        everyday: true,
        start: DateTime(2026),
        end: DateTime(2027),
      );
      final deleted = _trip(
        'deleted',
        start: DateTime(2026),
        end: DateTime(2027),
        deleted: DateTime(2026, 2),
      );
      expect(
        activeTripFor(DateTime(2026, 3, 15), [undated, everyday, deleted]),
        isNull,
      );
    });

    test('prefers the most recently updated trip when ranges overlap', () {
      final newer = _trip(
        'newer',
        start: DateTime(2026, 3, 15),
        end: DateTime(2026, 3, 16),
        updated: DateTime(2026, 3, 2),
      );
      expect(activeTripFor(DateTime(2026, 3, 15), [boracay, newer]), newer);
      expect(activeTripFor(DateTime(2026, 3, 15), [newer, boracay]), newer);
    });
  });

  group('formatTripRange', () {
    test('uses plain dashes and drops repeated parts', () {
      expect(
        formatTripRange(DateTime(2026, 3, 12), DateTime(2026, 3, 19)),
        '12-19 Mar',
      );
      expect(
        formatTripRange(DateTime(2026, 3, 30), DateTime(2026, 4, 4)),
        '30 Mar - 4 Apr',
      );
      expect(
        formatTripRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        '30 Dec 2026 - 2 Jan 2027',
      );
      expect(
        formatTripRange(DateTime(2026, 3, 12), DateTime(2026, 3, 12)),
        '12 Mar',
      );
    });
  });

  group('sentence-case metadata', () {
    test('formats moment times, dates, and counts', () {
      final date = DateTime(2026, 3, 14, 16, 42);
      expect(
        formatMomentTime(date, now: DateTime(2026, 11, 21)),
        'Sat 14 Mar, 4:42 pm',
      );
      expect(
        formatMomentTime(date, now: DateTime(2027, 1, 2)),
        'Sat 14 Mar 2026, 4:42 pm',
      );
      expect(formatTime(DateTime(2026, 3, 14, 9, 5)), '9:05 am');
      expect(formatDate(date), '14 Mar 2026');
      expect(countLabel(1, 'moment'), '1 moment');
      expect(countLabel(2, 'moment'), '2 moments');
    });
  });

  group('MemoryStats', () {
    Moment moment(String id, DateTime at, {String? place}) =>
        Moment(id: id, tripId: 'everyday', capturedAt: at, placeLabel: place);

    test('counts totals, distinct days, and written places', () {
      final stats = MemoryStats.from([
        moment('a', DateTime(2026, 9, 1, 23, 59), place: 'White Beach'),
        moment('b', DateTime(2026, 9, 2, 0, 1), place: ' white beach '),
        moment('c', DateTime(2026, 9, 2, 10), place: '  '),
        moment('d', DateTime(2026, 3, 9), place: 'Malay'),
      ]);

      expect(stats.moments, 4);
      expect(stats.days, 3);
      expect(stats.places, 2);
    });
  });

  group('formatCoordinates', () {
    test('uses hemispheres and three decimals', () {
      expect(formatCoordinates(11.96864, 121.91804), '11.969°N · 121.918°E');
      expect(formatCoordinates(-33.8688, -70.6693), '33.869°S · 70.669°W');
    });
  });
}
