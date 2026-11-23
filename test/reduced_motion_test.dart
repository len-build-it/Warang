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
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
import 'package:warang/features/home_tab/trip_form_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/news_tab/news_tab_screen.dart';
import 'package:warang/features/onboarding/onboarding_screen.dart';
import 'package:warang/features/search/search_tab_screen.dart';
import 'package:warang/features/settings/about_screen.dart';
import 'package:warang/features/settings/settings_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;

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
    await repository.addMoment(
      caption: 'Sunset',
      latitude: 11.97,
      longitude: 121.92,
    );
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

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
