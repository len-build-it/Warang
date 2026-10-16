import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/shell/warang_drawer.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/map/warang_map.dart';
import 'package:warang/features/onboarding/onboarding_screen.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  testWidgets('unavailable backup is absent from settings', (tester) async {
    await tester.pumpWidget(_app(repository, const SettingsScreen()));

    expect(find.text('Back up everything'), findsNothing);
  });

  testWidgets('unavailable travelbook action is absent from the drawer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository,
        Scaffold(
          body: WarangDrawer(
            repository: repository,
            onSearch: () {},
            onSettings: () {},
            onAbout: () {},
          ),
        ),
      ),
    );

    expect(find.text('Backup & .travelbook'), findsNothing);
  });

  testWidgets('settings offers only working controls', (tester) async {
    await tester.pumpWidget(_app(repository, const SettingsScreen()));
    await tester.pump();

    expect(find.text('Clean up'), findsNothing);
    expect(find.text('Copy caption on share'), findsNothing);
    expect(find.text('Corner mark on images'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('settings profile row opens the name editor', (tester) async {
    await tester.runAsync(() => repository.setName('Len'));
    await tester.pumpWidget(_app(repository, const SettingsScreen()));
    await tester.pump();

    await tester.tap(find.text('Len'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your name'), findsOneWidget);
  });

  testWidgets('onboarding privacy note is accurate about map tiles', (
    tester,
  ) async {
    await tester.pumpWidget(_app(repository, const OnboardingScreen()));

    expect(find.textContaining('Nothing leaves it'), findsNothing);
    expect(
      find.textContaining('Map tiles are downloaded from OpenStreetMap.'),
      findsOneWidget,
    );
  });

  testWidgets('map has no layers menu', (tester) async {
    await tester.pumpWidget(
      _app(
        repository,
        Scaffold(
          body: WarangMapSurface(
            moments: const [],
            selectedId: null,
            palette: MapPalette.light,
            dark: false,
            onMomentTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Map layers'), findsNothing);
    expect(find.byIcon(Icons.layers_outlined), findsNothing);
  });

  testWidgets('moment card shows only actions that work', (tester) async {
    await tester.pumpWidget(
      _app(
        repository,
        Scaffold(
          body: MomentCard(
            moment: Moment(
              id: 'moment',
              tripId: repository.everyday.id,
              capturedAt: DateTime(2026),
              latitude: 11.55,
              longitude: 122,
            ),
            repository: repository,
            photoStore: PhotoStore(),
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Swipe for nearby moments'), findsNothing);
    expect(
      find.textContaining('11.550°N · 122.000°E', findRichText: true),
      findsOneWidget,
    );
  });
}

Widget _app(WarangRepository repository, Widget child) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: child),
);
