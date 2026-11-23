import 'package:flutter/widgets.dart';

import '../app/theme/palette.dart';
import '../app/theme/tokens.dart';
import '../app/theme/warang_icons.dart';

/// One of the fourteen FEAT-004 D-4 place categories.
@immutable
class PlaceCategory {
  const PlaceCategory({
    required this.key,
    required this.name,
    required this.glyph,
    required this.toneKey,
    required this.countsForStamps,
  });

  final String key;
  final String name;
  final WarangGlyph glyph;

  /// One of `WarangKeepsake`'s keys, or null for neutral (`transit`, `town`).
  final String? toneKey;
  final bool countsForStamps;

  KeepsakeTone? get tone => WarangKeepsake.byKey(toneKey);

  Color discBackground(Brightness brightness) {
    final t = tone;
    if (t != null) return t.tint(brightness);
    return brightness == Brightness.dark
        ? WarangColors.darkSurfaceRaised
        : WarangColors.lightGround;
  }

  Color discForeground(Brightness brightness) {
    final t = tone;
    if (t != null) return t.text(brightness);
    return brightness == Brightness.dark
        ? WarangColors.darkInk
        : WarangColors.lightInk;
  }
}

/// The fourteen FEAT-004 place categories, in D-4 table order.
abstract final class PlaceCategories {
  static const cafe = PlaceCategory(
    key: 'cafe',
    name: 'Cafe',
    glyph: WarangGlyphs.catCafe,
    toneKey: 'santan',
    countsForStamps: true,
  );
  static const food = PlaceCategory(
    key: 'food',
    name: 'Food',
    glyph: WarangGlyphs.catFood,
    toneKey: 'gumamela',
    countsForStamps: true,
  );
  static const sweets = PlaceCategory(
    key: 'sweets',
    name: 'Sweets and bakery',
    glyph: WarangGlyphs.catSweets,
    toneKey: 'santan',
    countsForStamps: true,
  );
  static const nightlife = PlaceCategory(
    key: 'nightlife',
    name: 'Nightlife',
    glyph: WarangGlyphs.catNightlife,
    toneKey: 'ube',
    countsForStamps: true,
  );
  static const beach = PlaceCategory(
    key: 'beach',
    name: 'Beach',
    glyph: WarangGlyphs.catBeach,
    toneKey: 'dagat',
    countsForStamps: true,
  );
  static const island = PlaceCategory(
    key: 'island',
    name: 'Island',
    glyph: WarangGlyphs.catIsland,
    toneKey: 'dagat',
    countsForStamps: true,
  );
  static const nature = PlaceCategory(
    key: 'nature',
    name: 'Mountains and falls',
    glyph: WarangGlyphs.catNature,
    toneKey: 'kalamansi',
    countsForStamps: true,
  );
  static const park = PlaceCategory(
    key: 'park',
    name: 'Parks and views',
    glyph: WarangGlyphs.catPark,
    toneKey: 'kalamansi',
    countsForStamps: true,
  );
  static const church = PlaceCategory(
    key: 'church',
    name: 'Churches',
    glyph: WarangGlyphs.catChurch,
    toneKey: 'amber',
    countsForStamps: true,
  );
  static const heritage = PlaceCategory(
    key: 'heritage',
    name: 'Heritage and museums',
    glyph: WarangGlyphs.catHeritage,
    toneKey: 'amber',
    countsForStamps: true,
  );
  static const market = PlaceCategory(
    key: 'market',
    name: 'Markets and malls',
    glyph: WarangGlyphs.catMarket,
    toneKey: 'langit',
    countsForStamps: true,
  );
  static const stay = PlaceCategory(
    key: 'stay',
    name: 'Stays',
    glyph: WarangGlyphs.catStay,
    toneKey: 'langit',
    countsForStamps: true,
  );
  static const transit = PlaceCategory(
    key: 'transit',
    name: 'On the way',
    glyph: WarangGlyphs.catTransit,
    toneKey: null,
    countsForStamps: false,
  );
  static const town = PlaceCategory(
    key: 'town',
    name: 'Towns and cities',
    glyph: WarangGlyphs.catTown,
    toneKey: null,
    countsForStamps: false,
  );

  static const all = <PlaceCategory>[
    cafe,
    food,
    sweets,
    nightlife,
    beach,
    island,
    nature,
    park,
    church,
    heritage,
    market,
    stay,
    transit,
    town,
  ];

  static final List<PlaceCategory> stampCategories = List.unmodifiable(
    all.where((category) => category.countsForStamps),
  );

  static PlaceCategory? byKey(String? key) {
    if (key == null) return null;
    for (final category in all) {
      if (category.key == key) return category;
    }
    return null;
  }
}
