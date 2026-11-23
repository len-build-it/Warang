// Renders the main Warang screens to PNG files for visual review.
//
// Run manually; it is outside test/ so the default suite never runs it:
//   flutter test tool/ux_screenshots_test.dart --update-goldens \
//     --dart-define=UX_LABEL=phase-1
//
// Output: docs/evidence/FEAT-001/<UX_LABEL>/. Map tiles cannot load in the
// test host, so the map renders as its ground colour.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/device_providers.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/place_categories.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/places/place_book_installer.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/places/place_picker_sheet.dart';
import 'package:warang/features/search/search_tab_screen.dart';

import '../test/support/place_book_fixture.dart';

class _ReadyPlaceBookNotifier extends PlaceBookNotifier {
  _ReadyPlaceBookNotifier(this._book);
  final PlaceBook _book;

  @override
  PlaceBookState build() => PlaceBookState.ready(_book);
}

const _label = String.fromEnvironment('UX_LABEL', defaultValue: 'latest');

/// The system text size, for the REQ-022 check at 2.0.
final _textScale = double.parse(
  const String.fromEnvironment('UX_TEXT_SCALE', defaultValue: '1'),
);

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Finds the SDK's bundled Material fonts by walking up from the tester.
String _materialFontsDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = p.join(directory.path, 'material_fonts');
    if (Directory(candidate).existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError(
    'Material fonts not found from ${Platform.resolvedExecutable}',
  );
}

Uint8List _photo(int seed) {
  final palettes = [
    [img.ColorRgb8(40, 120, 180), img.ColorRgb8(240, 200, 120)],
    [img.ColorRgb8(30, 140, 90), img.ColorRgb8(200, 230, 160)],
    [img.ColorRgb8(200, 90, 60), img.ColorRgb8(250, 210, 150)],
    [img.ColorRgb8(90, 60, 140), img.ColorRgb8(240, 150, 120)],
  ];
  final colors = palettes[seed % palettes.length];
  final image = img.Image(width: 400, height: 300);
  for (var y = 0; y < image.height; y++) {
    final t = y / image.height;
    final color = img.ColorRgb8(
      (colors[0].r * (1 - t) + colors[1].r * t).round(),
      (colors[0].g * (1 - t) + colors[1].g * t).round(),
      (colors[0].b * (1 - t) + colors[1].b * t).round(),
    );
    for (var x = 0; x < image.width; x++) {
      image.setPixel(x, y, color);
    }
  }
  return img.encodeJpg(image);
}

void main() {
  late Directory documents;
  late WarangDatabase database;
  late WarangRepository repository;
  late PhotoStore photoStore;
  late MapTileStore tileStore;
  late PlaceBook placeBook;

  setUpAll(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    final fonts = p.join(Directory.current.path, 'assets', 'fonts');
    await _loadFont('Bagel Fat One', [
      p.join(fonts, 'BagelFatOne-Regular.ttf'),
    ]);
    await _loadFont('Atkinson Hyperlegible Next', [
      p.join(fonts, 'AtkinsonHyperlegibleNext-Regular.ttf'),
      p.join(fonts, 'AtkinsonHyperlegibleNext-SemiBold.ttf'),
      p.join(fonts, 'AtkinsonHyperlegibleNext-Bold.ttf'),
    ]);
    await _loadFont('Shantell Sans', [
      p.join(fonts, 'ShantellSans-Medium.ttf'),
    ]);
    await _loadFont('WarangIcons', [p.join(fonts, 'WarangIcons.ttf')]);
    final material = _materialFontsDirectory();
    await _loadFont('MaterialIcons', [
      p.join(material, 'materialicons-regular.otf'),
    ]);
  });

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('warang_ux_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
    database = WarangDatabase.memory();
    photoStore = PhotoStore(documentsDirectory: documents);
    repository = WarangRepository(database, photoStore: photoStore);
    await repository.initialize();
    // In memory, so no camera or location leaks in from an earlier run.
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
    placeBook = await openFixturePlaceBook();
  });

  tearDown(() async {
    await placeBook.close();
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await repository.setName('Len');
      await repository.addTrip(
        'Boracay long weekend',
        'Malay, Aklan',
        DateTime(2026, 9, 6),
        DateTime(2026, 9, 14),
      );
      final moments = <(double, double, String?)>[
        (11.9686, 121.9180, 'Sunset at White Beach'),
        (11.9600, 121.9300, null),
        (11.9750, 121.9250, 'Breakfast by the water'),
        (11.9690, 121.9182, 'Second visit'),
      ];
      final cafe = (await placeBook.search('Station Two Espresso')).first;
      for (var index = 0; index < moments.length; index++) {
        final (latitude, longitude, caption) = moments[index];
        final stored = await photoStore.storeBytesAsset(_photo(index));
        await repository.addMoment(
          caption: caption,
          latitude: latitude,
          longitude: longitude,
          place: index == 0 ? cafe : null,
          relPath: stored.relPath,
          thumbRelPath: stored.thumbRelPath,
          width: stored.width,
          height: stored.height,
          bytes: stored.bytes,
          capturedAt: DateTime(2026, 9, 1 + index * 6, 16, 42),
        );
      }
    });
  }

  /// Pins far enough apart to stand alone at zoom 13, and two that group.
  Future<void> seedPins(WidgetTester tester) async {
    await tester.runAsync(() async {
      await repository.setName('Len');
      // Three of the pins fall in a dated trip and wear its colour.
      await repository.addTrip(
        'Boracay long weekend',
        'Malay, Aklan',
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 4),
      );
      final moments = <(double, double, String)>[
        (11.9950, 121.9000, 'Puka Beach'),
        (11.9840, 121.9380, 'Bulabog'),
        (11.9560, 121.9070, 'Sunset at White Beach'),
        (11.9450, 121.9390, 'Ferry over'),
        (11.9456, 121.9394, 'Halo-halo'),
      ];
      for (var index = 0; index < moments.length; index++) {
        final (latitude, longitude, caption) = moments[index];
        final stored = await photoStore.storeBytesAsset(_photo(index));
        await repository.addMoment(
          caption: caption,
          latitude: latitude,
          longitude: longitude,
          relPath: stored.relPath,
          thumbRelPath: stored.thumbRelPath,
          width: stored.width,
          height: stored.height,
          bytes: stored.bytes,
          capturedAt: DateTime(2026, 9, 1 + index, 16, 42),
        );
      }
      // The map reopens on the camera the user left it at.
      await tileStore.saveCamera(const LatLng(11.9690, 121.9180), 13);
    });
  }

  // Looking up, reading, and decoding a photo each need a real-async turn.
  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 16; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Widget host(Widget home, Brightness brightness, {LocationReader? locate}) =>
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          mapTileStoreProvider.overrideWithValue(tileStore),
          placeBookProvider.overrideWith(
            () => _ReadyPlaceBookNotifier(placeBook),
          ),
          locationReaderProvider.overrideWithValue(
            locate ??
                () async =>
                    const LocationFix(latitude: 11.9686, longitude: 121.918),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildWarangTheme(Brightness.light),
          darkTheme: buildWarangTheme(Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: home,
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 96, bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(top: 96, bottom: 68);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = _textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/evidence/FEAT-001/$_label/$name.png'),
    );
  }

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('onboarding $theme', (tester) async {
      phone(tester);
      await tester.pumpWidget(host(const WarangHome(), brightness));
      await shot(tester, '01_onboarding_$theme');
    });

    testWidgets('travel empty $theme', (tester) async {
      phone(tester);
      await tester.runAsync(() => repository.setName('Len'));
      await tester.pumpWidget(host(const WarangHome(), brightness));
      await shot(tester, '02_travel_empty_$theme');
    });

    testWidgets('filled flows $theme', (tester) async {
      phone(tester);
      await seed(tester);
      await tester.pumpWidget(host(const WarangHome(), brightness));
      await shot(tester, '03_travel_filled_$theme');

      await tester.tap(find.byTooltip('You'));
      await shot(tester, '05_you_sheet_$theme');
      // A tap on the dimmer above the sheet closes it.
      await tester.tapAt(const Offset(195, 60));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Search').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'beach');
      await shot(tester, '06_search_$theme');
      await tester.tap(
        find
            .descendant(
              of: find.byType(MomentSearchResults),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await shot(tester, '04_moment_open_$theme');
      await tester.tap(find.text('Edit'));
      await shot(tester, '13_edit_sheet_$theme');
      await tester.tap(find.text('Move pin on map'));
      await shot(tester, '14_placement_$theme');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      // On the dimmer, beside the selected pin.
      await tester.tapAt(const Offset(40, 120));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Trips').first);
      await shot(tester, '07_home_$theme');
      // At large text sizes the button is further down the shelf.
      await tester.ensureVisible(find.text('New trip'));
      await settle(tester);
      await tester.tap(find.text('New trip'));
      await shot(tester, '15_trip_form_$theme');
      await tester.enterText(find.byType(TextField), 'Antique');
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.text('Next'));
        await settle(tester);
      }
      await shot(tester, '18_trip_colour_$theme');
      await tester.tap(find.byType(CloseButton));
      await settle(tester);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await shot(tester, '08_home_scrolled_$theme');
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await settle(tester);
      await tester.tap(find.text('Everyday'));
      await shot(tester, '09_trip_detail_$theme');
      await tester.pageBack();
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('News').first);
      await shot(tester, '10_news_$theme');

      await tester.tap(find.bySemanticsLabel('Map').first);
      await settle(tester);
      await tester.tap(find.byTooltip('You'));
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await shot(tester, '11_settings_$theme');
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byTooltip('You'));
      await settle(tester);
      await tester.tap(find.text('About Warang'));
      await shot(tester, '19_about_$theme');
    });

    testWidgets('photo pins $theme', (tester) async {
      phone(tester);
      await seedPins(tester);
      await tester.pumpWidget(host(const WarangHome(), brightness));
      await settle(tester);
      expect(find.byType(WarangPhotoPin), findsNWidgets(3));
      expect(find.byType(WarangClusterPin), findsOneWidget);
      await shot(tester, '16_map_pins_$theme');
      // The southern pin would be under the card, so the map makes room.
      await tester.tap(find.bySemanticsLabel('Pin, Sunset at White Beach'));
      await shot(tester, '17_pin_selected_$theme');
    });

    testWidgets('capture $theme', (tester) async {
      phone(tester);
      late File file;
      await tester.runAsync(() async {
        file = File(p.join(documents.path, 'shot.jpg'))
          ..writeAsBytesSync(_photo(2));
      });
      await tester.pumpWidget(
        host(CaptureScreen(initialPhoto: XFile(file.path)), brightness),
      );
      await shot(tester, '12_capture_$theme');
    });

    testWidgets('categories $theme', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Categories', style: WarangType.displayM),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 3.0,
                        children: [
                          for (final category in PlaceCategories.all)
                            Row(
                              children: [
                                CategoryDisc(category: category, size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: WarangType.titleS,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          brightness,
        ),
      );
      await shot(tester, '20_categories_$theme');
    });

    testWidgets('places picker and capture chip $theme', (tester) async {
      phone(tester);
      await tester.runAsync(() async {
        await repository.setName('Len');
        await repository.addMoment(placeLabel: 'Kape Tambayan');
      });

      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showPlacePickerSheet(
                    context,
                    near: const LatLng(11.7086, 122.3643),
                    allowUserPlace: true,
                    allowClear: true,
                    userPlaces: repository.places,
                  ),
                  child: const Text('Pick'),
                ),
              ),
            ),
          ),
          brightness,
        ),
      );
      await tester.tap(find.text('Pick'));
      await shot(tester, '21_place_picker_$theme');

      await tester.enterText(find.byType(TextField).last, 'kap');
      await shot(tester, '22_place_picker_typing_$theme');
      await tester.binding.handlePopRoute();
      await settle(tester);

      late File file;
      await tester.runAsync(() async {
        file = File(p.join(documents.path, 'cafe_shot.jpg'))
          ..writeAsBytesSync(_photo(1));
      });
      await tester.pumpWidget(
        host(
          CaptureScreen(initialPhoto: XFile(file.path)),
          brightness,
          locate: () async => const LocationFix(
            latitude: 11.7086,
            longitude: 122.3643,
            accuracyM: 25,
          ),
        ),
      );
      await shot(tester, '23_capture_place_chip_$theme');
    });
  }
}
