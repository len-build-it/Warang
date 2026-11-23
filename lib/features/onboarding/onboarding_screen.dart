import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../maya/maya_companion.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The maya turns its head toward the name field while it has focus.
    _nameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    Future<void> start() async {
      await ref
          .read(repositoryProvider)
          .setName(
            _nameController.text.trim().isEmpty
                ? 'Explorer'
                : _nameController.text.trim(),
          );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 44, 32, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // S1: the maya on a 180 amber clay disc, floating 2 px.
                Center(
                  child: SizedBox.square(
                    dimension: 180,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        const ClayDisc(
                          diameter: 180,
                          tone: WarangKeepsake.amber,
                          depth: ClayDepth.clay2,
                        ),
                        MayaCompanion(
                          size: 160,
                          place: MayaPlace.firstRun,
                          float: true,
                          lookToward: _nameFocus.hasFocus,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Bagel Fat One is never more than one line (V3), so the
                // wordmark shrinks to fit rather than wrap.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Warang',
                    maxLines: 1,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'A map you fill with your own photographs.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: WarangNeutrals.of(context).inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                WarangField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  hintText: 'What should we call you?',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => start(),
                ),
                const SizedBox(height: 12),
                WarangButton.primary(label: 'Start', onPressed: start),
                const SizedBox(height: 26),
                Text(
                  'Warang asks for your camera to take photos and your location to place them on the map. Your name, photos and pins stay on this phone. Map tiles are downloaded from OpenStreetMap.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WarangNeutrals.of(context).inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
