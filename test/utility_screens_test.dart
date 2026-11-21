import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late Directory tempDir;
  late PhotoStore photoStore;
  late MapTileStore mapTileStore;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    tempDir = Directory.systemTemp.createTempSync('warang_utility_test_');
    photoStore = PhotoStore(documentsDirectory: tempDir);
    mapTileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await mapTileStore.close();
    repository.dispose();
    await database.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      mapTileStoreProvider.overrideWithValue(mapTileStore),
    ],
    child: MaterialApp(
      theme: buildWarangTheme(Brightness.light),
      darkTheme: buildWarangTheme(Brightness.dark),
      home: child,
    ),
  );

  testWidgets(
    'MomentSearchDelegate shows explicit empty state on unmatched query',
    (tester) async {
      final delegate = MomentSearchDelegate(repository, photoStore: photoStore);
      delegate.query = 'nonexistentquery123';

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) =>
                Scaffold(body: delegate.buildResults(context)),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
      expect(
        find.text('No matches found for "nonexistentquery123"'),
        findsOneWidget,
      );
      expect(
        find.text('Try searching for a different caption or place name.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'MomentSearchDelegate renders readable caption, place, and plain dash',
    (tester) async {
      await tester.runAsync(() async {
        await repository.addMoment(
          caption: 'Sunset over Boracay',
          placeLabel: 'Station 1',
          capturedAt: DateTime(2026, 4, 15),
        );
      });

      final delegate = MomentSearchDelegate(repository, photoStore: photoStore);
      delegate.query = 'Boracay';

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) =>
                Scaffold(body: delegate.buildResults(context)),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Sunset over Boracay'), findsOneWidget);
      expect(find.text('Station 1 - 15 Apr 2026'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('SettingsScreen reports the real photo storage size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final photos = Directory('${tempDir.path}/warang/photos/2026/10')
        ..createSync(recursive: true);
      File('${photos.path}/a.jpg').writeAsBytesSync(List.filled(2048, 1));
    });
    // The size is read with directory streams, which only advance on the
    // real event loop, so the screen is built outside the fake clock.
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            mapTileStoreProvider.overrideWithValue(mapTileStore),
            photoStoreProvider.overrideWithValue(photoStore),
          ],
          child: MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(find.text('2.0 KB'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'SettingsScreen provides back navigation AppBar, non-tappable info, and Clear action with SnackBar',
    (tester) async {
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Follows your phone'), findsOneWidget);
      expect(find.text('Clean up'), findsNothing);
      expect(find.text('Sharing'), findsNothing);
      expect(find.text('Copy caption on share'), findsNothing);
      expect(find.text('Corner mark on images'), findsNothing);
      expect(find.textContaining('Nothing leaves it'), findsNothing);

      final clearButton = find.widgetWithText(TextButton, 'Clear');
      expect(clearButton, findsOneWidget);

      // Clear asks first; Cancel keeps the cache.
      await tester.tap(clearButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clear offline map cache?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clear offline map cache?'), findsNothing);
      expect(find.text('Offline map cache cleared.'), findsNothing);

      await tester.tap(clearButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Clear cache'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Offline map cache cleared.'), findsOneWidget);

      final footer = find.text('Your photos and pins stay on this phone.');
      await tester.scrollUntilVisible(footer, 200);
      expect(footer, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'CaptureScreen layout is responsive on 360x640 screen without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeFile = File('${tempDir.path}/fake_capture.jpg');
      fakeFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

      await tester.pumpWidget(
        app(
          CaptureScreen(
            initialPhoto: XFile(fakeFile.path),
            fetchLocation: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retake'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Say something (optional)'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      final retakeFinder = find.bySemanticsLabel(RegExp('Retake photograph'));
      expect(retakeFinder, findsOneWidget);
      final retakeSize = tester.getSize(retakeFinder);
      expect(retakeSize.width, greaterThanOrEqualTo(48.0));
      expect(retakeSize.height, greaterThanOrEqualTo(48.0));

      final cancelFinder = find.bySemanticsLabel(RegExp('Cancel capture'));
      expect(cancelFinder, findsOneWidget);
      final cancelSize = tester.getSize(cancelFinder);
      expect(cancelSize.width, greaterThanOrEqualTo(48.0));
      expect(cancelSize.height, greaterThanOrEqualTo(48.0));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Trip creation dialog validates required trip name and creates trip with feedback',
    (tester) async {
      await tester.pumpWidget(app(const HomeTabScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final newTripButton = find.text('New trip');
      expect(newTripButton, findsOneWidget);
      await tester.tap(newTripButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Trip name'), findsOneWidget);
      expect(find.text('Place (optional)'), findsOneWidget);

      final createButton = find.widgetWithText(FilledButton, 'Create');
      expect(createButton, findsOneWidget);

      // Tap create with empty trip name -> should validate and show error
      await tester.tap(createButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trip name is required'), findsOneWidget);

      // Enter valid trip name
      await tester.enterText(
        find.widgetWithText(TextField, 'Trip name'),
        'Visayas Expedition',
      );
      await tester.pump();

      // Error text should clear
      expect(find.text('Trip name is required'), findsNothing);

      // Tap create and wait for async DB insert
      await tester.tap(createButton);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (repository.trips.any((t) => t.title == 'Visayas Expedition')) {
          break;
        }
      }
      // Animate SnackBar entrance
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should close and SnackBar appear
      expect(
        repository.trips.any((t) => t.title == 'Visayas Expedition'),
        isTrue,
      );
      expect(find.text('Trip "Visayas Expedition" created.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
