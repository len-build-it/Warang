// Two map bugs older than FEAT-003, through the real shell: clusters that
// never split, and the OpenStreetMap credit hidden under the dock.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/dock.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

const _latitude = 11.9686;
const _longitude = 121.918;

/// About one metre of latitude.
const _metre = 1 / 110600;

/// Serves a valid blank tile, so a sweep through many zooms does not depend
/// on the network or on tiles finishing after they have left the screen.
class _BlankTiles extends MapTileStore {
  _BlankTiles() : super(databasePath: sqflite.inMemoryDatabasePath);

  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNgYGBgAAAABQABeqhXUAAAAABJRU5ErkJggg==',
  );

  @override
  Future<MapTileRecord?> get({
    required int z,
    required int x,
    required int y,
    required String layerId,
  }) async => MapTileRecord(
    z: z,
    x: x,
    y: y,
    layerId: layerId,
    bytes: _png,
    fetchedAt: DateTime.now(),
  );
}

/// The real fonts, because the credit's height decides what it can cover.
Future<void> _loadFonts() async {
  for (final (family, files) in [
    (
      WarangType.textFamily,
      ['AtkinsonHyperlegibleNext-Regular', 'AtkinsonHyperlegibleNext-SemiBold'],
    ),
    (WarangType.handFamily, ['ShantellSans-Medium']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late MapTileStore tileStore;

  setUpAll(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    await _loadFonts();
  });

  setUp(() async {
    WarangStamp.resetSession();
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    await repository.setName('Len');
    tileStore = _BlankTiles();
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> addNorth(WidgetTester tester, List<double> metres) =>
      tester.runAsync(() async {
        for (final north in metres) {
          await repository.addMoment(
            caption: 'North $north',
            latitude: _latitude + north * _metre,
            longitude: _longitude,
          );
        }
      });

  Future<WarangMapSurfaceState> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          mapTileStoreProvider.overrideWithValue(tileStore),
        ],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const AppShell(),
        ),
      ),
    );
    await settle(tester);
    return tester.state<WarangMapSurfaceState>(find.byType(WarangMapSurface));
  }

  group('clusters', () {
    for (final (apart, zoom) in [(2000.0, 14.0), (400.0, 16.0), (60.0, 18.0)]) {
      testWidgets('$apart m apart stand alone at zoom $zoom', (tester) async {
        await addNorth(tester, [0, apart]);
        final map = await open(tester);
        map.moveToCoordinate(_latitude + apart / 2 * _metre, _longitude, zoom);
        await settle(tester);
        expect(find.byType(WarangClusterPin), findsNothing);
        expect(find.byType(WarangPhotoPin), findsNWidgets(2));
      });
    }

    testWidgets('tapping a cluster zooms until its pins come apart', (
      tester,
    ) async {
      await addNorth(tester, [0, 400]);
      final map = await open(tester);
      map.moveToCoordinate(_latitude + 200 * _metre, _longitude, 10);
      await settle(tester);
      for (var taps = 0; taps < 5; taps++) {
        if (find.byType(WarangClusterPin).evaluate().isEmpty) break;
        await tester.tap(find.byType(WarangClusterPin));
        await settle(tester);
      }
      expect(find.byType(WarangClusterPin), findsNothing);
      expect(find.byType(WarangPhotoPin), findsNWidgets(2));
    });

    testWidgets('pins never overlap at any zoom', (tester) async {
      await addNorth(tester, [
        for (var index = 0; index < 24; index++) index * index * 7.0,
      ]);
      final map = await open(tester);
      for (var zoom = 5.0; zoom <= 18; zoom += .5) {
        map.moveToCoordinate(_latitude + 600 * _metre, _longitude, zoom);
        await tester.pump();
        await tester.pump();
        final centres = [
          for (final type in [WarangPhotoPin, WarangClusterPin])
            for (final element in find.byType(type).evaluate())
              tester
                  .getRect(
                    find.byElementPredicate(
                      (candidate) => candidate == element,
                    ),
                  )
                  .bottomCenter,
        ];
        for (var a = 0; a < centres.length; a++) {
          for (var b = a + 1; b < centres.length; b++) {
            expect(
              (centres[a] - centres[b]).distance,
              greaterThanOrEqualTo(WarangPhotoPin.size),
              reason: 'zoom $zoom',
            );
          }
        }
      }
      await settle(tester);
    });

    testWidgets('moments on the same spot stay one cluster', (tester) async {
      await addNorth(tester, [0, 0]);
      final map = await open(tester);
      map.moveToCoordinate(_latitude, _longitude, 18);
      await settle(tester);
      expect(find.byType(WarangClusterPin), findsOneWidget);
    });
  });

  group('placement', () {
    testWidgets('only the centre pin stands for the moment being placed', (
      tester,
    ) async {
      await addNorth(tester, [0]);
      await open(tester);
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(placingMomentProvider.notifier)
          .start(repository.moments.single.id);
      await settle(tester);
      expect(find.byType(WarangPhotoPin), findsOneWidget);
    });

    testWidgets('a tap on another pin does not open it', (tester) async {
      await addNorth(tester, [0, 500]);
      final map = await open(tester);
      final placed = repository.moments.firstWhere(
        (moment) => moment.caption == 'North 0.0',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      container.read(placingMomentProvider.notifier).start(placed.id);
      map.moveToCoordinate(_latitude, _longitude, 15);
      await settle(tester);
      // The other pin is about 108 above the centre of the screen.
      await tester.tapAt(const Offset(195, 422 - 108 - 30));
      await settle(tester);
      expect(container.read(selectedMomentProvider), isNull);
    });
  });

  group('map credit', () {
    final credit = find.textContaining('© OpenStreetMap contributors');
    final button = find.byTooltip('Map credits');

    for (final (size, textScale, filled) in [
      (const Size(390, 844), 1.0, false),
      (const Size(390, 844), 1.0, true),
      (const Size(320, 640), 2.0, false),
      (const Size(1000, 700), 1.0, false),
      (const Size(780, 360), 1.0, false),
    ]) {
      testWidgets('shows unasked and clear ($size, $textScale, $filled)', (
        tester,
      ) async {
        if (filled) await addNorth(tester, [0]);
        await open(tester, size: size, textScale: textScale);
        expect(credit, findsOneWidget);
        expect(find.textContaining('Open Database License'), findsOneWidget);
        expect(
          find.textContaining('openstreetmap.org/copyright'),
          findsOneWidget,
        );
        expect(button.hitTestable(), findsOneWidget);

        final card = tester.getRect(
          find.ancestor(of: credit, matching: find.byType(ClaySurface)).first,
        );
        final others = [
          find.byTooltip('You'),
          find.byTooltip('Recenter'),
          button,
          find.byType(WarangCaptureButton),
          if (!filled && size.height >= 500)
            find.descendant(
              of: find.byType(WarangSpeechBubble),
              matching: find.byType(ClaySurface),
            ),
        ];
        for (final other in others) {
          expect(
            card.overlaps(tester.getRect(other)),
            isFalse,
            reason: '$other',
          );
        }
        final control = tester.getRect(button);
        expect(
          control.overlaps(tester.getRect(find.byTooltip('Recenter'))),
          isFalse,
        );
        if (size.width < WarangLayout.railBreakpoint) {
          final dockTop = size.height - 34 - 8 - WarangLayout.dockHeight;
          expect(find.byType(WarangDock), findsOneWidget);
          expect(control.bottom, lessThanOrEqualTo(dockTop));
          expect(card.bottom, lessThanOrEqualTo(dockTop));
        }
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        expect(card.top, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('folds after five seconds and reopens from its button', (
      tester,
    ) async {
      await open(tester);
      expect(credit, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(credit, findsNothing);
      await tester.tap(button);
      await settle(tester);
      expect(credit, findsOneWidget);
      await tester.tap(button);
      await settle(tester);
      expect(credit, findsNothing);
    });

    testWidgets('the button mirrors recenter', (tester) async {
      await open(tester);
      final left = tester.getRect(button);
      final right = tester.getRect(find.byTooltip('Recenter'));
      expect(left.top, right.top);
      expect(left.left, 390 - right.right);
    });
  });
}
