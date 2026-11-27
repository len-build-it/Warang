import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/you_sheet.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/milestones.dart';
import 'package:warang/core/models.dart';
import 'package:warang/core/place_categories.dart';
import 'package:warang/core/stamps.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/stamps/stamp_page_sheet.dart';
import 'package:warang/features/stamps/stamp_titles.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, List<String>> titles;

  setUpAll(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    final raw = await rootBundle.loadString('assets/data/stamps.json');
    titles = parseStampTitles(raw);
  });

  Place makePlace(String id, String name, String? categoryKey) => Place(
    id: id,
    name: name,
    categoryKey: categoryKey,
    source: 'user',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Moment makeMoment(
    String id, {
    required String? placeId,
    required DateTime capturedAt,
    String? placeLabel,
    String? placeCategory,
  }) => Moment(
    id: id,
    tripId: 'everyday',
    placeId: placeId,
    placeLabel: placeLabel,
    placeCategory: placeCategory,
    capturedAt: capturedAt,
    createdAt: capturedAt,
    updatedAt: capturedAt,
  );

  BookPlace bookPlace(
    String ref,
    String name,
    String category,
    double lat,
    double lon,
  ) => BookPlace(
    osmRef: ref,
    name: name,
    altNames: '',
    category: category,
    latitude: lat,
    longitude: lon,
    town: 'Kalibo',
    province: 'Aklan',
    weight: 1,
  );

  group('REQ-028 bundled stamp titles', () {
    test(
      'assets/data/stamps.json holds four titles for every stamp category',
      () {
        expect(titles.keys.toSet(), stampCategoryKeys);
        for (final category in PlaceCategories.stampCategories) {
          final list = titles[category.key];
          expect(list, isNotNull, reason: 'missing ${category.key}');
          expect(list!.length, 4, reason: '${category.key} must have 4 titles');
          for (final t in list) {
            expect(t.trim(), isNotEmpty);
          }
        }
        expect(titles['cafe']!.first, 'Kape lover');
      },
    );
  });

  group('REQ-022 & REQ-023 pure stamp calculation', () {
    test(
      'ten moments at one cafe on one day count as one visit; tier 1 needs 3 visits and 2 places',
      () {
        final places = [
          makePlace('c1', 'Kape ni Juan', 'cafe'),
          makePlace('c2', 'Poblacion Brew', 'cafe'),
        ];
        // Ten moments on the same day at c1 = 1 visit.
        final sameDay = [
          for (var i = 0; i < 10; i++)
            makeMoment(
              'm$i',
              placeId: 'c1',
              capturedAt: DateTime(2026, 5, 1, 8, i),
            ),
        ];
        expect(
          computeCategoryStamps(
            moments: sameDay,
            places: places,
            titles: titles,
          ),
          isEmpty,
        );

        // Three visits on three days at ONE place earns nothing.
        final onePlace = [
          makeMoment('a', placeId: 'c1', capturedAt: DateTime(2026, 5, 1, 9)),
          makeMoment('b', placeId: 'c1', capturedAt: DateTime(2026, 5, 2, 9)),
          makeMoment('c', placeId: 'c1', capturedAt: DateTime(2026, 5, 3, 9)),
        ];
        expect(
          computeCategoryStamps(
            moments: onePlace,
            places: places,
            titles: titles,
          ),
          isEmpty,
        );

        // 3 visits across 2 places earns tier 1 ("Kape lover").
        final tier1 = [
          makeMoment('a', placeId: 'c1', capturedAt: DateTime(2026, 5, 1, 9)),
          makeMoment('b', placeId: 'c1', capturedAt: DateTime(2026, 5, 2, 9)),
          makeMoment('c', placeId: 'c2', capturedAt: DateTime(2026, 5, 3, 9)),
        ];
        final stamps = computeCategoryStamps(
          moments: tier1,
          places: places,
          titles: titles,
        );
        expect(stamps, hasLength(1));
        expect(stamps.single.categoryKey, 'cafe');
        expect(stamps.single.tier, 1);
        expect(stamps.single.title, 'Kape lover');
        expect(stamps.single.visits, 3);
        expect(stamps.single.places, 2);
        expect(stamps.single.firstVisitPlaceName, 'Kape ni Juan');
        expect(stamps.single.placeVisits.map((p) => p.placeName).toList(), [
          'Kape ni Juan',
          'Poblacion Brew',
        ]);
      },
    );

    test('transit, town, and uncategorised places earn nothing (REQ-023)', () {
      final places = [
        makePlace('t1', 'Kalibo Airport', 'transit'),
        makePlace('t2', 'Caticlan Port', 'transit'),
        makePlace('tw1', 'Kalibo', 'town'),
        makePlace('tw2', 'Malay', 'town'),
        makePlace('u1', 'Home', null),
        makePlace('u2', 'Office', null),
      ];
      final moments = [
        for (final pair in [('t1', 't2'), ('tw1', 'tw2'), ('u1', 'u2')]) ...[
          makeMoment(
            '${pair.$1}-1',
            placeId: pair.$1,
            capturedAt: DateTime(2026, 6, 1, 10),
          ),
          makeMoment(
            '${pair.$1}-2',
            placeId: pair.$1,
            capturedAt: DateTime(2026, 6, 2, 10),
          ),
          makeMoment(
            '${pair.$2}-1',
            placeId: pair.$2,
            capturedAt: DateTime(2026, 6, 3, 10),
          ),
        ],
      ];
      expect(
        computeCategoryStamps(moments: moments, places: places, titles: titles),
        isEmpty,
      );
    });

    test('10,000-moment fixture computes in under 16 ms (Council C-3)', () {
      final places = [
        for (var i = 0; i < 60; i++)
          makePlace(
            'p$i',
            'Place $i',
            PlaceCategories.stampCategories[i % 12].key,
          ),
      ];
      final base = DateTime(2024, 1, 1, 9);
      final moments = [
        for (var i = 0; i < 10000; i++)
          makeMoment(
            'm$i',
            placeId: 'p${i % 60}',
            capturedAt: base.add(Duration(hours: i * 3)),
          ),
      ];
      // Warm up JIT.
      computeCategoryStamps(moments: moments, places: places, titles: titles);
      final watch = Stopwatch()..start();
      final result = computeCategoryStamps(
        moments: moments,
        places: places,
        titles: titles,
      );
      watch.stop();
      expect(result, hasLength(12));
      expect(watch.elapsedMilliseconds, lessThan(16));
    });
  });

  group('REQ-024, REQ-025, REQ-026, REQ-027 repository & UI flows', () {
    late Directory tempDir;
    late WarangDatabase db;
    late WarangRepository repo;
    late MapTileStore tileStore;

    setUp(() async {
      StampTitles.reset();
      WarangStamp.resetSession();
      tempDir = Directory.systemTemp.createTempSync('warang_stamps_');
      db = WarangDatabase.memory();
      repo = WarangRepository(
        db,
        photoStore: PhotoStore(documentsDirectory: tempDir),
      );
      await repo.initialize();
      await repo.setName('Len');
      tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
    });

    tearDown(() async {
      await tileStore.close();
      repo.dispose();
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<void> seedCafeTier1AndBeachTier1() async {
      final c1 = bookPlace('n1', 'Kape ni Juan', 'cafe', 11.7086, 122.3643);
      final c2 = bookPlace('n2', 'Poblacion Brew', 'cafe', 11.7091, 122.3650);
      final b1 = bookPlace('n3', 'White Beach', 'beach', 11.9618, 121.9242);
      final b2 = bookPlace('n4', 'Puka Beach', 'beach', 11.9950, 121.9120);
      await repo.addMoment(
        caption: 'Cafe 1 day 1',
        latitude: c1.latitude,
        longitude: c1.longitude,
        place: c1,
        capturedAt: DateTime(2026, 7, 1, 9),
      );
      await repo.addMoment(
        caption: 'Cafe 1 day 2',
        latitude: c1.latitude,
        longitude: c1.longitude,
        place: c1,
        capturedAt: DateTime(2026, 7, 2, 9),
      );
      await repo.addMoment(
        caption: 'Cafe 2 day 3',
        latitude: c2.latitude,
        longitude: c2.longitude,
        place: c2,
        capturedAt: DateTime(2026, 7, 3, 9),
      );
      await repo.addMoment(
        caption: 'Cafe 2 day 4',
        latitude: c2.latitude,
        longitude: c2.longitude,
        place: c2,
        capturedAt: DateTime(2026, 7, 4, 9),
      );
      await repo.addMoment(
        caption: 'Beach 1 day 1',
        latitude: b1.latitude,
        longitude: b1.longitude,
        place: b1,
        capturedAt: DateTime(2026, 7, 5, 16),
      );
      await repo.addMoment(
        caption: 'Beach 1 day 2',
        latitude: b1.latitude,
        longitude: b1.longitude,
        place: b1,
        capturedAt: DateTime(2026, 7, 6, 16),
      );
      await repo.addMoment(
        caption: 'Beach 2 day 3',
        latitude: b2.latitude,
        longitude: b2.longitude,
        place: b2,
        capturedAt: DateTime(2026, 7, 7, 16),
      );
    }

    test(
      'REQ-025: tier 1 cheers once, second save does not, and Somewhere new orders before stamp',
      () async {
        final c1 = bookPlace('n1', 'Kape ni Juan', 'cafe', 11.7086, 122.3643);
        final c2 = bookPlace('n2', 'Manila Coffee', 'cafe', 14.5995, 120.9842);

        final m1 = await repo.addMoment(
          caption: 'First',
          latitude: c1.latitude,
          longitude: c1.longitude,
          place: c1,
          capturedAt: DateTime(2026, 8, 1, 9),
        );
        expect(
          (await repo.claimMilestone(
            m1,
            stampTitles: titles,
          )).map((m) => m.key).toList(),
          ['first-moment'],
        );

        final m2 = await repo.addMoment(
          caption: 'Second',
          latitude: c1.latitude,
          longitude: c1.longitude,
          place: c1,
          capturedAt: DateTime(2026, 8, 2, 9),
        );
        expect(await repo.claimMilestone(m2, stampTitles: titles), isEmpty);

        // Third visit at a second cafe > 25 km away triggers BOTH Somewhere new!
        // and Kape lover! in that order.
        final m3 = await repo.addMoment(
          caption: 'Third far away',
          latitude: c2.latitude,
          longitude: c2.longitude,
          place: c2,
          capturedAt: DateTime(2026, 8, 3, 9),
        );
        final claimed = await repo.claimMilestone(m3, stampTitles: titles);
        expect(claimed.map((m) => m.kind).toList(), [
          MilestoneKind.somewhereNew,
          MilestoneKind.categoryStamp,
        ]);
        expect(claimed[0].message, 'Somewhere new!');
        expect(claimed[1].key, 'stamp:cafe:1');
        expect(claimed[1].message, 'Kape lover!');

        // A second qualifying save does NOT cheer tier 1 again.
        final m4 = await repo.addMoment(
          caption: 'Fourth',
          latitude: c2.latitude,
          longitude: c2.longitude,
          place: c2,
          capturedAt: DateTime(2026, 8, 4, 9),
        );
        expect(await repo.claimMilestone(m4, stampTitles: titles), isEmpty);
      },
    );

    testWidgets(
      'REQ-026, REQ-027, REQ-024: You sheet hides unearned row, shows earned stamps, opens stamp page, and drops stamp after delete',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        Future<void> settle() async {
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 80));
          }
        }

        // With 0 stamps, You sheet hides "Your stamps".
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: repo,
                builder: (context, _) => YouSheet(
                  repository: repo,
                  onSettings: () {},
                  onAbout: () {},
                ),
              ),
            ),
          ),
        );
        await settle();
        expect(find.text('Your stamps'), findsNothing);
        expect(find.text('Kape lover'), findsNothing);

        // Seed cafe (4 visits, 2 places) and beach (3 visits, 2 places).
        await tester.runAsync(seedCafeTier1AndBeachTier1);
        await settle();

        expect(find.text('Your stamps'), findsOneWidget);
        expect(find.text('Kape lover'), findsOneWidget);
        expect(find.text('Sun seeker'), findsOneWidget);
        // Unearned categories are absent.
        expect(find.text('Hungry wanderer'), findsNothing);

        // Forbidden text check (REQ-026) on You sheet.
        final forbidden = RegExp(
          r'(more to|next|left|until|/)',
          caseSensitive: false,
        );
        for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
          final data = textWidget.data ?? '';
          expect(
            forbidden.hasMatch(data),
            isFalse,
            reason: 'Forbidden text in YouSheet: "$data"',
          );
        }

        // Tap Kape lover -> opens StampPageSheet.
        String? selectedCategory;
        String? selectedPlaceId;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: repo,
                builder: (context, _) => YouSheet(
                  repository: repo,
                  onSettings: () {},
                  onAbout: () {},
                  onSelectStampPlace: (cat, placeId) {
                    selectedCategory = cat;
                    selectedPlaceId = placeId;
                  },
                ),
              ),
            ),
          ),
        );
        await settle();

        await tester.tap(find.bySemanticsLabel('Kape lover, Cafe'));
        await settle();

        expect(find.byType(StampPageSheet), findsOneWidget);
        expect(find.text('4 visits to 2 places'), findsOneWidget);
        expect(find.text('Since 1 Jul 2026, Kape ni Juan'), findsOneWidget);
        expect(find.text('Kape ni Juan'), findsOneWidget);
        expect(find.text('Poblacion Brew'), findsOneWidget);

        // Forbidden text check (REQ-026) on StampPageSheet.
        for (final textWidget in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(StampPageSheet),
            matching: find.byType(Text),
          ),
        )) {
          final data = textWidget.data ?? '';
          expect(
            forbidden.hasMatch(data),
            isFalse,
            reason: 'Forbidden text in StampPageSheet: "$data"',
          );
        }

        // Tapping a place closes the sheet and reports category + placeId.
        await tester.tap(find.text('Kape ni Juan'));
        await settle();
        expect(selectedCategory, 'cafe');
        expect(selectedPlaceId, isNotNull);

        // REQ-024: deleting moments below threshold removes the cafe stamp.
        final cafeMoments = repo.moments
            .where((m) => m.placeCategory == 'cafe')
            .toList();
        await tester.runAsync(() async {
          await repo.softDeleteMoment(cafeMoments[0].id);
          await repo.softDeleteMoment(cafeMoments[1].id);
        });
        await settle();
        expect(find.text('Kape lover'), findsNothing);
        expect(find.text('Sun seeker'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a place on the stamp page sets the map category filter in AppShell',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.runAsync(seedCafeTier1AndBeachTier1);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              mapTileStoreProvider.overrideWithValue(tileStore),
            ],
            child: MaterialApp(
              theme: buildWarangTheme(Brightness.light),
              home: const AppShell(),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Open You sheet -> tap Kape lover -> tap Kape ni Juan.
        await tester.tap(find.bySemanticsLabel('You, profile and settings'));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.bySemanticsLabel('Kape lover, Cafe'));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('Kape ni Juan'));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TravelModeScreen)),
        );
        expect(container.read(mapCategoryFilterProvider), 'cafe');
        expect(container.read(shellTabProvider), ShellTab.map);
      },
    );
  });
}
