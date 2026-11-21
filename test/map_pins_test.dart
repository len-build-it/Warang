// FEAT-003 Phase 6: C10 clay pins, the dimmer under an open moment, the
// new-pin landing (REQ-009), and pins leaving after a delete.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MarkerLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/features/map/map_tile_store.dart';
import 'package:warang/features/map/warang_map.dart';

void main() {
  late MapTileStore tileStore;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tileStore = MapTileStore(databasePath: sqflite.inMemoryDatabasePath);
  });

  tearDown(() => tileStore.close());

  Moment moment(String id, {double lat = 11.9686, double lng = 121.918}) =>
      Moment(
        id: id,
        tripId: 'everyday',
        capturedAt: DateTime(2026, 9, 1),
        latitude: lat,
        longitude: lng,
      );

  Widget map(
    List<Moment> moments, {
    String? selectedId,
    String? landingId,
    bool reduced = false,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: buildWarangTheme(brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduced,
      ),
      child: Builder(
        builder: (context) => WarangMapSurface(
          moments: moments,
          selectedId: selectedId,
          landingId: landingId,
          dimmed: selectedId != null,
          palette: MapPalette.light,
          dark: brightness == Brightness.dark,
          tileStore: tileStore,
          onMomentTap: (_) {},
        ),
      ),
    ),
  );

  Future<void> pumpMap(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  /// Vertical offsets of every translate under [finder].
  Iterable<double> lifts(WidgetTester tester, Finder finder) => tester
      .widgetList<Transform>(
        find.descendant(of: finder, matching: find.byType(Transform)),
      )
      .map((transform) => transform.transform.getTranslation().y);

  for (final brightness in Brightness.values) {
    testWidgets('pins are clay discs of the C10 sizes (${brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWarangTheme(brightness),
          home: const Scaffold(
            body: Row(
              children: [
                WarangPhotoPin(),
                WarangPhotoPin(selected: true),
                WarangClusterPin(count: 4),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(WarangPhotoPin).first).width, 58);
      expect(tester.getSize(find.byType(WarangPhotoPin).last).width, 70);
      expect(tester.getSize(find.byType(WarangClusterPin)).width, 54);
      // Each disc is a pre-painted image, so the map never paints live blurs.
      expect(find.byType(ClayDisc), findsNWidgets(3));
      expect(find.byType(RawImage), findsNWidgets(3));
      expect(find.text('4'), findsOneWidget);
      // Nothing tints or filters the photo inside a pin.
      expect(
        find.descendant(
          of: find.byType(WarangPhotoPin),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('a new pin drops in with motion when animations are on', (
    tester,
  ) async {
    await pumpMap(tester, map([moment('new')], landingId: 'new'));
    final landing = find.byType(LandingPin);
    expect(landing, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    expect(lifts(tester, landing).any((y) => y < -10), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(lifts(tester, landing).every((y) => y.abs() < 1), isTrue);
  });

  testWidgets('a new pin only fades in under reduced motion', (tester) async {
    await pumpMap(
      tester,
      map([moment('new')], landingId: 'new', reduced: true),
    );
    final landing = find.byType(LandingPin);
    expect(landing, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    expect(lifts(tester, landing).every((y) => y == 0), isTrue);
    expect(
      find.descendant(of: landing, matching: find.byType(Opacity)),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the selected pin grows above the dimmer', (tester) async {
    await pumpMap(
      tester,
      map([moment('a'), moment('b', lat: 12.5, lng: 122.5)], selectedId: 'a'),
    );
    await tester.pump(const Duration(seconds: 1));
    final dimmer = find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox &&
          widget.color == warangDimmer(Brightness.light),
    );
    expect(dimmer, findsOneWidget);
    expect(tester.getSize(dimmer), const Size(390, 844));
    final selected = find.byWidgetPredicate(
      (widget) => widget is WarangPhotoPin && widget.selected,
    );
    expect(selected, findsOneWidget);
    // The selected pin's layer comes after the dimmer, so it paints above.
    final layers = find.byType(MarkerLayer).evaluate().toList();
    expect(layers, hasLength(2));
    expect(
      find.descendant(
        of: find.byWidget(layers.last.widget),
        matching: selected,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a deleted pin pops away, and undo brings it back', (
    tester,
  ) async {
    final a = moment('a');
    await pumpMap(tester, map([a], selectedId: 'a'));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(map([]));
    await tester.pump();
    expect(find.byKey(const ValueKey('leave-a')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('leave-a')), findsNothing);

    // Undo restores the moment while its pin is leaving.
    await tester.pumpWidget(map([a], selectedId: 'a'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(map([]));
    await tester.pump();
    await tester.pumpWidget(map([a]));
    await tester.pump();
    expect(find.byKey(const ValueKey('return-a')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
