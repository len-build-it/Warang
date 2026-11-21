import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/device_providers.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

typedef _Fix = ({double latitude, double longitude});

void main() {
  late Directory documents;
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;
  late File photo;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('warang_capture_flow_');
    database = WarangDatabase.memory();
    repository = WarangRepository(
      database,
      photoStore: PhotoStore(documentsDirectory: documents),
    );
    await repository.initialize();
    await repository.setName('Len');
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
    photo = File(p.join(documents.path, 'camera.jpg'))
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 30)));
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget host(Widget home, {LocationReader? locate}) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      mapTileStoreProvider.overrideWithValue(tileStore),
      locationReaderProvider.overrideWithValue(locate ?? () async => null),
      cameraPickerProvider.overrideWithValue(() async => XFile(photo.path)),
    ],
    child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: home),
  );

  Future<void> realWait(WidgetTester tester, [int ms = 200]) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('meta line reports locating, then the coordinates', (
    tester,
  ) async {
    final fix = Completer<_Fix?>();
    await tester.pumpWidget(
      host(
        CaptureScreen(initialPhoto: XFile(photo.path)),
        locate: () => fix.future,
      ),
    );
    await tester.pump();
    expect(find.text('Locating…'), findsOneWidget);

    fix.complete((latitude: 11.96864, longitude: 121.91804));
    await tester.pump();
    await tester.pump();

    expect(find.text('11.969°N'), findsOneWidget);
    expect(find.text('121.918°E'), findsOneWidget);
    expect(find.textContaining('Locating'), findsNothing);
  });

  testWidgets('meta line says no location yet when no fix arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(CaptureScreen(initialPhoto: XFile(photo.path))),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No location yet'), findsOneWidget);
    expect(find.text('Saving to Everyday'), findsOneWidget);
  });

  testWidgets('trip line names the dated trip covering today', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(
      () => repository.addTrip(
        'Boracay',
        null,
        DateTime(today.year, today.month, today.day),
        DateTime(today.year, today.month, today.day),
      ),
    );
    await tester.pumpWidget(
      host(
        CaptureScreen(initialPhoto: XFile(photo.path), fetchLocation: false),
      ),
    );
    await tester.pump();

    expect(find.text('Saving to Boracay'), findsOneWidget);
  });

  testWidgets('a failed save keeps the photo and offers retry', (tester) async {
    phone(tester);
    final missing = XFile(p.join(documents.path, 'missing.jpg'));
    await tester.pumpWidget(
      host(CaptureScreen(initialPhoto: missing, fetchLocation: false)),
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await realWait(tester);

    expect(
      find.text("Couldn't save this photo. It's still here - try again."),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(repository.moments, isEmpty);
  });

  test(
    'locationReaderProvider returns null when permission is denied',
    () async {
      for (final status in [
        LocationPermission.denied,
        LocationPermission.deniedForever,
        LocationPermission.unableToDetermine,
      ]) {
        final container = ProviderContainer(
          overrides: [
            locationPermissionProvider.overrideWithValue(() async => status),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(locationReaderProvider)(), isNull);
      }
    },
  );

  testWidgets('a capture saves, returns to the map, and confirms the trip', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      host(
        const AppShell(),
        locate: () async => (latitude: 11.9686, longitude: 121.918),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(WarangCaptureButton));
    await realWait(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CaptureScreen), findsOneWidget);

    // Save runs real file IO, so it must start outside the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 40 && repository.moments.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    for (var i = 0; i < 10; i++) {
      if (find.byType(CaptureScreen).evaluate().isEmpty) break;
      await realWait(tester, 50);
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CaptureScreen), findsNothing);
    expect(find.text('Saved to Everyday'), findsOneWidget);
    expect(repository.moments, hasLength(1));
    expect(repository.moments.single.latitude, 11.9686);
    expect(repository.moments.single.relPath, isNotNull);
    // Back on the map, the new moment's pin is the one that lands.
    final map = tester.widget<WarangMapSurface>(find.byType(WarangMapSurface));
    expect(map.landingId, repository.moments.single.id);
  });
}
