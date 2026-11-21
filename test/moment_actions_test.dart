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

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<ProviderContainer> openMoment(
    WidgetTester tester,
    Moment moment,
  ) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    expect(find.byType(MomentCard), findsOneWidget);
    return container;
  }

  testWidgets('edit sheet saves caption, place, and trip', (tester) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(
        caption: 'Old caption',
        latitude: 11.9686,
        longitude: 121.918,
      ),
    ))!;
    await tester.runAsync(
      () => repository.addTrip('Antique', null, null, null),
    );
    await openMoment(tester, moment);
    expect(
      find.textContaining('11.969°N · 121.918°E', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Edit'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Caption'),
      'Sunset at White Beach',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Place name'),
      'White Beach',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Antique').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = repository.moments.single;
    expect(saved.caption, 'Sunset at White Beach');
    expect(saved.placeLabel, 'White Beach');
    expect(saved.tripId, repository.trips.firstWhere((t) => !t.isEveryday).id);
    expect(find.text('Sunset at White Beach'), findsOneWidget);
    expect(
      find.textContaining('White Beach ·', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('add location places the pin at the map centre', (tester) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(caption: 'No fix'),
    ))!;
    final container = await openMoment(tester, moment);

    await tester.tap(find.bySemanticsLabel('Add location'));
    await settle(tester);
    expect(find.text('Move the map to the spot'), findsOneWidget);
    expect(find.byType(MomentCard), findsNothing);

    await tester.tap(find.text('Confirm'));
    await settle(tester);

    final saved = repository.moments.single;
    expect(saved.latitude, isNotNull);
    expect(saved.longitude, isNotNull);
    expect(find.text('Move the map to the spot'), findsNothing);
    expect(container.read(selectedMomentProvider)?.momentId, moment.id);
    expect(find.textContaining('°N ·', findRichText: true), findsOneWidget);
  });

  testWidgets('back leaves placement without moving the moment', (
    tester,
  ) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(caption: 'No fix'),
    ))!;
    await openMoment(tester, moment);

    await tester.tap(find.bySemanticsLabel('Add location'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Move the map to the spot'), findsNothing);
    expect(find.byType(MomentCard), findsOneWidget);
    expect(repository.moments.single.latitude, isNull);
  });

  testWidgets('delete offers undo, which restores the moment', (tester) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(
        caption: 'Keep me',
        latitude: 11.9686,
        longitude: 121.918,
      ),
    ))!;
    final container = await openMoment(tester, moment);

    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(repository.moments, isEmpty);
    expect(find.byType(MomentCard), findsNothing);
    expect(find.text('Moment deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(repository.moments.single.id, moment.id);
    expect(container.read(selectedMomentProvider)?.momentId, moment.id);
    expect(find.byType(MomentCard), findsOneWidget);
  });

  testWidgets('dragging the handle down dismisses the card', (tester) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(latitude: 11.9686, longitude: 121.918),
    ))!;
    final container = await openMoment(tester, moment);

    await tester.fling(
      find.bySemanticsLabel('Close moment'),
      const Offset(0, 300),
      1200,
    );
    await settle(tester);

    expect(container.read(selectedMomentProvider), isNull);
    expect(find.byType(MomentCard), findsNothing);
  });
}
