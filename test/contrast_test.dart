// FEAT-003 REQ-002 and REQ-003: WCAG 2.2 AA contrast for the V1 neutrals.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/tokens.dart';

/// WCAG 2.x relative luminance, computed from sRGB channels.
double _luminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('luminance matches the WCAG reference values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(
      contrast(const Color(0xFF767676), Colors.white),
      closeTo(4.54, 0.01),
    );
  });

  for (final brightness in Brightness.values) {
    group('V1 neutrals ${brightness.name}', () {
      final theme = buildWarangTheme(brightness);
      final neutrals = theme.extension<WarangNeutrals>()!;
      final backgrounds = {
        'ground': neutrals.ground,
        'surface': neutrals.surface,
        'surfaceRaised': neutrals.surfaceRaised,
      };
      final texts = {
        'ink': neutrals.ink,
        'inkSoft': neutrals.inkSoft,
        'inkFaint': neutrals.inkFaint,
        'accentText': WarangColors.accentText(brightness),
      };

      for (final text in texts.entries) {
        for (final background in backgrounds.entries) {
          test('${text.key} on ${background.key} is at least 4.5:1', () {
            expect(
              contrast(text.value, background.value),
              greaterThanOrEqualTo(4.5),
            );
          });
        }
      }

      for (final background in ['ground', 'surface']) {
        test('boundary on $background is at least 3:1', () {
          expect(
            contrast(neutrals.boundary, backgrounds[background]!),
            greaterThanOrEqualTo(3),
          );
        });
      }

      test('the theme wires the neutrals into Material roles', () {
        expect(theme.scaffoldBackgroundColor, neutrals.ground);
        expect(theme.colorScheme.surface, neutrals.surface);
        expect(theme.colorScheme.onSurface, neutrals.ink);
        expect(theme.colorScheme.outline, neutrals.boundary);
        expect(theme.colorScheme.outlineVariant, neutrals.hairline);
        expect(theme.inputDecorationTheme.hintStyle?.color, neutrals.inkFaint);
        final enabled = theme.inputDecorationTheme.enabledBorder!;
        expect(enabled.borderSide.color, neutrals.boundary);
      });
    });
  }
}
