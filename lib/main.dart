import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/db/database.dart';
import 'data/files/photo_store.dart';
import 'data/places/place_book_installer.dart';
import 'data/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final databaseDirectory = Directory(p.join(documents.path, 'warang'));
  await databaseDirectory.create(recursive: true);
  final database = WarangDatabase.open(
    File(p.join(databaseDirectory.path, 'warang.sqlite')),
  );
  final photoStore = PhotoStore(documentsDirectory: documents);
  final repository = WarangRepository(database, photoStore: photoStore);
  await repository.initialize();
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repository)],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const WarangApp()),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(photoStore.sweepOrphans(database));
    unawaited(container.read(placeBookProvider.notifier).ensureReady());
  });
}
