// FEAT-003 REQ-010: with reduced motion, every screen settles with no
// scale or rotation transition and no repeating animation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/you_sheet.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/place_categories.dart';
import 'package:warang/core/stamps.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/places/place_book_installer.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
import 'package:warang/features/home_tab/trip_form_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/news_tab/news_tab_screen.dart';
import 'package:warang/features/onboarding/onboarding_screen.dart';
import 'package:warang/features/places/place_picker_sheet.dart';
import 'package:warang/features/search/search_tab_screen.dart';
import 'package:warang/features/settings/about_screen.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/stamps/stamp_page_sheet.dart';

import 'support/place_book_fixture.dart';

class _ReadyBook extends PlaceBookNotifier {
  _ReadyBook(this._book);
  final PlaceBook _book;

  @override
  PlaceBookState build() => PlaceBookState.ready(_book);
}

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;
  late PlaceBook book;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    WarangStamp.resetSession();
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
    await repository.addTrip('Aklan', 'Malay', null, null);
    book = await openFixturePlaceBook();
    final cafe = (await book.search('Kape ni Juan')).first;
    final cafe2 = (await book.search('Poblacion Brew')).first;
    final beach = (await book.search('White Beach')).first;
    await repository.addMoment(
      caption: 'Morning coffee',
      latitude: cafe.latitude,
      longitude: cafe.longitude,
      place: cafe,
      capturedAt: DateTime(2026, 8, 1, 9),
    );
    await repository.addMoment(
      caption: 'Afternoon coffee',
      latitude: cafe.latitude,
      longitude: cafe.longitude,
      place: cafe,
      capturedAt: DateTime(2026, 8, 2, 9),
    );
    await repository.addMoment(
      caption: 'Second cafe',
      latitude: cafe2.latitude,
      longitude: cafe2.longitude,
      place: cafe2,
      capturedAt: DateTime(2026, 8, 3, 9),
    );
    await repository.addMoment(
      caption: 'Sunset',
      latitude: beach.latitude,
      longitude: beach.longitude,
      place: beach,
      capturedAt: DateTime(2026, 8, 4, 17),
    );
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await book.close();
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  final sampleStamp = CategoryStamp(
    categoryKey: 'cafe',
    tier: 1,
    title: 'Kape lover',
    visits: 3,
    places: 2,
    firstVisitDate: DateTime(2026, 8, 1),
    firstVisitPlaceName: 'Kape ni Juan',
    placeVisits: [
      PlaceVisitCount(
        placeId: 'p1',
        placeName: 'Kape ni Juan',
        visits: 2,
        firstVisit: DateTime(2026, 8, 1),
      ),
    ],
  );

  final screens = <String, Widget Function(WarangRepository)>{
    'first run': (_) => const OnboardingScreen(),
    'map': (_) => const AppShell(),
    'trips shelf': (_) => const HomeTabScreen(),
    'trip detail': (repository) =>
        TripDetailScreen(tripId: repository.everyday.id),
    'trip form': (_) => const TripFormScreen(),
    'search': (_) => const SearchTabScreen(),
    'news': (_) => NewsTabScreen(entries: Future.value(const [])),
    'settings': (_) => const SettingsScreen(),
    'about': (_) => const AboutScreen(),
    'capture': (_) =>
        CaptureScreen(initialPhoto: XFile('missing.jpg'), fetchLocation: false),
    'place search sheet': (_) => const Scaffold(
      body: PlacePickerSheet(allowUserPlace: false, showNearbyWhenEmpty: false),
    ),
    'place picker sheet': (repo) => Scaffold(
      body: PlacePickerSheet(
        allowUserPlace: true,
        showNearbyWhenEmpty: true,
        userPlaces: repo.places,
      ),
    ),
    'you sheet stamps': (repo) => Scaffold(
      body: YouSheet(repository: repo, onSettings: () {}, onAbout: () {}),
    ),
    'stamp page sheet': (_) => Scaffold(
      body: StampPageSheet(
        stamp: sampleStamp,
        category: PlaceCategories.cafe,
        onSelectPlace: (_) {},
      ),
    ),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    testWidgets('$name settles still under reduced motion', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            mapTileStoreProvider.overrideWithValue(tileStore),
            placeBookProvider.overrideWith(() => _ReadyBook(book)),
          ],
          child: MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: build(repository),
          ),
        ),
      );
      for (var index = 0; index < 6; index++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      // The map's credit folds after five seconds; then all is still.
      await tester.pump(const Duration(seconds: 6));
      // One more frame lets anything that just ended draw its last state.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Nothing is left scaled, mid-press or mid-pop; cards and stamps keep
      // only their fixed tilt.
      for (final transform in tester.widgetList<Transform>(
        find.byType(Transform),
      )) {
        // Zero is the Scaffold's empty floating-button slot, at rest.
        final scale = transform.transform.getColumn(0).xy.length;
        expect(scale == 0 || (scale - 1).abs() < .001, isTrue, reason: name);
      }
      // And nothing repeats: no animation asks for another frame.
      expect(tester.binding.hasScheduledFrame, isFalse, reason: name);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
