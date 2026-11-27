import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:warang/app/app.dart';
import 'package:warang/app/device_providers.dart';
import 'package:warang/app/shell/you_sheet.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/core/models.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/places/place_book.dart';
import 'package:warang/data/places/place_book_installer.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/capture/capture_screen.dart';
import 'package:warang/features/maya/maya_companion.dart';
import 'package:warang/features/places/place_picker_sheet.dart';
import 'package:warang/features/search/search_tab_screen.dart';

import 'support/place_book_fixture.dart';

class _SlowSaveRepository extends WarangRepository {
  _SlowSaveRepository(
    super.database, {
    required super.photoStore,
    required this.gate,
  });

  final Completer<void> gate;

  @override
  Future<Moment> captureMoment({
    required File photo,
    String? caption,
    double? latitude,
    double? longitude,
    double? accuracyM,
    BookPlace? place,
    DateTime? capturedAt,
  }) async {
    await gate.future;
    throw const FileSystemException('Simulated save failure');
  }
}

class _FlakyAssetBundle extends AssetBundle {
  _FlakyAssetBundle(this.failOncePayload);

  final String failOncePayload;
  int attempts = 0;

  @override
  Future<ByteData> load(String key) async {
    attempts++;
    if (attempts == 1) {
      throw StateError('Transient asset error');
    }
    return ByteData.sublistView(Uint8List.fromList(failOncePayload.codeUnits));
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));
}

class _FixedPlaceBookNotifier extends PlaceBookNotifier {
  _FixedPlaceBookNotifier(this._initial);

  final PlaceBookState _initial;

  @override
  PlaceBookState build() => _initial;
}

List<int> _tinyPngBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(224, 160, 32));
  return img.encodePng(image);
}

void main() {
  testWidgets('AUD-005: CaptureScreen blocks system Back while saving', (
    tester,
  ) async {
    late WarangDatabase db;
    late Directory tempDir;
    late _SlowSaveRepository repo;
    late File photo;
    final gate = Completer<void>();

    await tester.runAsync(() async {
      db = WarangDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('warang_p4_back_');
      final store = PhotoStore(documentsDirectory: tempDir);
      repo = _SlowSaveRepository(db, photoStore: store, gate: gate);
      await repo.initialize();
      photo = File(p.join(tempDir.path, 'shot.png'))
        ..writeAsBytesSync(_tinyPngBytes());
    });
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CaptureScreen(
                      initialPhoto: XFile(photo.path),
                      fetchLocation: false,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CaptureScreen), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();

    // System Back while saving must not dismiss CaptureScreen.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CaptureScreen), findsOneWidget);

    // Let the save fail and confirm the screen stays mounted with retry feedback.
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(
      find.text("Couldn't save this photo. It's still here - try again."),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('AUD-006: editMomentDetails rolls back caption when place write fails', () async {
    final db = WarangDatabase.memory();
    final tempDir = await Directory.systemTemp.createTemp('warang_p4_txn_');
    final repo = WarangRepository(
      db,
      photoStore: PhotoStore(documentsDirectory: tempDir),
    );
    await repo.initialize();
    addTearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final moment = await repo.addMoment(caption: 'Original caption');

    await db.customStatement('''
      CREATE TRIGGER fail_place_insert BEFORE INSERT ON places
      BEGIN
        SELECT RAISE(ABORT, 'simulated place insert failure');
      END;
    ''');

    await expectLater(
      repo.editMomentDetails(
        moment.id,
        caption: 'Updated caption',
        userPlaceName: 'New Place',
        initialPlaceId: moment.placeId,
      ),
      throwsA(anything),
    );

    final rows = await db.momentsDao.getActive();
    final row = rows.firstWhere((m) => m.id == moment.id);
    expect(row.caption, 'Original caption');
  });

  test('AUD-008: corrupt milestonesShown JSON resets cleanly instead of throwing', () async {
    final db = WarangDatabase.memory();
    final tempDir = await Directory.systemTemp.createTemp('warang_p4_json_');
    final repo = WarangRepository(
      db,
      photoStore: PhotoStore(documentsDirectory: tempDir),
    );
    await repo.initialize();
    addTearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    await db.appMetaDao.writeValue(
      'milestonesShown',
      '{corrupt json',
      DateTime.now(),
    );
    final moment = await repo.addMoment(caption: 'First');
    final claimed = await repo.claimMilestone(moment, stampTitles: const {});
    expect(claimed, isNotEmpty);
  });

  testWidgets('AUD-009: repeated Maya drags settle back to Offset.zero cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWarangTheme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: MayaCompanion(
              size: 100,
              place: MayaPlace.about,
              pose: MayaPose.sitting,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final finder = find.byType(MayaCompanion);
    final gesture1 = await tester.startGesture(tester.getCenter(finder));
    await gesture1.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture1.up();
    await tester.pump(const Duration(milliseconds: 50));

    final gesture2 = await tester.startGesture(tester.getCenter(finder));
    await gesture2.moveBy(const Offset(-20, 10));
    await tester.pump();
    await gesture2.up();
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('AUD-010: MayaLines.load clears cached future after failure and retries', () async {
    MayaLines.reset();
    addTearDown(MayaLines.reset);

    final bundle = _FlakyAssetBundle('{"about": ["Hello!"]}');
    await expectLater(MayaLines.load(bundle), throwsStateError);
    final loaded = await MayaLines.load(bundle);
    expect(loaded['about'], ['Hello!']);
    expect(bundle.attempts, 2);
  });

  test('AUD-011: setAvatar removes superseded avatar and sweepOrphans cleans profile dir', () async {
    final db = WarangDatabase.memory();
    final tempDir = await Directory.systemTemp.createTemp('warang_p4_avatar_');
    final store = PhotoStore(documentsDirectory: tempDir);
    final repo = WarangRepository(db, photoStore: store);
    await repo.initialize();
    addTearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final src1 = File(p.join(tempDir.path, 'a1.png'))
      ..writeAsBytesSync(_tinyPngBytes());
    final src2 = File(p.join(tempDir.path, 'a2.png'))
      ..writeAsBytesSync(_tinyPngBytes());

    await repo.setAvatar(src1);
    final firstPath = repo.profile.avatarRelPath!;
    expect(await (await store.resolve(firstPath)).exists(), isTrue);

    await repo.setAvatar(src2);
    final secondPath = repo.profile.avatarRelPath!;
    expect(secondPath, isNot(firstPath));
    expect(await (await store.resolve(firstPath)).exists(), isFalse);
    expect(await (await store.resolve(secondPath)).exists(), isTrue);

    final orphan = File(p.join(tempDir.path, 'warang', 'profile', 'orphan.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final swept = await store.sweepOrphans(db);
    expect(swept.deletedFiles, 1);
    expect(await orphan.exists(), isFalse);
    expect(await (await store.resolve(secondPath)).exists(), isTrue);
  });

  testWidgets('AUD-014: PlacePickerSheet clears loading spinner when PlaceBook throws', (
    tester,
  ) async {
    late PlaceBook book;
    await tester.runAsync(() async {
      book = await openFixturePlaceBook();
      await book.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeBookProvider.overrideWith(
            () => _FixedPlaceBookNotifier(PlaceBookState.ready(book)),
          ),
        ],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: const Scaffold(
            body: PlacePickerSheet(
              near: LatLng(11.7086, 122.3643),
              showNearbyWhenEmpty: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AUD-016: MomentSearchResults refreshes when an existing moment is edited', (
    tester,
  ) async {
    late WarangDatabase db;
    late Directory tempDir;
    late PhotoStore store;
    late WarangRepository repo;
    late Moment moment;

    await tester.runAsync(() async {
      db = WarangDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('warang_p4_search_');
      store = PhotoStore(documentsDirectory: tempDir);
      repo = WarangRepository(db, photoStore: store);
      await repo.initialize();
      moment = await repo.addMoment(caption: 'Old morning walk');
    });
    addTearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final revisionBefore = repo.revision;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: repo,
              builder: (context, _) => MomentSearchResults(
                repository: repo,
                photoStore: store,
                query: 'Siquijor',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text('Nothing here yet, try another word'), findsOneWidget);

    await tester.runAsync(() async {
      await repo.updateMoment(
        moment.id,
        caption: 'Siquijor sunset',
        tripId: moment.tripId,
      );
    });
    expect(repo.revision, greaterThan(revisionBefore));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Siquijor sunset'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AUD-018: pickProfilePhoto shows error snackbar on corrupt image', (
    tester,
  ) async {
    late WarangDatabase db;
    late Directory tempDir;
    late WarangRepository repo;
    late File badFile;

    await tester.runAsync(() async {
      db = WarangDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('warang_p4_pick_');
      final store = PhotoStore(documentsDirectory: tempDir);
      repo = WarangRepository(db, photoStore: store);
      await repo.initialize();
      badFile = File(p.join(tempDir.path, 'corrupt.jpg'))
        ..writeAsBytesSync([0, 1, 2, 3, 4]);
    });
    addTearDown(() async {
      repo.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    late BuildContext capturedContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          galleryPickerProvider.overrideWithValue(
            () async => XFile(badFile.path),
          ),
        ],
        child: MaterialApp(
          theme: buildWarangTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() => pickProfilePhoto(capturedContext, repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("Couldn't update profile photo. Try again."),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
