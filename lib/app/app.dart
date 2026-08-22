import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'theme/tokens.dart';

final repositoryProvider = Provider<WarangRepository>(
  (ref) => throw UnimplementedError(),
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
