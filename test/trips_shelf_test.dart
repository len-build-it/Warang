// FEAT-003 Phase 7: trip colours on the shelf, the trip detail band, the
// trip form, and the map's pins (REQ-013, REQ-014, REQ-016, S6 to S8).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/trip_rules.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
import 'package:warang/features/home_tab/trip_form_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    WarangStamp.resetSession();
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Brightness brightness = Brightness.light,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: buildWarangTheme(brightness),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduced,
            ),
            child: home,
          ),
        ),
      ),
    );
  }

  test('the analytics charts are gone (D-4)', () {
    expect(
      File('lib/features/home_tab/analytics_charts.dart').existsSync(),
      isFalse,
    );
  });

  test('palette trip tones follow the stored colour order', () {
    expect([
      for (final tone in WarangKeepsake.tripTones) tone.key,
    ], tripColorKeys);
  });

  for (final brightness in Brightness.values) {
    testWidgets('each trip card wears its own tint (${brightness.name})', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await repository.addTrip('Antique', null, null, null);
        await repository.addTrip('Guimaras', null, null, null);
      });
      await pump(tester, const HomeTabScreen(), brightness: brightness);
      await settle(tester);
      for (final title in ['Antique', 'Guimaras']) {
        final trip = repository.trips.firstWhere((t) => t.title == title);
        final card = tester.widget<ClaySurface>(
          find
              .descendant(
                of: find.widgetWithText(TripShelfCard, title),
                matching: find.byType(ClaySurface),
              )
              .first,
        );
        expect(
          card.color,
          WarangKeepsake.forTrip(trip)!.tint(brightness),
          reason: title,
        );
      }
      // Cards lean alternately by position, within V4's 2 degrees.
      final leans = tester
          .widgetList<TripShelfCard>(find.byType(TripShelfCard))
          .map((card) => card.tiltDegrees)
          .toList();
      expect(leans, [-1.5, 1.5]);
    });
  }

  testWidgets('a long name leaves Bagel for Atkinson over more lines', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.addTrip('Boracay', null, null, null);
      await repository.addTrip(
        'Boracay long weekend with friends',
        null,
        null,
        null,
      );
    });
    await pump(tester, const HomeTabScreen());
    await settle(tester);
    expect(
      tester.widget<Text>(find.text('Boracay')).style?.fontFamily,
      WarangType.displayFamily,
    );
    final long = tester.widget<Text>(
      find.text('Boracay long weekend with friends'),
    );
    expect(long.style?.fontFamily, WarangType.textFamily);
    expect(long.maxLines, 3);
  });

  testWidgets('the stamps count up the first time only', (tester) async {
    await tester.runAsync(() async {
      for (var index = 0; index < 5; index++) {
        await repository.addMoment(caption: 'Moment $index');
      }
    });
    await pump(tester, const HomeTabScreen());
    await tester.pump(const Duration(milliseconds: 100));
    final midway = find.descendant(
      of: find.bySemanticsLabel('5 moments'),
      matching: find.text('5'),
    );
    expect(midway, findsNothing, reason: 'still counting');
    await settle(tester);
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('under reduced motion the stamps show their totals at once', (
    tester,
  ) async {
    await tester.runAsync(() => repository.addMoment(caption: 'One'));
    await pump(tester, const HomeTabScreen(), reduced: true);
    await tester.pump();
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('no trips yet: a kind line, no number games', (tester) async {
    await pump(tester, const HomeTabScreen());
    await settle(tester);
    expect(find.text("Plan a trip and I'll pack my bag"), findsOneWidget);
    expect(find.textContaining('streak'), findsNothing);
  });

  testWidgets('a new trip springs onto the shelf', (tester) async {
    await pump(tester, const HomeTabScreen());
    await settle(tester);
    await tester.runAsync(
      () => repository.addTrip('Siquijor', null, null, null),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final scale = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(TripShelfCard),
            matching: find.byType(Transform),
          ),
        )
        // The length of the x axis: the scale, whatever the rotation.
        .map((transform) => transform.transform.getColumn(0).xy.length)
        .reduce((a, b) => a < b ? a : b);
    expect(scale, lessThan(.95));
    await settle(tester);
  });

  testWidgets('trip detail: a band in the trip colour and an options sheet', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.addTrip('Bohol', 'Panglao', null, null);
    });
    final trip = repository.trips.firstWhere((t) => t.title == 'Bohol');
    await tester.runAsync(() async {
      await repository.addMoment(caption: 'Chocolate hills');
      final moment = repository.moments.single;
      await repository.updateMoment(
        moment.id,
        caption: 'Chocolate hills',
        placeLabel: '',
        tripId: trip.id,
      );
    });
    await pump(tester, TripDetailScreen(tripId: trip.id));
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color ==
                WarangKeepsake.forTrip(trip)!.tint(Brightness.light),
      ),
      findsOneWidget,
    );
    // Moments sit in a grid of polaroids under the cover.
    expect(find.byType(WarangPolaroid), findsNWidgets(2));
    expect(find.text('Chocolate hills'), findsOneWidget);

    await tester.tap(find.byTooltip('Trip options'));
    await settle(tester);
    expect(find.byType(WarangSheetFrame), findsOneWidget);
    expect(find.widgetWithText(WarangButton, 'Edit trip'), findsOneWidget);
    expect(find.widgetWithText(WarangButton, 'Delete trip'), findsOneWidget);
  });

  testWidgets('the form preselects the next colour and keeps a chosen one', (
    tester,
  ) async {
    await tester.runAsync(() => repository.addTrip('First', null, null, null));
    await pump(tester, const TripFormScreen());
    await settle(tester);
    // Back on the first question leaves; later, it steps back.
    for (var step = 0; step < 3; step++) {
      if (step == 0) {
        await tester.enterText(find.byType(TextField), 'Second');
      }
      await tester.tap(find.text('Next'));
      await settle(tester);
    }
    expect(find.text('Pick a colour'), findsOneWidget);
    final chips = tester.widgetList<WarangChip>(find.byType(WarangChip));
    expect(chips, hasLength(6));
    final selected = chips.where((chip) => chip.selected).single;
    // First got the first colour, so Second is offered the next one.
    expect(selected.tone?.key, tripColorKeys[1]);
    expect(selected.label, tripColorNames[tripColorKeys[1]]);

    await tester.tap(find.text('Back'));
    await settle(tester);
    expect(find.text('When?'), findsOneWidget);
    // System back also steps back, but Close leaves from any question.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Where is it?'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await settle(tester);
    expect(find.byType(TripFormScreen), findsNothing);
    expect(repository.trips.where((trip) => trip.title == 'Second'), isEmpty);
  });

  testWidgets('pins wear their trip colour, and Everyday stays neutral', (
    tester,
  ) async {
    final tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
    addTearDown(tileStore.close);
    await tester.runAsync(() async {
      await repository.addTrip('Coron', null, null, null);
      await repository.addMoment(latitude: 11.9, longitude: 120.2);
      await repository.addMoment(latitude: 14.6, longitude: 121.0);
    });
    final trip = repository.trips.firstWhere((t) => t.title == 'Coron');
    final coloured = repository.moments.first;
    await tester.runAsync(
      () => repository.updateMoment(
        coloured.id,
        caption: '',
        placeLabel: '',
        tripId: trip.id,
      ),
    );
    final fill = WarangKeepsake.forTrip(trip)!.fill;
    await pump(
      tester,
      Scaffold(
        body: WarangMapSurface(
          moments: repository.moments,
          selectedId: null,
          palette: MapPalette.light,
          dark: false,
          tileStore: tileStore,
          tripRings: {trip.id: fill},
          onMomentTap: (_) {},
        ),
      ),
    );
    await tester.pump();
    final rings = tester
        .widgetList<WarangPhotoPin>(find.byType(WarangPhotoPin))
        .map((pin) => pin.ringColor)
        .toSet();
    expect(rings, {fill, null});
  });
}
