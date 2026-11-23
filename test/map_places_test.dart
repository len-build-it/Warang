import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/places/place_book_installer.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

import 'support/place_book_fixture.dart';

class _ReadyBook extends PlaceBookNotifier {
  _ReadyBook(this._book);
  final PlaceBook _book;

  @override
  PlaceBookState build() => PlaceBookState.ready(_book);
}

void main() {
  late Directory tempDir;
  late WarangDatabase db;
  late WarangRepository repo;
  late MapTileStore tileStore;
  late PlaceBook book;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('warang_map_places_');
    db = WarangDatabase.memory();
    repo = WarangRepository(
      db,
      photoStore: PhotoStore(documentsDirectory: tempDir),
    );
    await repo.initialize();
    await repo.setName('Len');
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
    book = await openFixturePlaceBook();
  });

  tearDown(() async {
    await book.close();
    await tileStore.close();
    repo.dispose();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host({bool disableAnimations = false}) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      mapTileStoreProvider.overrideWithValue(tileStore),
      placeBookProvider.overrideWith(() => _ReadyBook(book)),
    ],
    child: MaterialApp(
      theme: buildWarangTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'Find a place pill opens search, moves map, and shows offline notice (REQ-007, REQ-008)',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      await settle(tester);

      final pill = find.bySemanticsLabel('Find a place');
      expect(pill, findsOneWidget);
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));

      await tester.tap(pill);
      await settle(tester);
      expect(find.text('Search places in the Philippines'), findsWidgets);

      await tester.enterText(find.byType(TextField).last, 'Kape');
      await settle(tester);
      await tester.tap(find.text('Kape ni Juan'));
      await settle(tester);

      // Marker shows place name and offline notice (empty tile store).
      expect(find.text('Kape ni Juan'), findsOneWidget);
      expect(find.text('Map not saved here yet'), findsOneWidget);

      final mapState = tester.state<WarangMapSurfaceState>(
        find.byType(WarangMapSurface),
      );
      expect(mapState.center.latitude, closeTo(11.7086, 0.001));
      expect(mapState.center.longitude, closeTo(122.3643, 0.001));

      // Closing removes the marker.
      await tester.tap(find.byTooltip('Close place marker'));
      await settle(tester);
      expect(find.text('Kape ni Juan'), findsNothing);
    },
  );

  testWidgets('reduced motion jumps to chosen place with no animation frames', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(disableAnimations: true));
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Find a place'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'White');
    await settle(tester);
    await tester.tap(find.text('White Beach'));
    await tester.pump();

    final mapState = tester.state<WarangMapSurfaceState>(
      find.byType(WarangMapSurface),
    );
    // Under reduced motion, the map jumps immediately on the first frame.
    expect(mapState.center.latitude, closeTo(11.9618, 0.001));
    expect(mapState.center.longitude, closeTo(121.9242, 0.001));

    await settle(tester);
    mapState.moveToPlace(const LatLng(14.5915, 120.9736));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(mapState.center.latitude, closeTo(14.5915, 0.001));
    expect(mapState.center.longitude, closeTo(120.9736, 0.001));
    await settle(tester);
  });

  testWidgets(
    'placement search attaches place on confirm and drops it after pan (REQ-009)',
    (tester) async {
      phone(tester);
      final moment = (await tester.runAsync(
        () => repo.addMoment(caption: 'Needs a pin'),
      ))!;

      await tester.pumpWidget(host());
      await settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      container.read(placingMomentProvider.notifier).start(moment.id);
      await settle(tester);

      // Search pill is hidden during placement; placement search button is shown.
      expect(find.bySemanticsLabel('Find a place'), findsNothing);
      await tester.tap(find.byTooltip('Search for a place'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Kape');
      await settle(tester);
      await tester.tap(find.text('Kape ni Juan'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);

      final placed = repo.moments.single;
      expect(placed.latitude, closeTo(11.7086, 0.001));
      expect(placed.longitude, closeTo(122.3643, 0.001));
      expect(placed.placeLabel, 'Kape ni Juan');

      // Now place a second moment, search, pan away, and confirm -> no place attached.
      final moment2 = (await tester.runAsync(
        () => repo.addMoment(caption: 'Panned away'),
      ))!;
      container.read(selectedMomentProvider.notifier).clear();
      container.read(placingMomentProvider.notifier).start(moment2.id);
      await settle(tester);

      await tester.tap(find.byTooltip('Search for a place'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'White');
      await settle(tester);
      await tester.tap(find.text('White Beach'));
      await settle(tester);

      // Pan the map away before confirming.
      await tester.drag(find.byType(WarangMapSurface), const Offset(80, 60));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);

      final panned = repo.moments.firstWhere((m) => m.id == moment2.id);
      expect(panned.latitude, isNotNull);
      expect(panned.placeId, isNull);
    },
  );

  testWidgets(
    'category filter row filters map pins and resets on All (REQ-020)',
    (tester) async {
      phone(tester);
      final cafe = (await tester.runAsync(
        () => book.search('Kape ni Juan'),
      ))!.first;
      final beach = (await tester.runAsync(
        () => book.search('White Beach'),
      ))!.first;
      await tester.runAsync(() async {
        await repo.addMoment(
          caption: 'Coffee stop',
          latitude: cafe.latitude,
          longitude: cafe.longitude,
          place: cafe,
        );
        await repo.addMoment(
          caption: 'Beach day',
          latitude: beach.latitude,
          longitude: beach.longitude,
          place: beach,
        );
        await tileStore.saveCamera(const LatLng(11.83, 122.14), 10);
      });

      await tester.pumpWidget(host());
      await settle(tester);

      expect(find.widgetWithText(WarangChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(WarangChip, 'Cafe'), findsOneWidget);
      expect(find.widgetWithText(WarangChip, 'Beach'), findsOneWidget);
      expect(find.byType(WarangPhotoPin), findsNWidgets(2));

      // Filter to Cafe -> only 1 pin visible.
      await tester.tap(find.widgetWithText(WarangChip, 'Cafe'));
      await settle(tester);
      expect(find.byType(WarangPhotoPin), findsNWidgets(1));

      // Tap All -> both pins return.
      await tester.tap(find.widgetWithText(WarangChip, 'All'));
      await settle(tester);
      expect(find.byType(WarangPhotoPin), findsNWidgets(2));
    },
  );
}
