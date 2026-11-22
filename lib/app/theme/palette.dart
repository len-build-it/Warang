import 'package:flutter/widgets.dart';

import '../../core/models.dart';
import '../../core/trip_rules.dart';

/// One keepsake colour from FEAT-003 V2, with its tints and text colours.
///
/// Labels on a solid [fill] are always `ink`, never white. Large areas use
/// [tint]; solid fills are only for small objects.
@immutable
class KeepsakeTone {
  const KeepsakeTone({
    required this.key,
    required this.fill,
    required this.lightTint,
    required this.lightText,
    required this.darkTint,
    required this.darkText,
    this.highlight,
    this.shade,
    this.shadow,
  });

  /// The stored name, for example `gumamela`.
  final String key;
  final Color fill;
  final Color lightTint;
  final Color lightText;
  final Color darkTint;
  final Color darkText;

  /// Explicit clay tones; when null they derive from [fill] (V5).
  final Color? highlight;
  final Color? shade;
  final Color? shadow;

  Color tint(Brightness brightness) =>
      brightness == Brightness.dark ? darkTint : lightTint;

  Color text(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : lightText;

  /// The fill lightened 25%, drawn at 60% as the clay highlight.
  Color get clayHighlight =>
      (highlight ?? _shift(fill, .25)).withValues(alpha: .60);

  /// The fill darkened 25%, drawn at 45% as the clay shade.
  Color get clayShade => (shade ?? _shift(fill, -.25)).withValues(alpha: .45);

  /// The fill darkened 45%, drawn at 30% as the outer clay shadow.
  Color get clayShadow => (shadow ?? _shift(fill, -.45)).withValues(alpha: .30);

  static Color _shift(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// The FEAT-003 V2 keepsake palette.
abstract final class WarangKeepsake {
  static const amber = KeepsakeTone(
    key: 'amber',
    fill: Color(0xFFE8A020),
    lightTint: Color(0xFFFBE7BE),
    lightText: Color(0xFF7F5C0F),
    darkTint: Color(0xFF3A2E15),
    darkText: Color(0xFFF2B84B),
    highlight: Color(0xFFFFD27A),
    shade: Color(0xFFB5770F),
    shadow: Color(0xFF8A5A10),
  );
  static const gumamela = KeepsakeTone(
    key: 'gumamela',
    fill: Color(0xFFE8664F),
    lightTint: Color(0xFFF9D3CB),
    lightText: Color(0xFFA63A26),
    darkTint: Color(0xFF3D211C),
    darkText: Color(0xFFF28A76),
  );
  static const dagat = KeepsakeTone(
    key: 'dagat',
    fill: Color(0xFF2FA7A0),
    lightTint: Color(0xFFC9EAE6),
    lightText: Color(0xFF1A6E69),
    darkTint: Color(0xFF16312F),
    darkText: Color(0xFF5CC7BF),
  );
  static const kalamansi = KeepsakeTone(
    key: 'kalamansi',
    fill: Color(0xFF86B83A),
    lightTint: Color(0xFFDDEDC4),
    lightText: Color(0xFF4D6E1C),
    darkTint: Color(0xFF25301A),
    darkText: Color(0xFFA6D163),
  );
  static const ube = KeepsakeTone(
    key: 'ube',
    fill: Color(0xFF9B7FD6),
    lightTint: Color(0xFFE3DAF5),
    lightText: Color(0xFF6A4BB0),
    darkTint: Color(0xFF2C2540),
    darkText: Color(0xFFB9A2EC),
  );
  static const langit = KeepsakeTone(
    key: 'langit',
    fill: Color(0xFF5A97DB),
    lightTint: Color(0xFFD4E4F7),
    lightText: Color(0xFF285E9C),
    darkTint: Color(0xFF1C2A3D),
    darkText: Color(0xFF86B6EC),
  );
  static const santan = KeepsakeTone(
    key: 'santan',
    fill: Color(0xFFF2909F),
    lightTint: Color(0xFFFBDDE1),
    lightText: Color(0xFFA8435A),
    darkTint: Color(0xFF3D2328),
    darkText: Color(0xFFF6A9B5),
  );

  static const all = [amber, gumamela, dagat, kalamansi, ube, langit, santan];

  /// The six trip colours, in assignment order (amber is never a trip).
  static const tripTones = [gumamela, dagat, kalamansi, ube, langit, santan];

  /// A trip's colour (FEAT-003 D-1), or null for Everyday, which is drawn
  /// neutral.
  static KeepsakeTone? forTrip(Trip trip) => byKey(tripColorKey(trip));

  /// The person's own colour (C3): their first trip's, or amber.
  static KeepsakeTone forUser(Iterable<Trip> trips) {
    final made = trips.where((trip) => !trip.isEveryday).toList()
      ..sort(
        (a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
    return made.isEmpty ? amber : forTrip(made.first) ?? amber;
  }

  static KeepsakeTone? byKey(String? key) {
    for (final tone in all) {
      if (tone.key == key) return tone;
    }
    return null;
  }
}
