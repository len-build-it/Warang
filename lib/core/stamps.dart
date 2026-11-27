import 'dart:convert';

import 'models.dart';

/// The twelve FEAT-004 D-4 categories that earn keepsake stamps.
/// `transit` and `town` never earn stamps (REQ-023).
const Set<String> stampCategoryKeys = <String>{
  'cafe',
  'food',
  'sweets',
  'nightlife',
  'beach',
  'island',
  'nature',
  'park',
  'church',
  'heritage',
  'market',
  'stay',
};

/// Tier thresholds from FEAT-004 D-3: (tier, minVisits, minPlaces).
const List<({int tier, int visits, int places})> stampTierThresholds = [
  (tier: 4, visits: 50, places: 25),
  (tier: 3, visits: 25, places: 12),
  (tier: 2, visits: 10, places: 5),
  (tier: 1, visits: 3, places: 2),
];

/// Parses the bundled `assets/data/stamps.json` document into a map of
/// category key -> list of four tier titles.
Map<String, List<String>> parseStampTitles(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, Object?>) return const {};
  final result = <String, List<String>>{};
  for (final entry in decoded.entries) {
    if (entry.value case final List<Object?> items) {
      result[entry.key] = [
        for (final item in items)
          if (item is String) item,
      ];
    }
  }
  return result;
}

/// Visits to one place inside a category stamp.
class PlaceVisitCount {
  const PlaceVisitCount({
    required this.placeId,
    required this.placeName,
    required this.visits,
    required this.firstVisit,
  });

  final String placeId;
  final String placeName;
  final int visits;
  final DateTime firstVisit;
}

/// A derived keepsake stamp for one category (FEAT-004 D-3).
class CategoryStamp {
  const CategoryStamp({
    required this.categoryKey,
    required this.tier,
    required this.title,
    required this.visits,
    required this.places,
    required this.firstVisitDate,
    required this.firstVisitPlaceName,
    required this.placeVisits,
  });

  final String categoryKey;
  final int tier;
  final String title;
  final int visits;
  final int places;
  final DateTime firstVisitDate;
  final String firstVisitPlaceName;
  final List<PlaceVisitCount> placeVisits;

  /// Key stored in `milestonesShown` once this tier has been cheered.
  String get milestoneKey => 'stamp:$categoryKey:$tier';
}

class _PlaceAccumulator {
  _PlaceAccumulator(this.placeId, this.placeName, this.firstVisit);

  final String placeId;
  final String placeName;
  DateTime firstVisit;
  final Set<int> days = <int>{};
}

/// Derives earned category stamps from [moments] and [places] only (FEAT-004
/// D-3). Counts only distinct place-and-day visits and distinct places.
///
/// Returned stamps are ordered highest tier first, then most visits (spec F6).
List<CategoryStamp> computeCategoryStamps({
  required Iterable<Moment> moments,
  required Iterable<Place> places,
  required Map<String, List<String>> titles,
}) {
  final placeById = <String, Place>{
    for (final place in places) place.id: place,
  };

  final byCategory = <String, Map<String, _PlaceAccumulator>>{};

  for (final moment in moments) {
    final placeId = moment.placeId;
    if (placeId == null || placeId.isEmpty) continue;
    final place = placeById[placeId];
    final categoryKey = place?.categoryKey ?? moment.placeCategory;
    if (categoryKey == null || !stampCategoryKeys.contains(categoryKey)) {
      continue;
    }

    final local = moment.capturedAt.toLocal();
    final dayKey = local.year * 10000 + local.month * 100 + local.day;
    final categoryMap = byCategory.putIfAbsent(
      categoryKey,
      () => <String, _PlaceAccumulator>{},
    );
    var acc = categoryMap[placeId];
    if (acc == null) {
      final placeName = place?.name ?? moment.placeLabel ?? '';
      acc = _PlaceAccumulator(placeId, placeName, local);
      categoryMap[placeId] = acc;
    } else if (local.isBefore(acc.firstVisit)) {
      acc.firstVisit = local;
    }
    acc.days.add(dayKey);
  }

  final earned = <CategoryStamp>[];
  for (final entry in byCategory.entries) {
    final categoryKey = entry.key;
    final accumulators = entry.value.values;
    final placeCount = accumulators.length;
    var visitCount = 0;
    DateTime? firstDate;
    var firstPlaceName = '';
    for (final acc in accumulators) {
      visitCount += acc.days.length;
      if (firstDate == null || acc.firstVisit.isBefore(firstDate)) {
        firstDate = acc.firstVisit;
        firstPlaceName = acc.placeName;
      }
    }

    var tier = 0;
    for (final threshold in stampTierThresholds) {
      if (visitCount >= threshold.visits && placeCount >= threshold.places) {
        tier = threshold.tier;
        break;
      }
    }
    if (tier == 0 || firstDate == null) continue;

    final categoryTitles = titles[categoryKey];
    final title = (categoryTitles != null && categoryTitles.length >= tier)
        ? categoryTitles[tier - 1]
        : categoryKey;

    final placeVisits =
        [
          for (final acc in accumulators)
            PlaceVisitCount(
              placeId: acc.placeId,
              placeName: acc.placeName,
              visits: acc.days.length,
              firstVisit: acc.firstVisit,
            ),
        ]..sort((a, b) {
          final byVisits = b.visits.compareTo(a.visits);
          if (byVisits != 0) return byVisits;
          final byFirst = a.firstVisit.compareTo(b.firstVisit);
          if (byFirst != 0) return byFirst;
          return a.placeName.compareTo(b.placeName);
        });

    earned.add(
      CategoryStamp(
        categoryKey: categoryKey,
        tier: tier,
        title: title,
        visits: visitCount,
        places: placeCount,
        firstVisitDate: firstDate,
        firstVisitPlaceName: firstPlaceName,
        placeVisits: placeVisits,
      ),
    );
  }

  earned.sort((a, b) {
    final byTier = b.tier.compareTo(a.tier);
    if (byTier != 0) return byTier;
    final byVisits = b.visits.compareTo(a.visits);
    if (byVisits != 0) return byVisits;
    return a.categoryKey.compareTo(b.categoryKey);
  });

  return earned;
}
