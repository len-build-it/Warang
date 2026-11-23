// FEAT-003 Phase 6 visual review (P-1): layout regressions on the map,
// moment card, capture, edit sheet, and placement, through the real screens.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/app_state.dart';
import 'package:warang/app/device_providers.dart';
import 'package:warang/app/shell/app_shell.dart';
import 'package:warang/app/shell/dock.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

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
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() async {
    await tileStore.close();
    repository.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 8; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<Moment> add(
    WidgetTester tester, {
    double? latitude = 11.9686,
    double? longitude = 121.918,
  }) async => (await tester.runAsync(
    () => repository.addMoment(
      caption: 'Sunset',
      latitude: latitude,
      longitude: longitude,
    ),
  ))!;

  Future<ProviderContainer> open(
    WidgetTester tester, {
    Widget home = const AppShell(),
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          mapTileStoreProvider.overrideWithValue(tileStore),
          locationReaderProvider.overrideWithValue(
            () async =>
                const LocationFix(latitude: 11.9686, longitude: 121.918),
          ),
        ],
        child: MaterialApp(theme: buildWarangTheme(brightness), home: home),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byWidget(home)));
  }

  final selectedPin = find.byWidgetPredicate(
    (widget) => widget is WarangPhotoPin && widget.selected,
  );

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    for (final focus in [true, false]) {
      testWidgets('the selected pin is clear of the card ($size, $focus)', (
        tester,
      ) async {
        final moment = await add(tester);
        final container = await open(tester, size: size);
        container
            .read(selectedMomentProvider.notifier)
            .select(moment, focus: focus);
        await settle(tester);
        final pin = tester.getRect(selectedPin);
        final card = tester.getRect(find.byType(MomentCard));
        expect(pin.top, greaterThanOrEqualTo(48));
        expect(pin.bottom, lessThanOrEqualTo(card.top));
        // Centred in the visible strip between the status bar and the card.
        expect(pin.center.dy, closeTo((48 + card.top) / 2, 2));
        expect(pin.center.dx, closeTo(size.width / 2, 2));
      });
    }
  }

  testWidgets('the pin stays clear at 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final moment = await add(tester);
    final container = await open(tester, size: const Size(360, 640));
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    final pin = tester.getRect(selectedPin);
    expect(pin.top, greaterThanOrEqualTo(48));
    expect(
      pin.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(MomentCard)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a pin already in view leaves the map alone', (
    tester,
  ) async {
    final moment = await add(tester);
    final container = await open(tester);
    final map = tester.state<WarangMapSurfaceState>(
      find.byType(WarangMapSurface),
    );
    // South of the pin at zoom 15, so the pin sits high on the screen.
    map.moveToCoordinate(11.9590, 121.918);
    await settle(tester);
    final before = map.center;
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    expect(map.center, before);
  });

  testWidgets('the pin stays clear when the screen size changes', (
    tester,
  ) async {
    final moment = await add(tester);
    final container = await open(tester);
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    tester.view.physicalSize = const Size(360, 640);
    await settle(tester);
    expect(
      tester.getRect(selectedPin).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(MomentCard)).top),
    );
  });

  testWidgets('the polaroid shares the buttons edges', (tester) async {
    final moment = await add(tester);
    final container = await open(tester);
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    final frame = tester.getRect(
      find
          .descendant(
            of: find.byType(WarangPolaroid),
            matching: find.byType(ClaySurface),
          )
          .first,
    );
    expect(frame.left, 20);
    expect(frame.right, 370);
    expect(
      tester.getRect(find.widgetWithText(WarangButton, 'Edit')).left,
      frame.left,
    );
    expect(
      tester.getRect(find.widgetWithText(WarangButton, 'Delete')).right,
      frame.right,
    );
  });

  testWidgets('the top of the Add location stamp takes taps', (tester) async {
    final moment = await add(tester, latitude: null, longitude: null);
    final container = await open(tester);
    container.read(selectedMomentProvider.notifier).select(moment);
    await settle(tester);
    final stamp = tester.getRect(find.byType(WarangStamp));
    await tester.tapAt(stamp.center - const Offset(0, 22));
    await settle(tester);
    expect(find.text('Move the map to the spot'), findsOneWidget);
  });

  testWidgets('Cancel and Confirm line up', (tester) async {
    final moment = await add(tester);
    final container = await open(tester);
    container.read(placingMomentProvider.notifier).start(moment.id);
    await settle(tester);
    final cancel = tester.getRect(find.widgetWithText(WarangButton, 'Cancel'));
    final confirm = tester.getRect(
      find.widgetWithText(WarangButton, 'Confirm'),
    );
    expect(cancel.height, 56);
    expect(confirm.height, 56);
    expect(cancel.top, confirm.top);
  });

  testWidgets('a pin pointer tip sits on the bottom of its box', (
    tester,
  ) async {
    await open(
      tester,
      home: const Scaffold(
        body: Row(
          children: [
            WarangPhotoPin(),
            WarangPhotoPin(selected: true),
            WarangClusterPin(count: 4),
          ],
        ),
      ),
    );
    for (final type in [WarangPhotoPin, WarangClusterPin]) {
      for (final element in find.byType(type).evaluate().toList()) {
        final pin = find.byWidget(element.widget);
        final square = find.descendant(
          of: pin,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints ==
                    const BoxConstraints.tightFor(width: 11, height: 11),
          ),
        );
        final box = tester.renderObject<RenderBox>(square);
        final centre = box.localToGlobal(box.size.center(Offset.zero)).dy;
        // A rotated square's tip, less what its 2.5 corner radius rounds off.
        final tip = centre + 5.5 * math.sqrt2 - 2.5 * (math.sqrt2 - 1);
        expect(tip, closeTo(tester.getRect(pin).bottom, .3), reason: '$type');
      }
    }
  });

  testWidgets('pins and clusters say what they open', (tester) async {
    final handle = tester.ensureSemantics();
    await add(tester);
    await open(tester);
    expect(find.bySemanticsLabel('Pin, Sunset'), findsOneWidget);
    await add(tester, latitude: 11.9687);
    await settle(tester);
    expect(find.bySemanticsLabel('2 moments, zoom in'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('pins regroup after the map zooms by itself', (tester) async {
    await add(tester);
    await add(tester, latitude: 11.9960);
    await open(tester);
    expect(find.byType(WarangClusterPin), findsOneWidget);
    tester
        .state<WarangMapSurfaceState>(find.byType(WarangMapSurface))
        .moveToCoordinate(11.9823, 121.918, 13);
    await settle(tester);
    expect(find.byType(WarangClusterPin), findsNothing);
    expect(find.byType(WarangPhotoPin), findsNWidgets(2));
  });

  testWidgets('the dock highlight is centred on the selected icon', (
    tester,
  ) async {
    await open(tester);
    final icon = tester.getCenter(
      find.descendant(
        of: find.byType(WarangDock),
        matching: find.byWidgetPredicate(
          (widget) => widget is WarangIcon && widget.selected,
        ),
      ),
    );
    final blob = tester.getCenter(
      find.descendant(
        of: find.byType(WarangDock),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints ==
                  const BoxConstraints.tightFor(width: 52, height: 34),
        ),
      ),
    );
    expect((icon - blob).distance, lessThan(.5));
  });

  testWidgets('recenter shares the avatar margin, 16 above the dock', (
    tester,
  ) async {
    await open(tester);
    final disc = tester.getRect(
      find.descendant(
        of: find.byTooltip('Recenter'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 40 && widget.height == 40,
        ),
      ),
    );
    expect(390 - disc.right, 16);
    expect(844 - 34 - 8 - 72 - disc.bottom, 16);
  });

  testWidgets('the empty-map bubble clears recenter and capture', (
    tester,
  ) async {
    await open(tester);
    final bubble = tester.getRect(
      find.descendant(
        of: find.byType(WarangSpeechBubble),
        matching: find.byType(ClaySurface),
      ),
    );
    for (final control in [
      find.byTooltip('Recenter'),
      find.byType(WarangCaptureButton),
    ]) {
      expect(bubble.overlaps(tester.getRect(control.first)), isFalse);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('the top shade only fades (${brightness.name})', (
      tester,
    ) async {
      final moment = await add(tester);
      final container = await open(tester, brightness: brightness);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(WarangTopScrim),
          matching: find.byType(DecoratedBox),
        ),
      );
      final colors = (box.decoration as BoxDecoration).gradient!.colors;
      expect(colors.first.a, greaterThan(0));
      expect(colors.last.a, 0);
      // Fading to transparent black instead is what drew the grey stripe.
      expect(
        colors.last.withValues(alpha: 1),
        colors.first.withValues(alpha: 1),
      );

      container.read(selectedMomentProvider.notifier).select(moment);
      await settle(tester);
      expect(find.byType(WarangTopScrim), findsNothing);
    });

    testWidgets('selected Everyday is not a solid (${brightness.name})', (
      tester,
    ) async {
      await open(
        tester,
        brightness: brightness,
        home: const Scaffold(
          body: Center(child: WarangChip(label: 'Everyday', selected: true)),
        ),
      );
      final neutrals = brightness == Brightness.dark
          ? WarangNeutrals.dark
          : WarangNeutrals.light;
      final clay = tester.widget<ClaySurface>(find.byType(ClaySurface));
      expect(clay.color, neutrals.surfaceRaised);
      expect(clay.outline?.color, neutrals.boundary);
      expect(clay.outline?.width, 2);
      expect(
        tester.widget<Text>(find.text('Everyday')).style?.color,
        neutrals.ink,
      );
    });
  }

  for (final (width, textScale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('capture labels its controls ($width, text $textScale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(
        tester,
        size: Size(width, 844),
        home: CaptureScreen(initialPhoto: XFile('missing.jpg')),
      );
      expect(find.widgetWithText(WarangField, 'Caption'), findsOneWidget);
      final retake = tester.getRect(
        find.widgetWithText(ClayPressable, 'Retake'),
      );
      final close = tester.getRect(find.widgetWithText(ClayPressable, 'Close'));
      expect(retake.overlaps(close), isFalse);
      expect(close.right, lessThanOrEqualTo(width - 16));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('three stamp lines get room inside the dashed ring', (
    tester,
  ) async {
    await open(
      tester,
      home: const Center(
        child: WarangStamp.place(
          id: 'three',
          lines: ['11.969°N', '121.918°E', '10:45 pm'],
          tone: WarangKeepsake.dagat,
        ),
      ),
    );
    expect(tester.getSize(find.byType(WarangStamp)), const Size(120, 80));
  });
}
