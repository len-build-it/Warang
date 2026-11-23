// FEAT-003 Phase 9: the interactive maya (REQ-017 to REQ-021).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/milestones.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/maya/maya_companion.dart';
import 'package:warang/features/news_tab/news_tab_screen.dart';
import 'package:warang/features/onboarding/onboarding_screen.dart';
import 'package:warang/features/settings/about_screen.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  var now = DateTime(2026, 11, 23, 10);

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // A load left pending by an earlier test would never finish in this
    // one's fake clock, so each test reads the lines afresh.
    MayaLines.reset();
    rootBundle.evict('assets/data/maya_lines.json');
    MayaCompanionState.clock = () => now;
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
  });

  tearDown(() async {
    MayaCompanionState.clock = DateTime.now;
    repository.dispose();
    await database.close();
  });

  /// Several frames: a ticker's first frame is its start, not progress.
  Future<void> frames(WidgetTester tester, [int count = 30]) async {
    for (var frame = 0; frame < count; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget host(Widget child, {bool reduced = false}) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: buildWarangTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: child,
      ),
    ),
  );

  MayaCompanionState maya(WidgetTester tester) =>
      tester.state<MayaCompanionState>(find.byType(MayaCompanion).first);

  Widget alone({bool reduced = false}) => host(
    const Scaffold(
      body: Center(child: MayaCompanion(size: 120, place: MayaPlace.about)),
    ),
    reduced: reduced,
  );

  group('touch (M3)', () {
    testWidgets('a tap hops and says a line, never the same twice', (
      tester,
    ) async {
      await tester.pumpWidget(alone());
      await tester.tap(find.byType(MayaCompanion));
      await tester.pump();
      expect(maya(tester).pose, MayaPose.hop);
      await settle(tester);
      final first = tester.widget<WarangSpeechBubble>(
        find.byType(WarangSpeechBubble),
      );
      // Lines are not announced: the bubble sits outside the semantics tree.
      expect(find.bySemanticsLabel(first.text), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(maya(tester).pose, MayaPose.idle);

      now = now.add(const Duration(seconds: 5));
      await tester.tap(find.byType(MayaCompanion));
      await settle(tester);
      final second = tester.widget<WarangSpeechBubble>(
        find.byType(WarangSpeechBubble),
      );
      expect(second.text, isNot(first.text));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('three taps within two seconds make it dizzy', (tester) async {
      await tester.pumpWidget(alone());
      for (var tap = 0; tap < 3; tap++) {
        now = now.add(const Duration(milliseconds: 400));
        await tester.tap(find.byType(MayaCompanion));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(maya(tester).pose, MayaPose.dizzy);
      await tester.pump(const Duration(seconds: 3));
      expect(maya(tester).pose, MayaPose.idle);
    });

    testWidgets('a long press puffs it up until release', (tester) async {
      await tester.pumpWidget(alone());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MayaCompanion)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(maya(tester).pose, MayaPose.puffed);
      await gesture.up();
      await frames(tester);
      expect(maya(tester).pose, MayaPose.idle);
    });

    testWidgets('a drag moves it at most 24, then it springs back', (
      tester,
    ) async {
      await tester.pumpWidget(alone());
      final figure = find.byType(MayaFigure);
      final start = tester.getCenter(figure);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MayaCompanion)),
      );
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getCenter(figure).dx - start.dx, closeTo(24, .5));
      await gesture.up();
      await frames(tester);
      expect(tester.getCenter(figure).dx, closeTo(start.dx, .5));
    });

    testWidgets('more than five hops in a minute play calmer', (tester) async {
      await tester.pumpWidget(alone());
      for (var tap = 0; tap < 6; tap++) {
        now = now.add(const Duration(seconds: 3));
        await tester.tap(find.byType(MayaCompanion));
        await settle(tester);
        await tester.pump(const Duration(seconds: 3));
      }
      // The sixth hop says nothing.
      expect(find.byType(WarangSpeechBubble), findsNothing);
      now = now.add(const Duration(minutes: 2));
      await tester.tap(find.byType(MayaCompanion));
      await settle(tester);
      expect(find.byType(WarangSpeechBubble), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('under reduced motion a reaction is only a pose change', (
      tester,
    ) async {
      await tester.pumpWidget(alone(reduced: true));
      await tester.tap(find.byType(MayaCompanion));
      await tester.pump();
      expect(maya(tester).pose, MayaPose.hop);
      expect(
        find.descendant(
          of: find.byType(MayaCompanion),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('it is named once for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(alone());
      expect(find.bySemanticsLabel('Maya, the Warang mascot'), findsOneWidget);
      handle.dispose();
    });
  });

  test('no pose is sad, lonely, or waiting (REQ-019)', () {
    for (final pose in MayaPose.values) {
      expect(pose.name, isNot(matches(RegExp('sad|lone|wait|miss'))));
    }
  });

  group('context (M4)', () {
    MayaPose at(DateTime time, {List<Trip> trips = const []}) =>
        contextPose(now: time, trips: trips, moments: const []);

    test('late at night it is sleepy', () {
      expect(at(DateTime(2026, 1, 1, 23, 30)), MayaPose.sleepy);
      expect(at(DateTime(2026, 1, 1, 4, 59)), MayaPose.sleepy);
      expect(at(DateTime(2026, 1, 1, 5)), MayaPose.idle);
    });

    test('on a trip start date it holds a packed bag', () {
      final trip = Trip(
        id: 't',
        title: 'Iloilo',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );
      expect(at(DateTime(2026, 1, 1, 9), trips: [trip]), MayaPose.packedBag);
    });

    test('after a trip with moments it holds a postcard', () {
      final trip = Trip(
        id: 't',
        title: 'Iloilo',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );
      final pose = contextPose(
        now: DateTime(2026, 2, 1, 9),
        trips: [trip],
        moments: [Moment(id: 'm', tripId: 't', capturedAt: DateTime(2026))],
      );
      expect(pose, MayaPose.postcard);
    });
  });

  group('where it appears (M2, REQ-017)', () {
    Future<void> expectMaya(
      WidgetTester tester,
      Widget screen, {
      required bool shown,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(screen));
      await settle(tester);
      expect(
        find.byType(MayaCompanion),
        shown ? findsWidgets : findsNothing,
        reason: '${screen.runtimeType}',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }

    testWidgets('on first run, the shelf, News, Settings, and About', (
      tester,
    ) async {
      await expectMaya(tester, const OnboardingScreen(), shown: true);
      await expectMaya(tester, const HomeTabScreen(), shown: true);
      await expectMaya(
        tester,
        NewsTabScreen(entries: Future.value(const [])),
        shown: true,
      );
      await expectMaya(tester, const SettingsScreen(), shown: true);
      await expectMaya(tester, const AboutScreen(), shown: true);
    });

    testWidgets('perched on the first trip card', (tester) async {
      await tester.runAsync(
        () => repository.addTrip('Aklan', null, null, null),
      );
      await tester.pumpWidget(host(const HomeTabScreen()));
      await settle(tester);
      final perch = tester.getRect(find.byType(MayaCompanion));
      final card = tester.getRect(find.byType(TripShelfCard));
      expect(perch.width, 56);
      expect(perch.bottom, closeTo(card.top + 12, 14));
    });

    testWidgets('never on the map, the moment card, or capture', (
      tester,
    ) async {
      final tileStore = MapTileStore(
        databasePath: sqflite.inMemoryDatabasePath,
      );
      addTearDown(tileStore.close);
      final moment = (await tester.runAsync(
        () => repository.addMoment(latitude: 11.97, longitude: 121.92),
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            mapTileStoreProvider.overrideWithValue(tileStore),
          ],
          child: MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: const AppShell(),
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(TravelModeScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TravelModeScreen),
          matching: find.byType(MayaCompanion),
        ),
        findsNothing,
      );
      ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      ).read(selectedMomentProvider.notifier).select(moment);
      await settle(tester);
      expect(find.byType(MomentCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TravelModeScreen),
          matching: find.byType(MayaCompanion),
        ),
        findsNothing,
      );
      // Let the tile cache's database timeouts run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('never on capture', (tester) async {
      await expectMaya(
        tester,
        CaptureScreen(initialPhoto: XFile('missing.jpg'), fetchLocation: false),
        shown: false,
      );
    });
  });

  group('milestones (REQ-020)', () {
    test('first moment, first in a trip, and somewhere new', () {
      const trip = Trip(id: 'boracay', title: 'Boracay');
      Moment at(String id, {String tripId = 'everyday', double? lat}) => Moment(
        id: id,
        tripId: tripId,
        capturedAt: DateTime(2026),
        latitude: lat,
        longitude: lat == null ? null : 121.9,
      );
      expect(
        milestoneFor(at('a', lat: 11.9), const [], null)?.kind,
        MilestoneKind.firstMoment,
      );
      final everyday = [at('a', lat: 11.9)];
      expect(
        milestoneFor(at('b', tripId: 'boracay'), everyday, trip)?.kind,
        MilestoneKind.firstInTrip,
      );
      // About 11 km away: not new.
      expect(milestoneFor(at('c', lat: 12.0), everyday, null), isNull);
      // About 33 km away from every earlier moment: somewhere new.
      expect(
        milestoneFor(at('d', lat: 12.2), everyday, null)?.kind,
        MilestoneKind.somewhereNew,
      );
      // Without coordinates there is nothing to measure.
      expect(milestoneFor(at('e'), everyday, null), isNull);
    });

    test('each fires once, and the record survives a restart', () async {
      final first = await repository.addMoment(caption: 'One');
      expect(
        (await repository.claimMilestone(first)).map((m) => m.key).toList(),
        ['first-moment'],
      );
      expect(await repository.claimMilestone(first), isEmpty);

      // Deleting and starting again does not repeat the first-moment cheer.
      await repository.softDeleteMoment(first.id);
      final again = await repository.addMoment(caption: 'Two');
      expect(await repository.claimMilestone(again), isEmpty);

      repository.dispose();
      repository = WarangRepository(database);
      await repository.initialize();
      expect(await repository.claimMilestone(again), isEmpty);
    });

    testWidgets('the first save is cheered once by the maya in the toast', (
      tester,
    ) async {
      final tileStore = MapTileStore(
        databasePath: sqflite.inMemoryDatabasePath,
      );
      addTearDown(tileStore.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            mapTileStoreProvider.overrideWithValue(tileStore),
          ],
          child: MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: const AppShell(),
          ),
        ),
      );
      await settle(tester);
      final screen = tester.state<TravelModeScreenState>(
        find.byType(TravelModeScreen),
      );
      Future<void> save(String caption) async {
        final moment = (await tester.runAsync(
          () => repository.addMoment(caption: caption),
        ))!;
        await tester.runAsync(() => screen.showCaptured(moment));
        await settle(tester);
      }

      await save('First');
      final toast = find.byType(WarangToast);
      expect(
        find.descendant(of: toast, matching: find.byType(MayaCompanion)),
        findsOneWidget,
      );
      expect(
        find.text('Your first moment! Saved to Everyday.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      await save('Second');
      expect(find.text('Saved to Everyday'), findsOneWidget);
      expect(
        find.descendant(of: toast, matching: find.byType(MayaCompanion)),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    test('nothing in the app counts streaks or missed days (REQ-021)', () {
      final hits = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => RegExp(
              'streak|consecutive',
              caseSensitive: false,
            ).hasMatch(file.readAsStringSync()),
          )
          .map((file) => file.path)
          .toList();
      expect(hits, isEmpty);
    });
  });
}
