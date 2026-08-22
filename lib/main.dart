import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/db/database.dart';
import 'data/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final databaseDirectory = Directory(p.join(documents.path, 'warang'));
  await databaseDirectory.create(recursive: true);
  final database = WarangDatabase.open(
    File(p.join(databaseDirectory.path, 'warang.sqlite')),
  );
  final repository = WarangRepository(database);
  await repository.initialize();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        repositoryProvider.overrideWithValue(repository),
      ],
      child: const WarangApp(),
    ),
  );
}
