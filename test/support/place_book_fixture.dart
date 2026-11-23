import 'dart:convert';
import 'dart:io';

import 'package:warang/data/places/place_book.dart';

/// Loads the shared test place book in memory using the real `schema.sql`.
Future<PlaceBook> openFixturePlaceBook() async {
  final schemaSql = File('tool/place_book/schema.sql').readAsStringSync();
  final raw = File('test/fixtures/place_book_fixture.json').readAsStringSync();
  final decoded = (jsonDecode(raw) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final places = decoded.map(
    (item) => BookPlace(
      osmRef: item['osmRef'] as String,
      name: item['name'] as String,
      altNames: (item['altNames'] as String?) ?? '',
      category: item['category'] as String,
      latitude: (item['lat'] as num).toDouble(),
      longitude: (item['lon'] as num).toDouble(),
      town: (item['town'] as String?) ?? '',
      province: (item['province'] as String?) ?? '',
      weight: (item['weight'] as num?)?.toInt() ?? 0,
    ),
  );
  return PlaceBook.memory(schemaSql: schemaSql, places: places);
}
