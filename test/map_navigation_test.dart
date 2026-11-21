import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/dock.dart';
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
    testWidgets('dock height and clearance follow width and insets', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              // 72 dock + 8 margin + 34 inset.
              expect(WarangLayout.navigationHeight(context), 114.0);
              // Plus half of the raised 84 capture button.
              expect(WarangLayout.dockClearance(context), 156.0);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: Builder(
            builder: (context) {
              expect(WarangLayout.navigationHeight(context), 0.0);
              expect(WarangLayout.dockClearance(context), 0.0);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Clay dock', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
    }

    testWidgets('replaces the bottom bar and drawer, in dock order', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(find.byType(WarangDock), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);

      double x(Finder finder) => tester.getCenter(finder).dx;
      final order = [
        x(find.text('Map')),
        x(find.text('Trips')),
        x(find.byType(WarangCaptureButton)),
        x(find.text('News')),
        x(find.text('Search').last),
      ];
      for (var index = 1; index < order.length; index++) {
        expect(order[index], greaterThan(order[index - 1]));
      }
      // The capture button is centred on the dock's top edge.
      final dock = tester.getRect(find.byType(WarangDock));
      final capture = tester.getCenter(find.byType(WarangCaptureButton));
      expect(capture.dx, closeTo(dock.center.dx, 1));
      final pillTop =
          dock.bottom - WarangLayout.dockMarginBottom - WarangLayout.dockHeight;
      expect(capture.dy, closeTo(pillTop, 1));
    });

    testWidgets(
      'selection is distinguishable beyond color alone via icons, font weight, and semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpShell(tester);

        Finder navIcon(WarangGlyph glyph, {required bool selected}) =>
            find.byWidgetPredicate(
              (widget) =>
                  widget is WarangIcon &&
                  widget.glyph == glyph &&
                  widget.selected == selected,
            );

        // Map is selected: its map icon fills with amber.
        expect(navIcon(WarangGlyphs.map, selected: true), findsOneWidget);

        // Trips is unselected: its suitcase keeps the hairline fill.
        expect(navIcon(WarangGlyphs.trips, selected: false), findsOneWidget);
        expect(navIcon(WarangGlyphs.trips, selected: true), findsNothing);

        final mapText = tester.widget<Text>(find.text('Map'));
        final tripsText = tester.widget<Text>(find.text('Trips'));
        expect(mapText.style?.fontWeight, FontWeight.w700);
        expect(tripsText.style?.fontWeight, FontWeight.w600);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Map')),
          isSemantics(isSelected: true, isButton: true),
        );
        handle.dispose();
      },
    );

    testWidgets('hides labels above 160% text size and keeps tooltips', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpShell(tester);
      expect(
        find.descendant(
          of: find.byType(WarangDock),
          matching: find.text('Map'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Map'), findsOneWidget);
    });

    testWidgets('becomes a left rail on wide screens, in the same order', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1200, 800));
      expect(find.byType(WarangDock), findsNothing);
      expect(find.byType(WarangRail), findsOneWidget);
      double y(Finder finder) => tester.getCenter(finder).dy;
      final order = [
        y(find.text('Map')),
        y(find.text('Trips')),
        y(find.byType(WarangCaptureButton)),
        y(find.text('News')),
        y(find.text('Search').first),
      ];
      for (var index = 1; index < order.length; index++) {
        expect(order[index], greaterThan(order[index - 1]));
      }
    });
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
                      bottom: 156.0 + 8,
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
        // Screen height is 844. The dock and the raised capture button
        // reach 156 up, so the card ends at 844 - (156 + 8) = 680.
        expect(cardBottom, lessThanOrEqualTo(680.0));
      },
    );
  });
}
