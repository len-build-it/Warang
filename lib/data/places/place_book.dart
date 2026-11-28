import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:latlong2/latlong.dart';

import 'fts_query.dart';

/// A single named place from the bundled offline Philippine place book.
class BookPlace {
  const BookPlace({
    required this.osmRef,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.altNames = '',
    this.town = '',
    this.province = '',
    this.weight = 0,
  });

  final String osmRef;
  final String name;
  final String altNames;
  final String category;
  final double latitude;
  final double longitude;
  final String town;
  final String province;
  final int weight;

  LatLng get latLng => LatLng(latitude, longitude);

  String get locationSubtitle {
    if (town.isNotEmpty && province.isNotEmpty && town != province) {
      return '$town, $province';
    }
    if (town.isNotEmpty) return town;
    return province;
  }

  @override
  bool operator ==(Object other) =>
      other is BookPlace &&
      other.osmRef == osmRef &&
      other.name == name &&
      other.category == category &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.town == town &&
      other.province == province;

  @override
  int get hashCode =>
      Object.hash(osmRef, name, category, latitude, longitude, town, province);
}

class _PlaceBookDb extends GeneratedDatabase {
  _PlaceBookDb(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (_) async {}, onUpgrade: (_, _, _) async {});

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}

/// Read-only handle to the offline Philippine place book SQLite file.
class PlaceBook {
  PlaceBook._(this._db, {bool lockReadOnly = true})
    : _queryOnlyApplied = !lockReadOnly;

  /// Opens a copied place book file on disk in read-only mode.
  factory PlaceBook.openFile(File file) {
    final executor = NativeDatabase.createInBackground(file);
    return PlaceBook._(_PlaceBookDb(executor));
  }

  /// Creates an in-memory place book from [schemaSql] and [places] for tests.
  static Future<PlaceBook> memory({
    required String schemaSql,
    required Iterable<BookPlace> places,
    Map<String, String> meta = const {
      'schema_version': '1',
      'source': 'Test fixture',
      'source_date': '2026-11-22',
      'built_at': '2026-11-22T00:00:00Z',
      'licence': 'ODbL 1.0 - OpenStreetMap contributors',
    },
  }) async {
    final db = _PlaceBookDb(NativeDatabase.memory());
    for (final statement in _splitSqlStatements(schemaSql)) {
      await db.customStatement(statement);
    }
    for (final entry in meta.entries) {
      await db.customInsert(
        'INSERT INTO meta (key, value) VALUES (?, ?)',
        variables: [
          Variable.withString(entry.key),
          Variable.withString(entry.value),
        ],
      );
    }
    for (final place in places) {
      await db.customInsert(
        '''INSERT INTO places (
             osm_ref, name, alt_names, category, lat, lon, town, province, weight
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable.withString(place.osmRef),
          Variable.withString(place.name),
          Variable.withString(place.altNames),
          Variable.withString(place.category),
          Variable.withReal(place.latitude),
          Variable.withReal(place.longitude),
          Variable.withString(place.town),
          Variable.withString(place.province),
          Variable.withInt(place.weight),
        ],
      );
    }
    await db.customStatement(
      "INSERT INTO places_fts(places_fts) VALUES('rebuild')",
    );
    return PlaceBook._(db);
  }

  final _PlaceBookDb _db;
  bool _queryOnlyApplied;
  static const _distance = Distance();

  Future<void> _ensureQueryOnly() async {
    if (_queryOnlyApplied) return;
    await _db.customStatement('PRAGMA query_only = ON');
    _queryOnlyApplied = true;
  }

  Future<Map<String, String>> readMeta() async {
    await _ensureQueryOnly();
    final rows = await _db.customSelect('SELECT key, value FROM meta').get();
    return {
      for (final row in rows)
        row.read<String>('key'): row.read<String>('value'),
    };
  }

  Future<Map<String, int>> categoryCounts() async {
    await _ensureQueryOnly();
    final rows = await _db
        .customSelect(
          'SELECT category, COUNT(*) AS cnt FROM places GROUP BY category',
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('category'): row.read<int>('cnt'),
    };
  }

  /// Searches places offline using FTS5, ranked by text match then nearness.
  Future<List<BookPlace>> search(
    String text, {
    LatLng? near,
    int limit = 30,
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < 2) return const [];
    final ftsQuery = buildFtsQuery(trimmed);
    if (ftsQuery == null) return const [];
    await _ensureQueryOnly();

    final rows = await _queryFtsPlaces(ftsQuery, near: near, limit: limit);
    return rows.map(_placeFromRow).toList();
  }

  Future<List<QueryRow>> _queryFtsPlaces(
    String ftsQuery, {
    LatLng? near,
    required int limit,
  }) {
    final distanceOrder = near == null
        ? ''
        : '((p.lat - ?) * (p.lat - ?) + (p.lon - ?) * (p.lon - ?)) ASC,\n'
              '                        ';
    final variables = <Variable>[
      Variable.withString(ftsQuery),
      if (near != null) ...[
        Variable.withReal(near.latitude),
        Variable.withReal(near.latitude),
        Variable.withReal(near.longitude),
        Variable.withReal(near.longitude),
      ],
      Variable.withInt(limit),
    ];
    return _db
        .customSelect('''SELECT p.osm_ref, p.name, p.alt_names, p.category,
                      p.lat, p.lon, p.town, p.province, p.weight
               FROM places_fts
               JOIN places p ON p.id = places_fts.rowid
               WHERE places_fts MATCH ?
               ORDER BY ROUND(bm25(places_fts, 10.0, 5.0, 2.0, 1.0), 1) ASC,
                        ${distanceOrder}p.weight DESC,
                        p.name ASC
               LIMIT ?''', variables: variables)
        .get();
  }

  /// Returns places within [radiusMetres] of [point], sorted nearest first.
  Future<List<BookPlace>> nearby(
    LatLng point,
    double radiusMetres, {
    int limit = 8,
  }) async {
    if (radiusMetres <= 0 || limit <= 0) return const [];
    await _ensureQueryOnly();
    final latDelta = (radiusMetres / 111320.0) * 1.05;
    final cosLat = math
        .cos(point.latitude * math.pi / 180.0)
        .abs()
        .clamp(0.1, 1.0);
    final lonDelta = latDelta / cosLat;

    final rows = await _db
        .customSelect(
          '''SELECT osm_ref, name, alt_names, category,
                    lat, lon, town, province, weight
             FROM places
             WHERE lat BETWEEN ? AND ?
               AND lon BETWEEN ? AND ?''',
          variables: [
            Variable.withReal(point.latitude - latDelta),
            Variable.withReal(point.latitude + latDelta),
            Variable.withReal(point.longitude - lonDelta),
            Variable.withReal(point.longitude + lonDelta),
          ],
        )
        .get();

    final withDistance = <(BookPlace, double)>[];
    for (final row in rows) {
      final place = _placeFromRow(row);
      final metres = _distance.as(LengthUnit.Meter, point, place.latLng);
      if (metres <= radiusMetres) {
        withDistance.add((place, metres));
      }
    }
    withDistance.sort((a, b) => a.$2.compareTo(b.$2));
    return withDistance.take(limit).map((e) => e.$1).toList();
  }

  Future<void> close() => _db.close();

  static BookPlace _placeFromRow(QueryRow row) => BookPlace(
    osmRef: row.read<String>('osm_ref'),
    name: row.read<String>('name'),
    altNames: row.read<String>('alt_names'),
    category: row.read<String>('category'),
    latitude: row.read<double>('lat'),
    longitude: row.read<double>('lon'),
    town: row.read<String>('town'),
    province: row.read<String>('province'),
    weight: row.read<int>('weight'),
  );
}

List<String> _splitSqlStatements(String sql) {
  final statements = <String>[];
  final buffer = StringBuffer();
  for (final line in sql.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
    buffer.writeln(line);
    if (trimmed.endsWith(';')) {
      statements.add(buffer.toString().trim());
      buffer.clear();
    }
  }
  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) statements.add(rest);
  return statements;
}
