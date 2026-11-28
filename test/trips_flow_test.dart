import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/formatting.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
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
    for (var index = 0; index < 8; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// The text field under the C5 label [label].
  Finder field(String label) => find.descendant(
    of: find.widgetWithText(WarangField, label),
    matching: find.byType(TextField),
  );

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          mapTileStoreProvider.overrideWithValue(tileStore),
          clockProvider.overrideWithValue(() => DateTime(2026, 6, 15, 10, 30)),
        ],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.bySemanticsLabel('Trips'));
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
  }

  testWidgets('a dated trip is created through the form', (tester) async {
    // The test font draws every glyph one em wide, which overflows the date
    // picker's own header at phone width; real fonts fit.
    await pumpHome(tester, width: 600);
    final now = DateTime(2026, 6, 15);

    await tester.tap(find.text('New trip'));
    await settle(tester);
    // One question at a time: name, place, dates, then colour.
    expect(find.text('Where to?'), findsOneWidget);
    await tester.enterText(field('Trip name'), 'Boracay long weekend');
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Where is it?'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('When?'), findsOneWidget);
    expect(
      find.text('Photos you take between these dates go into this trip.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Choose dates'));
    await settle(tester);
    // Pick the 12th and 19th inside the current month's grid.
    final month = find
        .ancestor(
          of: find.text(DateFormat.yMMMM().format(now)),
          matching: find.byType(Column),
        )
        .first;
    await tester.tap(find.descendant(of: month, matching: find.text('12')));
    await tester.tap(find.descendant(of: month, matching: find.text('19')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    final range = formatTripRange(
      DateTime(now.year, now.month, 12),
      DateTime(now.year, now.month, 19),
    );
    expect(find.text(range), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);

    // The colour after the last trip's is chosen; another can be picked.
    expect(find.text('Pick a colour'), findsOneWidget);
    await tester.tap(find.text('Sky'));
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    final trip = repository.trips.firstWhere(
      (item) => item.title == 'Boracay long weekend',
    );
    expect(trip.startDate, DateTime(now.year, now.month, 12));
    expect(trip.endDate, DateTime(now.year, now.month, 19));
    expect(trip.colorKey, 'langit');
    expect(find.text('Trip "Boracay long weekend" created.'), findsOneWidget);
    expect(find.textContaining('$range · 0 moments'), findsOneWidget);
  });

  testWidgets('trip detail stays live and opens moments on the map', (
    tester,
  ) async {
    final moment = (await tester.runAsync(
      () => repository.addMoment(
        caption: 'Breakfast by the water',
        latitude: 11.97,
        longitude: 121.92,
      ),
    ))!;
    await tester.runAsync(() => repository.addMoment(caption: 'Second'));
    final container = await pumpHome(tester);

    await tester.tap(find.text('Everyday'));
    await settle(tester);
    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    final second = repository.moments.firstWhere((m) => m.caption == 'Second');
    await tester.runAsync(() => repository.softDeleteMoment(second.id));
    await settle(tester);
    expect(find.text('Second'), findsNothing);

    await tester.tap(find.text('Breakfast by the water'));
    await settle(tester);

    expect(find.byType(TripDetailScreen), findsNothing);
    expect(container.read(shellTabProvider), 0);
    expect(container.read(selectedMomentProvider)?.momentId, moment.id);
    expect(find.byType(MomentCard), findsOneWidget);
  });

  testWidgets('deleting a trip asks first and keeps its moments', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.addTrip(
        'Guimaras',
        null,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 2),
      );
      await repository.addMoment(
        caption: 'Mango farm',
        capturedAt: DateTime(2026, 4, 1, 9),
      );
    });
    await pumpHome(tester);

    await tester.tap(find.text('Guimaras'));
    await settle(tester);
    await tester.tap(find.byTooltip('Trip options'));
    await settle(tester);
    await tester.tap(find.text('Delete trip'));
    await settle(tester);
    expect(find.text('Its 1 moment moves to Everyday.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete trip'));
    await settle(tester);

    expect(find.byType(TripDetailScreen), findsNothing);
    expect(repository.trips.where((trip) => trip.title == 'Guimaras'), isEmpty);
    expect(repository.moments.single.tripId, repository.everyday.id);
  });

  testWidgets('a trip can be edited from its detail screen', (tester) async {
    await tester.runAsync(() => repository.addTrip('Draft', null, null, null));
    await pumpHome(tester);

    await tester.tap(find.text('Draft'));
    await settle(tester);
    await tester.tap(find.byTooltip('Trip options'));
    await settle(tester);
    await tester.tap(find.text('Edit trip'));
    await settle(tester);
    await tester.enterText(field('Trip name'), 'Iloilo food crawl');
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Next'));
      await settle(tester);
    }
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Iloilo food crawl'), findsOneWidget);
    expect(
      repository.trips.where((trip) => trip.title == 'Iloilo food crawl'),
      hasLength(1),
    );
  });
}
