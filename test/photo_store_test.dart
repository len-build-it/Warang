import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:warang/core/ids.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/files/photo_store.dart';
import 'package:warang/data/repository.dart';

void main() {
  late Directory documents;
  late PhotoStore store;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('warang-photo-store-');
    store = PhotoStore(documentsDirectory: documents);
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  test(
    'imports a resized original and a 320px thumbnail at relative paths',
    () async {
      final source = File(p.join(documents.path, 'camera-output.png'))
        ..writeAsBytesSync(_imageBytes(width: 2400, height: 1200));

      final stored = await store.importPhotoAsset(
        source,
        now: DateTime(2026, 8),
      );

      expect(
        stored.relPath,
        matches(RegExp(r'^warang/photos/2026/08/[0-9a-f-]+\.jpg$')),
      );
      expect(stored.thumbRelPath, contains('/thumbs/'));
      for (final path in [stored.relPath, stored.thumbRelPath]) {
        expect(path, isNot(contains(':')));
        expect(path, isNot(startsWith('/')));
        expect(path, isNot(startsWith('\\')));
      }
      expect(stored.width, 2000);
      expect(stored.height, 1000);
      final fullImage = img.decodeImage(
        await (await store.resolve(stored.relPath)).readAsBytes(),
      );
      final thumbImage = img.decodeImage(
        await (await store.resolve(stored.thumbRelPath)).readAsBytes(),
      );
      expect(fullImage!.width, 2000);
      expect(thumbImage!.width, 320);
    },
  );

  test(
    'resolution remains relative when the documents directory changes',
    () async {
      final stored = await store.storeBytesAsset(
        Uint8List.fromList(_imageBytes(width: 400, height: 200)),
      );
      final otherDocuments = await Directory.systemTemp.createTemp(
        'warang-photo-store-other-',
      );
      addTearDown(() async {
        if (await otherDocuments.exists()) {
          await otherDocuments.delete(recursive: true);
        }
      });

      final resolved = await PhotoStore(
        documentsDirectory: otherDocuments,
      ).resolve(stored.relPath);

      expect(resolved.path, p.join(otherDocuments.path, stored.relPath));
      expect(resolved.path, isNot(contains(documents.path)));
    },
  );

  test(
    'orphan sweep removes unreferenced files and missing-file rows only',
    () async {
      final database = WarangDatabase.memory();
      final repository = WarangRepository(database, photoStore: store);
      await repository.initialize();
      try {
        final valid = await store.storeBytesAsset(
          Uint8List.fromList(_imageBytes(width: 640, height: 480)),
        );
        final moment = await repository.addMoment(
          relPath: valid.relPath,
          thumbRelPath: valid.thumbRelPath,
          width: valid.width,
          height: valid.height,
          bytes: valid.bytes,
        );
        final unreferenced = await store.storeBytesAsset(
          Uint8List.fromList(_imageBytes(width: 640, height: 480)),
        );
        final missingMoment = await repository.addMoment();
        await database.photosDao.insertPhoto(
          PhotosCompanion.insert(
            id: newId(),
            momentId: missingMoment.id,
            relPath: 'warang/photos/2026/08/missing.jpg',
            thumbRelPath: 'warang/photos/2026/08/thumbs/missing.jpg',
            width: 1,
            height: 1,
            bytes: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final result = await store.sweepOrphans(database);

        expect(result.deletedFiles, 2);
        expect(result.softDeletedRows, 1);
        expect(await (await store.resolve(valid.relPath)).exists(), isTrue);
        expect(
          await (await store.resolve(valid.thumbRelPath)).exists(),
          isTrue,
        );
        expect(
          await (await store.resolve(unreferenced.relPath)).exists(),
          isFalse,
        );
        expect(
          await (await store.resolve(unreferenced.thumbRelPath)).exists(),
          isFalse,
        );
        expect(await database.photosDao.firstForMoment(moment.id), isNotNull);
        expect(
          await database.photosDao.firstForMoment(missingMoment.id),
          isNull,
        );
      } finally {
        repository.dispose();
        await database.close();
      }
    },
  );
}

List<int> _imageBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(224, 160, 32));
  return img.encodePng(image);
}
