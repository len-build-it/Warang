import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/map/map_tile_store.dart';
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

  testWidgets('back on Home or News returns to Travel Mode', (tester) async {
    final container = await pumpShell(tester);
    for (final tab in ['Home', 'News']) {
      await tester.tap(find.text(tab));
      await settle(tester);
      expect(container.read(shellTabProvider), isNot(0));
      expect(canPop(tester), isFalse);

      await systemBack(tester);

      expect(container.read(shellTabProvider), 0);
    }
    expect(canPop(tester), isTrue);
  });

  testWidgets('drawer is modal over the navigation and back closes it', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    expect(find.text('About Warang'), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await settle(tester);
    expect(find.text('About Warang'), findsOneWidget);

    // The Home tab sits under the open drawer, so it cannot be reached.
    await tester.tapAt(tester.getCenter(find.text('Home').last));
    await settle(tester);
    expect(container.read(shellTabProvider), 0);
    expect(find.text('About Warang'), findsOneWidget);

    // The scrim beside the drawer closes it.
    await tester.tapAt(const Offset(370, 400));
    await settle(tester);
    expect(find.text('About Warang'), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await settle(tester);
    await systemBack(tester);
    expect(find.text('About Warang'), findsNothing);
  });

  testWidgets('closed drawer exposes no semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpShell(tester);
    expect(find.bySemanticsLabel('Search'), findsNothing);
    expect(find.bySemanticsLabel('Settings'), findsNothing);
    handle.dispose();
  });

  testWidgets('search from Home opens the result on Travel Mode', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await tester.tap(find.text('Home'));
    await settle(tester);

    await tester.tap(find.byTooltip('Search moments'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'sunset');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
    await tester.tap(find.text('Sunset at White Beach').last);
    await settle(tester);

    expect(container.read(shellTabProvider), 0);
    expect(container.read(selectedMomentProvider)?.momentId, moment.id);
    expect(container.read(selectedMomentProvider)?.focus, isTrue);
    expect(find.byType(MomentCard), findsOneWidget);
  });
}
