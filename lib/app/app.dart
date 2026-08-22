import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/daos.dart';
import '../data/db/database.dart';
import '../data/repository.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'theme/tokens.dart';

final databaseProvider = Provider<WarangDatabase>(
  (ref) => throw UnimplementedError(),
);

final repositoryProvider = Provider<WarangRepository>(
  (ref) => throw UnimplementedError(),
);

final profilesDaoProvider = Provider<ProfilesDao>(
  (ref) => ref.watch(databaseProvider).profilesDao,
);

final tripsDaoProvider = Provider<TripsDao>(
  (ref) => ref.watch(databaseProvider).tripsDao,
);

final momentsDaoProvider = Provider<MomentsDao>(
  (ref) => ref.watch(databaseProvider).momentsDao,
);

final photosDaoProvider = Provider<PhotosDao>(
  (ref) => ref.watch(databaseProvider).photosDao,
);

class WarangApp extends ConsumerWidget {
  const WarangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    return MaterialApp(
      title: 'Warang',
      debugShowCheckedModeBanner: false,
      theme: buildWarangTheme(Brightness.light),
      darkTheme: buildWarangTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AnimatedBuilder(
        animation: repository,
        builder: (context, _) => repository.profile.name.isEmpty
            ? const OnboardingScreen()
            : const HomeScreen(),
      ),
    );
  }
}
