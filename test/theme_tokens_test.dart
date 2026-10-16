import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/tokens.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final light = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('buildWarangTheme ${brightness.name}', () {
      final theme = buildWarangTheme(brightness);
      final textTheme = theme.textTheme;
      final styles = <String, TextStyle?>{
        'displayLarge': textTheme.displayLarge,
        'displayMedium': textTheme.displayMedium,
        'displaySmall': textTheme.displaySmall,
        'headlineLarge': textTheme.headlineLarge,
        'headlineMedium': textTheme.headlineMedium,
        'headlineSmall': textTheme.headlineSmall,
        'titleLarge': textTheme.titleLarge,
        'titleMedium': textTheme.titleMedium,
        'titleSmall': textTheme.titleSmall,
        'bodyLarge': textTheme.bodyLarge,
        'bodyMedium': textTheme.bodyMedium,
        'bodySmall': textTheme.bodySmall,
        'labelLarge': textTheme.labelLarge,
        'labelMedium': textTheme.labelMedium,
        'labelSmall': textTheme.labelSmall,
      };

      test('every text style uses a bundled family', () {
        const bundled = {'Public Sans', 'Bricolage Grotesque', 'DM Mono'};
        for (final entry in styles.entries) {
          expect(
            bundled,
            contains(entry.value?.fontFamily),
            reason: '${entry.key} has no bundled font family',
          );
        }
      });

      test('body and label roles use Public Sans', () {
        for (final key in [
          'bodyLarge',
          'bodyMedium',
          'bodySmall',
          'labelLarge',
          'labelMedium',
          'labelSmall',
        ]) {
          expect(styles[key]?.fontFamily, 'Public Sans', reason: key);
        }
      });

      test('focused field labels use readable accent text', () {
        final style = theme.inputDecorationTheme.floatingLabelStyle;
        final focused = WidgetStateProperty.resolveAs<TextStyle?>(style, {
          WidgetState.focused,
        });
        expect(focused?.color, WarangColors.accentText(brightness));
        expect(
          _contrast(focused!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('dividers use the line token', () {
        expect(theme.colorScheme.outlineVariant, theme.colorScheme.outline);
      });

      test('text buttons use readable accent text', () {
        final foreground = theme.textButtonTheme.style?.foregroundColor
            ?.resolve(<WidgetState>{});
        expect(foreground, WarangColors.accentText(brightness));
        expect(
          _contrast(foreground!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('scrim darkens the map in both themes', () {
    final dark = WarangColors.scrim(Brightness.dark);
    final light = WarangColors.scrim(Brightness.light);
    expect(
      Color.alphaBlend(dark, WarangColors.darkGround).computeLuminance(),
      lessThan(WarangColors.darkGround.computeLuminance()),
    );
    expect(dark.withValues(alpha: 1).computeLuminance(), lessThan(0.1));
    expect(light.withValues(alpha: 1).computeLuminance(), lessThan(0.1));
  });
}
