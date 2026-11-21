// One end-to-end walk through the core journey, as a user would take it:
// first run, a capture without GPS, correcting it later, organizing it into
// a trip, finding it again, and recovering from a mistaken delete.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/device_providers.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

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
    documents = Directory.systemTemp.createTempSync('warang_journey_');
    database = WarangDatabase.memory();
    repository = WarangRepository(
      database,
      photoStore: PhotoStore(documentsDirectory: documents),
    );
    await repository.initialize();
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

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 8; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('capture, correct, organize, find, and undo', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          mapTileStoreProvider.overrideWithValue(tileStore),
          cameraPickerProvider.overrideWithValue(() async => XFile(photo.path)),
          // No GPS fix: the capture must still save.
          locationReaderProvider.overrideWithValue(() async => null),
        ],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const WarangHome(),
        ),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WarangHome)),
    );

    // First run.
    await tester.enterText(find.byType(TextField), 'Len');
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.text('Capture your first moment.'), findsOneWidget);

    // Capture without GPS.
    await tester.tap(find.byType(WarangCaptureButton));
    await settle(tester);
    expect(find.textContaining('No location yet'), findsOneWidget);
    expect(find.text('Saving to Everyday'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 40 && repository.moments.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    for (var i = 0; i < 10; i++) {
      if (find.byType(CaptureScreen).evaluate().isEmpty) break;
      await settle(tester);
    }
    expect(find.text('Saved to Everyday'), findsOneWidget);
    final momentId = repository.moments.single.id;

    // Find it again from Home, since an unpinned moment has no map pin.
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.text('Everyday'));
    await settle(tester);
    await tester.tap(find.text('Moment'));
    await settle(tester);
    expect(container.read(shellTabProvider), 0);
    expect(find.byType(MomentCard), findsOneWidget);

    // Caption it later and name the place.
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
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Sunset at White Beach'), findsOneWidget);

    // Pin it by hand.
    await tester.tap(find.text('Edit'));
    await settle(tester);
    await tester.tap(find.text('Place on map'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(repository.moments.single.latitude, isNotNull);
    expect(find.byType(MomentCard), findsOneWidget);

    // Back closes the card; create a dated trip covering today.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(MomentCard), findsNothing);
    final today = DateTime.now();
    await tester.runAsync(
      () => repository.addTrip(
        'Boracay long weekend',
        'Malay, Aklan',
        DateTime(today.year, today.month, today.day),
        DateTime(today.year, today.month, today.day),
      ),
    );

    // Organize the earlier moment into the trip from its Edit sheet.
    container
        .read(selectedMomentProvider.notifier)
        .select(repository.moments.single);
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Boracay long weekend').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final trip = repository.trips.firstWhere((t) => !t.isEveryday);
    expect(repository.moments.single.tripId, trip.id);

    // The trip shows it, and opening it returns to the map.
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.text('Boracay long weekend'));
    await settle(tester);
    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(
      find.textContaining(DateFormat('d MMM yyyy').format(today)),
      findsWidgets,
    );
    await tester.tap(find.text('Sunset at White Beach'));
    await settle(tester);
    expect(container.read(selectedMomentProvider)?.momentId, momentId);

    // A mistaken delete is undone.
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(repository.moments, isEmpty);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(repository.moments.single.id, momentId);
    expect(repository.moments.single.caption, 'Sunset at White Beach');
    expect(find.byType(MomentCard), findsOneWidget);

    // Back from the open moment, then the app may exit.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(container.read(selectedMomentProvider), isNull);
    final shellPopScope = tester.widget<PopScope<Object?>>(
      find.byWidgetPredicate((widget) => widget is PopScope).first,
    );
    expect(shellPopScope.canPop, isTrue);
  });
}
