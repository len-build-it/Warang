// FEAT-003 REQ-006: every tappable icon carries a tooltip or a semantic
// label, on every main screen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:warang/core/models.dart';
import 'package:warang/core/place_categories.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';

void main() {
  late Directory documents;
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;
  late Moment moment;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    // A missed tap would check the previous screen under the next one's name.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('warang_icons_');
    database = WarangDatabase.memory();
    repository = WarangRepository(
      database,
      photoStore: PhotoStore(documentsDirectory: documents),
    );
    await repository.initialize();
    await repository.setName('Len');
    await repository.addTrip('Boracay', 'Malay, Aklan', null, null);
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
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Widget host(Widget home) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      mapTileStoreProvider.overrideWithValue(tileStore),
      locationReaderProvider.overrideWithValue(() async => null),
    ],
    child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: home),
  );

  /// Fails when an on-screen icon sits in a tappable node with no words.
  void expectLabelledIcons(WidgetTester tester, String screen) {
    final icons = find.byType(WarangIcon).evaluate().toList();
    expect(icons, isNotEmpty, reason: '$screen shows no icons');
    for (final element in icons) {
      final node = tester.getSemantics(
        find.byElementPredicate((candidate) => candidate == element),
      );
      final data = node.getSemanticsData();
      if (!data.hasAction(SemanticsAction.tap)) continue;
      expect(
        data.label.trim().isNotEmpty || data.tooltip.trim().isNotEmpty,
        isTrue,
        reason:
            '$screen: ${(element.widget as WarangIcon).glyph.stroke} '
            'is tappable but has no label or tooltip',
      );
    }
  }

  testWidgets('every tappable icon on the main screens is labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const AppShell()));
    await settle(tester);
    expectLabelledIcons(tester, 'map');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    expectLabelledIcons(tester, 'moment card');
    container.read(selectedMomentProvider.notifier).clear();
    await settle(tester);

    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    expectLabelledIcons(tester, 'You sheet');
    await tester.binding.handlePopRoute();
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Search').first);
    await settle(tester);
    expectLabelledIcons(tester, 'search');
    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
    expectLabelledIcons(tester, 'search with no results');

    await tester.tap(find.bySemanticsLabel('Trips').first);
    await settle(tester);
    expectLabelledIcons(tester, 'trips');
    await tester.tap(find.text('Boracay'));
    await settle(tester);
    expectLabelledIcons(tester, 'trip detail');
    await tester.binding.handlePopRoute();
    await settle(tester);
    // The page transition outlasts one settle; the dock takes no taps
    // until the route is gone.
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('News').first);
    await settle(tester);
    expectLabelledIcons(tester, 'news');

    await tester.tap(find.bySemanticsLabel('Map').first);
    await settle(tester);
    await tester.tap(find.byTooltip('You'));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expectLabelledIcons(tester, 'settings');
    handle.dispose();
  });

  testWidgets('capture screen icons are labelled', (tester) async {
    final handle = tester.ensureSemantics();
    late File photo;
    await tester.runAsync(() async {
      photo = File(p.join(documents.path, 'camera.jpg'))
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 30)));
    });
    await tester.pumpWidget(
      host(CaptureScreen(initialPhoto: XFile(photo.path))),
    );
    await settle(tester);
    expectLabelledIcons(tester, 'capture');
    handle.dispose();
  });

  testWidgets('all 14 category glyphs exist and CategoryDisc carries labels', (
    tester,
  ) async {
    expect(WarangGlyphs.all.length, 36);
    expect(PlaceCategories.all.length, 14);
    for (final category in PlaceCategories.all) {
      expect(WarangGlyphs.all.values, contains(category.glyph));
    }

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWarangTheme(Brightness.light),
        home: Scaffold(
          body: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in PlaceCategories.all)
                CategoryDisc(category: category, size: 40),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    for (final category in PlaceCategories.all) {
      expect(find.bySemanticsLabel(category.name), findsOneWidget);
    }
    handle.dispose();
  });
}
