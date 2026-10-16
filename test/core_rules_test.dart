import 'package:flutter_test/flutter_test.dart';
import 'package:warang/core/formatting.dart';
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

  group('formatCoordinates', () {
    test('uses hemispheres and three decimals', () {
      expect(formatCoordinates(11.96864, 121.91804), '11.969°N · 121.918°E');
      expect(formatCoordinates(-33.8688, -70.6693), '33.869°S · 70.669°W');
    });
  });
}
