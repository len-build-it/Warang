import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warang/app/app.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/data/db/database.dart';
import 'package:warang/data/repository.dart';
import 'package:warang/features/settings/settings_screen.dart';
import 'package:warang/features/travel_mode/travel_mode_screen.dart';

void main() {
  late WarangDatabase database;
  late WarangRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = WarangDatabase.memory();
    repository = WarangRepository(database);
    await repository.initialize();
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  testWidgets('unavailable backup is absent from settings', (tester) async {
    await tester.pumpWidget(_app(repository, const SettingsScreen()));

    expect(find.text('Back up everything'), findsNothing);
  });

  testWidgets('unavailable travelbook action is absent from the drawer', (
    tester,
  ) async {
    await tester.pumpWidget(_app(repository, const TravelModeScreen()));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Backup & .travelbook'), findsNothing);
  });
}

Widget _app(WarangRepository repository, Widget child) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(theme: buildWarangTheme(Brightness.light), home: child),
);
