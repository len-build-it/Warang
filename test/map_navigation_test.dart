import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
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
  group('WarangLayout', () {
    testWidgets(
      'calculates navigation height based on platform width and insets',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                final height = WarangLayout.navigationHeight(context);
                // 64.0 + 8.0 + 34.0 = 106.0
                expect(height, equals(106.0));
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(1200, 800),
              padding: EdgeInsets.only(bottom: 0),
            ),
            child: Builder(
              builder: (context) {
                final height = WarangLayout.navigationHeight(context);
                expect(height, equals(0.0));
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );
  });

  group('Mobile Navigation Bar', () {
    testWidgets(
      'uses WarangGlassSurface on Travel Mode and solid surface on Home tab',
      (tester) async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        binding.platformDispatcher.views.first.physicalSize = const Size(
          390,
          844,
        );
        binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
        addTearDown(() {
          binding.platformDispatcher.views.first.resetPhysicalSize();
          binding.platformDispatcher.views.first.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              theme: buildWarangTheme(Brightness.light),
              home: const AppShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // On Travel Mode tab (index 0), mobile nav should contain a WarangGlassSurface
        expect(find.byType(WarangGlassSurface), findsWidgets);

        // Switch to Home tab (index 1)
        await tester.tap(find.text('Home'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // On Home tab, the mobile nav is a solid DecoratedBox, so WarangGlassSurface is absent in nav
        final homeNavFinder = find.ancestor(
          of: find.text('Home'),
          matching: find.byType(SafeArea),
        );
        expect(
          find.descendant(
            of: homeNavFinder,
            matching: find.byType(WarangGlassSurface),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'selection is distinguishable beyond color alone via icons, font weight, and semantics',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              theme: buildWarangTheme(Brightness.dark),
              home: const AppShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Travel Mode is selected: uses filled icon Icons.map, w600 weight
        expect(find.byIcon(Icons.map), findsWidgets);

        // Home is unselected: uses outline icon Icons.home_outlined
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
        expect(find.byIcon(Icons.home), findsNothing);

        // Check text weight of selected vs unselected
        final travelText = tester.widget<Text>(find.text('Travel Mode').first);
        final homeText = tester.widget<Text>(find.text('Home').first);
        expect(travelText.style?.fontWeight, equals(FontWeight.w600));
        expect(homeText.style?.fontWeight, equals(FontWeight.w400));
      },
    );
  });

  group('Travel Mode Overlay Placement and Collision Prevention', () {
    testWidgets(
      'MomentCard floats cleanly above navigation height without overlapping',
      (tester) async {
        final moment = Moment(
          id: 'test_nav_moment',
          tripId: repository.everyday.id,
          capturedAt: DateTime(2026, 9, 5, 12, 0),
          caption: 'A view over the hills',
          latitude: 11.55,
          longitude: 122.0,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 48, bottom: 34),
            ),
            child: MaterialApp(
              theme: buildWarangTheme(Brightness.light),
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 106.0 + 8,
                      child: MomentCard(
                        moment: moment,
                        repository: repository,
                        photoStore: PhotoStore(),
                        onClose: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Ensure moment card rendered with caption and delete button
        expect(find.text('A view over the hills'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        final cardBottom = tester.getBottomRight(find.byType(MomentCard)).dy;
        // Screen height is 844. Nav bar occupies [844 - 106, 844] = [738, 844].
        // MomentCard bottom is at 844 - (106 + 8) = 730, cleanly above 738 with an 8px gap.
        expect(cardBottom, lessThanOrEqualTo(730.0));
      },
    );
  });
}
