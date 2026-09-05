import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/home_tab/home_tab_screen.dart';
import 'package:warang/features/home_tab/trip_detail_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;
  late Directory tempDir;
  late PhotoStore photoStore;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
    tempDir = Directory.systemTemp.createTempSync('warang_tactile_test_');
    photoStore = PhotoStore(documentsDirectory: tempDir);
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets(
    'MomentCard frames photo with restrained matting and readable metadata badge',
    (tester) async {
      final moment = Moment(
        id: 'moment_1',
        tripId: repository.everyday.id,
        capturedAt: DateTime(2026, 4, 15, 17, 30),
        placeLabel: 'White Beach',
        caption: 'Golden hour by the shore.',
      );

      await tester.pumpWidget(
        _app(
          repository,
          Scaffold(
            body: SingleChildScrollView(
              child: MomentCard(
                moment: moment,
                repository: repository,
                photoStore: photoStore,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify restrained printed photograph frame (12px rounded corner, 7px padding)
      final photoFrameFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding == const EdgeInsets.all(7) &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(12),
      );
      expect(photoFrameFinder, findsOneWidget);

      // Verify readable metadata area containing uppercase place and formatted timestamp
      expect(
        find.textContaining('WHITE BEACH', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('15 APR 2026', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('5:30 PM', findRichText: true),
        findsOneWidget,
      );

      // Verify caption
      expect(find.text('Golden hour by the shore.'), findsOneWidget);

      // Verify actions: Delete present, Share/Edit absent
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Edit'), findsNothing);
    },
  );

  testWidgets(
    'TripDetailScreen renders cover photo and moment thumbnails with plain dash',
    (tester) async {
      final photoFile = File('${tempDir.path}/test_cover.png');
      photoFile.writeAsBytesSync([1, 2, 3]);

      final trip = Trip(
        id: 'trip_1',
        title: 'Batanes Adventure',
        place: 'Basco',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 5),
      );

      final momentWithPhoto = Moment(
        id: 'm1',
        tripId: trip.id,
        capturedAt: DateTime(2026, 3, 2, 10, 15),
        caption: 'Lighthouse on the hill',
        relPath: 'test_cover.png',
      );

      await tester.pumpWidget(
        _app(
          repository,
          TripDetailScreen(
            trip: trip,
            moments: [momentWithPhoto],
            photoStore: photoStore,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify trip details
      expect(find.text('Batanes Adventure'), findsOneWidget);
      expect(find.text('Basco'), findsOneWidget);
      expect(find.text('Lighthouse on the hill'), findsOneWidget);

      // Verify date range uses plain dash '-' and NOT en dash
      expect(
        find.textContaining('01 MAR 2026 - 05 MAR 2026', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('\u2013', findRichText: true), findsNothing);

      // Verify cover image attempted to render via Image widget
      expect(find.byType(Image), findsAtLeastNWidgets(1));

      // Test with an empty trip without moments
      final emptyTrip = Trip(
        id: 'trip_empty',
        title: 'Empty Journey',
        startDate: DateTime(2026, 5, 1),
      );

      await tester.pumpWidget(
        _app(
          repository,
          TripDetailScreen(
            trip: emptyTrip,
            moments: const [],
            photoStore: photoStore,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fallback landscape icon is present
      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      expect(
        find.text('Your moments from this trip will appear here.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'HomeTabScreen displays journal covers with place tag and plain dashes',
    (tester) async {
      await tester.runAsync(() async {
        await repository.addTrip(
          'Cordillera Trek',
          'Sagada',
          DateTime(2026, 2, 10),
          DateTime(2026, 2, 14),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: buildWarangTheme(Brightness.light),
            home: const HomeTabScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify trip card rendered with title and place tag
      expect(find.text('Cordillera Trek'), findsOneWidget);
      expect(find.text('Sagada'), findsOneWidget);

      // Verify date range uses plain dash and no en dash
      expect(
        find.textContaining('FEB 10-14', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('\u2013', findRichText: true), findsNothing);

      // Verify stat cards (subordinated summaries) are present
      expect(find.text('MOMENTS'), findsOneWidget);
      expect(find.text('PLACES'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);

      // Tap trip card to verify navigation
      await tester.tap(find.text('Cordillera Trek'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TripDetailScreen), findsOneWidget);
    },
  );

  testWidgets('Long trip titles and captions wrap gracefully without overflow', (
    tester,
  ) async {
    const longCaption =
        'This is an exceptionally long moment caption describing the scenery, the atmosphere, the food, and every tactile impression from the entire journey across the islands.';
    final longMoment = Moment(
      id: 'm_long',
      tripId: repository.everyday.id,
      capturedAt: DateTime(2026, 1, 1),
      caption: longCaption,
    );

    await tester.pumpWidget(
      _app(
        repository,
        Scaffold(
          body: SingleChildScrollView(
            child: MomentCard(
              moment: longMoment,
              repository: repository,
              photoStore: photoStore,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(longCaption), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(WarangRepository repository, Widget child) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: child),
);
