import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:warang/app/app.dart';
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
import 'package:warang/features/search/search_tab_screen.dart';
import 'package:warang/features/travel_mode/moment_edit_sheet.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

import 'support/place_book_fixture.dart';

class _FixedPlaceBookNotifier extends PlaceBookNotifier {
  _FixedPlaceBookNotifier(this._initial);
  final PlaceBookState _initial;

  @override
  PlaceBookState build() => _initial;
}

void main() {
  late Directory tempDir;
  late WarangDatabase db;
  late WarangRepository repo;
  late PlaceBook book;
  late File photo;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('warang_places_flow_');
    db = WarangDatabase.memory();
    repo = WarangRepository(
      db,
      photoStore: PhotoStore(documentsDirectory: tempDir),
    );
    await repo.initialize();
    book = await openFixturePlaceBook();
    photo = File(p.join(tempDir.path, 'sample.jpg'))
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 30)));
  });

  tearDown(() async {
    await book.close();
    repo.dispose();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget host(
    Widget home, {
    PlaceBookState? bookState,
    LocationReader? locate,
  }) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      placeBookProvider.overrideWith(
        () => _FixedPlaceBookNotifier(bookState ?? PlaceBookState.ready(book)),
      ),
      if (locate != null) locationReaderProvider.overrideWithValue(locate),
    ],
    child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: home),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('Edit sheet place picker (REQ-012, REQ-013)', () {
    testWidgets(
      'reaches nearby, your places, place book, own place, and no place',
      (tester) async {
        phone(tester);
        // Seed an existing user place so "Your places" appears while typing.
        final other = await tester.runAsync(
          () => repo.addMoment(placeLabel: 'Kape Tambayan'),
        );
        expect(other, isNotNull);

        final moment = (await tester.runAsync(
          () => repo.addMoment(
            caption: 'Morning',
            latitude: 11.7086,
            longitude: 122.3643,
          ),
        ))!;

        await tester.pumpWidget(
          host(
            Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showMomentEditSheet(
                    context,
                    moment: repo.moments.firstWhere((m) => m.id == moment.id),
                    repository: repo,
                  ),
                  child: const Text('Open edit'),
                ),
              ),
            ),
          ),
        );

        // 1. Pick from Nearby.
        await tester.tap(find.text('Open edit'));
        await settle(tester);
        await tester.tap(find.text('Add a place'));
        await settle(tester);
        expect(find.text('Nearby'), findsOneWidget);
        expect(find.text('Kape ni Juan'), findsOneWidget);
        await tester.tap(find.text('Kape ni Juan'));
        await settle(tester);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settle(tester);
        expect(
          repo.moments.firstWhere((m) => m.id == moment.id).placeLabel,
          'Kape ni Juan',
        );
        expect(
          repo.moments.firstWhere((m) => m.id == moment.id).placeCategory,
          'cafe',
        );

        // 2. Typing shows Your places, Places, and Use as your own place.
        await tester.tap(find.text('Open edit'));
        await settle(tester);
        await tester.tap(find.text('Kape ni Juan'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).last, 'Kape');
        await settle(tester);
        expect(find.text('Your places'), findsOneWidget);
        expect(find.text('Kape Tambayan'), findsOneWidget);
        expect(find.text('Places'), findsOneWidget);
        expect(find.text('Use "Kape" as your own place'), findsOneWidget);
        await tester.tap(find.text('Kape Tambayan'));
        await settle(tester);
        // Set category to Cafe (REQ-013) and verify it applies to `other` too.
        await tester.ensureVisible(find.widgetWithText(WarangChip, 'Cafe'));
        await tester.tap(find.widgetWithText(WarangChip, 'Cafe'));
        await settle(tester);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settle(tester);
        expect(
          repo.moments.firstWhere((m) => m.id == other!.id).placeCategory,
          'cafe',
        );

        // 3. No place clears it.
        await tester.tap(find.text('Open edit'));
        await settle(tester);
        await tester.tap(find.text('Kape Tambayan'));
        await settle(tester);
        await tester.tap(find.text('No place'));
        await settle(tester);
        await tester.tap(find.text('Save'));
        await settle(tester);
        expect(
          repo.moments.firstWhere((m) => m.id == moment.id).placeId,
          isNull,
        );
      },
    );
  });

  group('Capture nearby suggestion (REQ-014, REQ-015)', () {
    testWidgets('shows chip near cafe; saving without tap saves no place', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          CaptureScreen(initialPhoto: XFile(photo.path)),
          locate: () async => const LocationFix(
            latitude: 11.7086,
            longitude: 122.3643,
            accuracyM: 20,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('At Kape ni Juan?'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        for (var i = 0; i < 40 && repo.moments.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      expect(repo.moments.single.placeId, isNull);
    });

    testWidgets('tapping chip accepts place and saves it', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          CaptureScreen(initialPhoto: XFile(photo.path)),
          locate: () async => const LocationFix(
            latitude: 11.7086,
            longitude: 122.3643,
            accuracyM: 20,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('At Kape ni Juan?'));
      await tester.pump();

      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        for (var i = 0; i < 40 && repo.moments.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      expect(repo.moments.single.placeLabel, 'Kape ni Juan');
      expect(repo.moments.single.placeCategory, 'cafe');
    });

    testWidgets(
      'no fix shows no chip and failed place book still saves in one tap',
      (tester) async {
        await tester.pumpWidget(
          host(
            CaptureScreen(initialPhoto: XFile(photo.path)),
            bookState: const PlaceBookState.failed('unavailable'),
            locate: () async => null,
          ),
        );
        await settle(tester);
        expect(find.textContaining('At '), findsNothing);

        await tester.runAsync(() async {
          await tester.tap(find.text('Save'));
          for (var i = 0; i < 40 && repo.moments.isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        expect(repo.moments, hasLength(1));
      },
    );
  });

  group('MomentCard and Search category display (REQ-019, REQ-021)', () {
    testWidgets(
      'MomentCard shows CategoryDisc and place name; search finds by category',
      (tester) async {
        final results = await tester.runAsync(
          () => book.search('Kape ni Juan'),
        );
        final cafe = results!.first;
        final moment = (await tester.runAsync(
          () => repo.addMoment(
            latitude: cafe.latitude,
            longitude: cafe.longitude,
            place: cafe,
          ),
        ))!;

        await tester.pumpWidget(
          host(
            Scaffold(
              body: MomentCard(
                moment: moment,
                repository: repo,
                photoStore: repo.photoStore,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CategoryDisc), findsOneWidget);
        final disc = tester.widget<CategoryDisc>(find.byType(CategoryDisc));
        expect(disc.category, PlaceCategories.cafe);
        expect(find.text('Kape ni Juan'), findsAtLeastNWidgets(1));

        // REQ-021: searching "cafe" finds a moment with no caption.
        await tester.pumpWidget(
          host(
            Scaffold(
              body: MomentSearchResults(
                repository: repo,
                photoStore: repo.photoStore,
                query: 'cafe',
                onSelected: (_) {},
              ),
            ),
          ),
        );
        await settle(tester);
        expect(find.text('Kape ni Juan'), findsOneWidget);
        expect(find.byType(CategoryDisc), findsOneWidget);
      },
    );
  });
}
