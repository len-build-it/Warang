import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'data/db/database.dart';
import 'data/files/photo_store.dart';
import 'data/repository.dart';
import 'features/map/map_tile_store.dart';

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
  await photoStore.sweepOrphans(database);
  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        mapTileStoreProvider.overrideWithValue(MapTileStore()),
      ],
      child: const WarangApp(),
    ),
  );
}
