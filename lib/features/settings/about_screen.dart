import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../maya/maya_companion.dart';

/// About Warang (S12), opened from the You sheet.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 34),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackButton()),
              const SizedBox(height: 16),
              const Center(
                child: MayaCompanion(
                  size: 120,
                  place: MayaPlace.about,
                  pose: MayaPose.sitting,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Semantics(
                  header: true,
                  // One line always (V3): it shrinks to fit at large text.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Warang',
                      maxLines: 1,
                      style: WarangType.wordmark.copyWith(color: neutrals.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Version ${AboutScreen.version}',
                  style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Aklanon. To go out and explore.',
                  textAlign: TextAlign.center,
                  style: WarangType.hand.copyWith(color: neutrals.inkSoft),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Places and map © OpenStreetMap contributors.\n'
                  'Place data is available under the ODbL '
                  '(openstreetmap.org/copyright), built with tool/place_book.',
                  textAlign: TextAlign.center,
                  style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: WarangButton.quiet(
                  label: 'Licences',
                  expand: false,
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Warang',
                    applicationVersion: AboutScreen.version,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
