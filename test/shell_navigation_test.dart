import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/dock.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/features/settings/about_screen.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;
  late Moment moment;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
    moment = await repository.addMoment(
      caption: 'Sunset at White Beach',
      latitude: 11.9686,
      longitude: 121.918,
    );
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
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
    await tester.pump(const Duration(milliseconds: 100));
    return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  bool canPop(WidgetTester tester) => tester
      .widget<PopScope<Object?>>(
        find
            .descendant(
              of: find.byType(AppShell),
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .first,
      )
      .canPop;

  testWidgets('back closes an open moment before anything else', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    expect(find.byType(MomentCard), findsOneWidget);
    expect(canPop(tester), isFalse);

    await systemBack(tester);

    expect(container.read(selectedMomentProvider), isNull);
    expect(find.byType(MomentCard), findsNothing);
    expect(canPop(tester), isTrue);
  });

  testWidgets('back on Trips, News, or Search returns to the map', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    for (final tab in ['Trips', 'News', 'Search']) {
      await tester.tap(find.bySemanticsLabel(tab).first);
      await settle(tester);
      expect(container.read(shellTabProvider), isNot(ShellTab.map));
      expect(canPop(tester), isFalse);

      await systemBack(tester);

      expect(container.read(shellTabProvider), ShellTab.map);
    }
    expect(canPop(tester), isTrue);
  });

  testWidgets('the You sheet is modal and closes with back or the dimmer', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    expect(find.text('About Warang'), findsNothing);

    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    expect(find.text('About Warang'), findsOneWidget);
    expect(find.text('Only on this phone'), findsOneWidget);

    // The dock sits under the open sheet, so it cannot be reached.
    expect(find.byType(WarangDock).hitTestable(), findsNothing);
    expect(container.read(shellTabProvider), ShellTab.map);

    // The dimmer above the sheet closes it.
    await tester.tapAt(const Offset(195, 40));
    await settle(tester);
    expect(find.text('About Warang'), findsNothing);

    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    await systemBack(tester);
    expect(find.text('About Warang'), findsNothing);
  });

  testWidgets('settings, profile, search, and About take two taps or fewer', (
    tester,
  ) async {
    final container = await pumpShell(tester);

    // Search: one tap on the dock.
    await tester.tap(find.bySemanticsLabel('Search').first);
    await settle(tester);
    expect(container.read(shellTabProvider), ShellTab.search);
    await systemBack(tester);

    // Settings: the avatar bubble, then Settings.
    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await systemBack(tester);

    // Profile: the avatar bubble, then the name opens the editor.
    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    await tester.tap(find.text('Len'));
    await settle(tester);
    expect(find.text('Your name'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await systemBack(tester);

    // About: the avatar bubble, then About Warang.
    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    await tester.tap(find.text('About Warang'));
    await settle(tester);
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Aklanon. To go out and explore.'), findsOneWidget);
  });

  testWidgets('the You sheet shows the counts as stamps', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    expect(find.byType(WarangStamp), findsNWidgets(3));
    expect(find.text('moment'), findsOneWidget);
    expect(find.text('Len'), findsOneWidget);
  });

  testWidgets('capture opens on release with no delay', (tester) async {
    await pumpShell(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WarangCaptureButton)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CaptureScreen, skipOffstage: false), findsNothing);
    await gesture.up();
    await tester.pump();
    // The capture route is built in the very frame the finger lifts (it is
    // offstage for that one frame while the transition measures heroes).
    expect(find.byType(CaptureScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('search opens the result on the map', (tester) async {
    final container = await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Search').first);
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'sunset');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
    await tester.tap(find.text('Sunset at White Beach').last);
    await settle(tester);

    expect(container.read(shellTabProvider), ShellTab.map);
    expect(container.read(selectedMomentProvider)?.momentId, moment.id);
    expect(container.read(selectedMomentProvider)?.focus, isTrue);
    expect(find.byType(MomentCard), findsOneWidget);
  });
}
