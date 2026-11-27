import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/fts_query.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/places/place_book_installer.dart';
import 'package:warang/data/repository.dart';

import 'support/place_book_fixture.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, Uint8List> assets;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    final bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(bytes);
  }
}

Future<Uint8List> _miniPlaceBookBytes(
  Directory tempDir, {
  String schemaVersion = '1',
}) async {
  sqfliteFfiInit();
  final filePath = p.join(
    tempDir.path,
    'seed_${schemaVersion}_${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  final db = await databaseFactoryFfi.openDatabase(
    filePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.insert('meta', {
          'key': 'schema_version',
          'value': schemaVersion,
        });
      },
      version: 1,
    ),
  );
  await db.close();
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  await file.delete();
  return bytes;
}

void main() {
  group('buildFtsQuery', () {
    test('quotes tokens, adds prefix wildcard, and strips FTS syntax', () {
      expect(buildFtsQuery(''), isNull);
      expect(buildFtsQuery('   " - * ( )  '), isNull);
      expect(buildFtsQuery('kap'), '"kap"*');
      expect(buildFtsQuery('kape ni juan'), '"kape" "ni" "juan"*');
      expect(
        buildFtsQuery('NEAR "foo" -bar* (baz)'),
        '"NEAR" "foo" "bar" "baz"*',
      );
    });
  });

  group('SearchDao FTS5 safety', () {
    test('syntax characters and NEAR never throw in moment search', () async {
      final db = WarangDatabase.memory();
      final tempDir = await Directory.systemTemp.createTemp('warang_fts_test_');
      addTearDown(() async {
        await db.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final repo = WarangRepository(
        db,
        photoStore: PhotoStore(documentsDirectory: tempDir),
      );
      await repo.initialize();
      await repo.addMoment(
        caption: 'Near the old pier',
        placeLabel: 'Kalibo Port',
      );

      for (final raw in ['"', '-', '*', '(', 'NEAR', 'near "pier"', '---']) {
        final hits = await db.searchDao.search(raw);
        expect(hits, isA<List<dynamic>>());
      }
      final matched = await db.searchDao.search('NEAR');
      expect(matched, hasLength(1));
    });
  });

  group('PlaceBook fixture queries', () {
    late PlaceBook book;

    setUp(() async {
      book = await openFixturePlaceBook();
    });

    tearDown(() async {
      await book.close();
    });

    test('supports prefix match, diacritic folding, and punctuation', () async {
      final prefix = await book.search('kap');
      expect(prefix.map((e) => e.name), contains('Kape ni Juan'));

      final accented = await book.search('pina');
      expect(accented.map((e) => e.name), contains('Piña Café'));

      final punct = await book.search("Ariel's Point -");
      expect(punct.map((e) => e.name), contains("Ariel's Point - Cliff"));

      for (final raw in ['"', '-', '*', '(', 'NEAR', 'a']) {
        final res = await book.search(raw);
        expect(res, isA<List<BookPlace>>());
      }
      expect(await book.search('k'), isEmpty);
    });

    test('ranks equally matching places nearer to map centre first', () async {
      final nearKalibo = await book.search(
        'Jollibee',
        near: const LatLng(11.707, 122.365),
      );
      expect(nearKalibo, hasLength(2));
      expect(nearKalibo.first.town, 'Kalibo');
      expect(nearKalibo.last.town, 'Numancia');

      final nearNumancia = await book.search(
        'Jollibee',
        near: const LatLng(11.751, 122.365),
      );
      expect(nearNumancia, hasLength(2));
      expect(nearNumancia.first.town, 'Numancia');
      expect(nearNumancia.last.town, 'Kalibo');
    });

    test('nearby filters by radius and orders nearest first', () async {
      const origin = LatLng(11.7086, 122.3643); // Kape ni Juan
      final nearby = await book.nearby(origin, 200);
      final names = nearby.map((e) => e.name).toList();
      expect(names.first, 'Kape ni Juan');
      expect(names, containsAll(['Poblacion Brew', 'Piña Café']));
      expect(names, isNot(contains('Station Two Espresso')));
      expect(names, isNot(contains('White Beach')));
    });
  });

  group('Bundled place book asset', () {
    test(
      'has schema version 1, all 14 categories, and fast 3-letter search',
      () async {
        final assetFile = File('assets/place_book/place_book.sqlite');
        expect(assetFile.existsSync(), isTrue);
        final tempDir = await Directory.systemTemp.createTemp(
          'warang_pb_asset_',
        );
        final copied = await assetFile.copy(
          p.join(tempDir.path, 'place_book.sqlite'),
        );
        final book = PlaceBook.openFile(copied);
        addTearDown(() async {
          await book.close();
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final meta = await book.readMeta();
        expect(meta['schema_version'], '1');
        expect(meta['source_date'], isNotEmpty);
        expect(meta['licence'], contains('ODbL'));

        final counts = await book.categoryCounts();
        const expectedCategories = [
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
          'transit',
          'town',
        ];
        for (final category in expectedCategories) {
          expect(
            counts[category] ?? 0,
            greaterThan(0),
            reason: 'Expected at least one row for $category',
          );
        }

        // Warm up once, then average 20 three-letter queries.
        await book.search('kap', near: const LatLng(11.706, 122.364));
        final sw = Stopwatch()..start();
        List<BookPlace> last = const [];
        for (var i = 0; i < 20; i++) {
          last = await book.search('kap', near: const LatLng(11.706, 122.364));
        }
        sw.stop();
        final avgMs = sw.elapsedMicroseconds / 20000.0;
        expect(last, isNotEmpty);
        expect(avgMs, lessThan(150.0));
      },
    );
  });

  group('PlaceBookInstaller and provider', () {
    test(
      'skips copy when ready, redoes interrupted copy, and removes old files',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'warang_pb_inst_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final payload = await _miniPlaceBookBytes(tempDir, schemaVersion: '1');
        final bundle = _FakeAssetBundle({'test/book.sqlite': payload});
        final spec = PlaceBookAssetSpec(
          assetKey: 'test/book.sqlite',
          schemaVersion: '1',
          sourceDate: '2026-11-22',
          expectedBytes: payload.length,
        );
        final installer = PlaceBookInstaller(
          spec: spec,
          bundle: bundle,
          supportDirectory: () async => tempDir,
        );

        // Simulate an older version and a leftover interrupted .tmp file.
        final oldFile = File(
          p.join(tempDir.path, 'place_book_1_2026-01-01.sqlite'),
        );
        await oldFile.writeAsBytes([1, 2, 3]);
        final leftoverTmp = File(p.join(tempDir.path, '${spec.fileName}.tmp'));
        await leftoverTmp.writeAsBytes([9, 9]);

        final installed = await installer.ensureInstalled();
        expect(await installed.exists(), isTrue);
        expect(await installed.length(), payload.length);
        expect(await oldFile.exists(), isFalse);
        expect(await leftoverTmp.exists(), isFalse);
        expect(bundle.loadCount, 1);

        // Second call skips copy when the file is already complete.
        final second = await installer.ensureInstalled();
        expect(second.path, installed.path);
        expect(bundle.loadCount, 1);

        // Truncating the file causes the installer to redo the copy.
        await installed.writeAsBytes([0, 1]);
        await installer.ensureInstalled();
        expect(await installed.length(), payload.length);
        expect(bundle.loadCount, 2);
      },
    );

    test(
      'reinstalls when existing file has wrong schema_version',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'warang_pb_schema_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final validPayload = await _miniPlaceBookBytes(
          tempDir,
          schemaVersion: '1',
        );
        final wrongSchemaPayload = await _miniPlaceBookBytes(
          tempDir,
          schemaVersion: '999',
        );
        final bundle = _FakeAssetBundle({'test/book.sqlite': validPayload});
        const spec = PlaceBookAssetSpec(
          assetKey: 'test/book.sqlite',
          schemaVersion: '1',
          sourceDate: '2026-11-22',
        );
        final target = File(p.join(tempDir.path, spec.fileName));
        await target.writeAsBytes(wrongSchemaPayload, flush: true);

        final installer = PlaceBookInstaller(
          spec: spec,
          bundle: bundle,
          supportDirectory: () async => tempDir,
        );
        final installed = await installer.ensureInstalled();
        expect(bundle.loadCount, 1);
        final book = PlaceBook.openFile(installed);
        addTearDown(book.close);
        final meta = await book.readMeta();
        expect(meta['schema_version'], '1');
      },
    );

    test('reports failed state when asset is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp('warang_pb_fail_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundle = _FakeAssetBundle(const {});
      final installer = PlaceBookInstaller(
        spec: const PlaceBookAssetSpec(
          assetKey: 'missing/book.sqlite',
          schemaVersion: '1',
          sourceDate: '2026-11-22',
          expectedBytes: 10,
        ),
        bundle: bundle,
        supportDirectory: () async => tempDir,
      );
      final container = ProviderContainer(
        overrides: [placeBookInstallerProvider.overrideWithValue(installer)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(placeBookProvider).status,
        PlaceBookStatus.preparing,
      );
      await container.read(placeBookProvider.notifier).ensureReady();
      expect(container.read(placeBookProvider).status, PlaceBookStatus.failed);
      expect(container.read(placeBookProvider).error, isNotNull);
    });
  });
}
