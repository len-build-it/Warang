import 'package:flutter/material.dart';

import 'components.dart' show WarangIcon;
import 'typography.dart';
import 'warang_icons.dart';

export 'typography.dart';

abstract final class WarangColors {
  static const accent = Color(0xFFE8A020);
  static const accentInk = Color(0xFF231F0E);

  // FEAT-003 V1 neutrals.
  static const lightGround = Color(0xFFF1EFE7);
  static const lightSurface = Color(0xFFFBFAF5);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF1A1D18);
  static const lightSoft = Color(0xFF4F544A);
  static const lightFaint = Color(0xFF646A5E);
  static const lightBoundary = Color(0xFF7E8475);
  static const lightLine = Color(0xFFE2DFD4);
  static const lightShadowTint = Color(0xFF5B4A2E);
  static const darkGround = Color(0xFF15130F);
  static const darkSurface = Color(0xFF221F19);
  static const darkSurfaceRaised = Color(0xFF2B2720);
  static const darkInk = Color(0xFFEDEBE3);
  static const darkSoft = Color(0xFFA9AE9F);
  static const darkFaint = Color(0xFF8F9585);
  static const darkBoundary = Color(0xFF6A7062);
  static const darkLine = Color(0xFF34302A);
  static const darkShadowTint = Color(0xFF000000);

  static const lightAccentText = Color(0xFF8A6412);
  static const darkAccentText = Color(0xFFE8A020);
  static const lightDotInactive = Color(0xFFC3C7BC);
  static const darkDotInactive = Color(0xFF3A4035);
  static const lightMapLabel = Color(0xFF8A8F83);
  static const darkMapLabel = Color(0xFF767C6D);
  static const lightMapLabelWater = Color(0xFF93A2A4);
  static const darkMapLabelWater = Color(0xFF5D6A6B);

  /// Dimmer behind modal cards and the drawer. Dark uses black, never the
  /// light ink, so the map underneath always darkens.
  static Color scrim(Brightness brightness) => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .55)
      : lightInk.withValues(alpha: .42);

  static Color accentText(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccentText : lightAccentText;
}

/// The FEAT-003 V1 neutral colours for one theme.
@immutable
class WarangNeutrals extends ThemeExtension<WarangNeutrals> {
  const WarangNeutrals({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.boundary,
    required this.hairline,
    required this.shadowTint,
  });

  /// Screen background.
  final Color ground;

  /// Clay cards, sheets, and the dock.
  final Color surface;

  /// Polaroid borders, and raised clay in dark.
  final Color surfaceRaised;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkSoft;

  /// Metadata and hints.
  final Color inkFaint;

  /// Outlines that identify a control: fields, toggles, selected states.
  final Color boundary;

  /// Decorative dividers only, never the only cue.
  final Color hairline;

  /// Base colour of clay shadows.
  final Color shadowTint;

  static const light = WarangNeutrals(
    ground: WarangColors.lightGround,
    surface: WarangColors.lightSurface,
    surfaceRaised: WarangColors.lightSurfaceRaised,
    ink: WarangColors.lightInk,
    inkSoft: WarangColors.lightSoft,
    inkFaint: WarangColors.lightFaint,
    boundary: WarangColors.lightBoundary,
    hairline: WarangColors.lightLine,
    shadowTint: WarangColors.lightShadowTint,
  );
  static const dark = WarangNeutrals(
    ground: WarangColors.darkGround,
    surface: WarangColors.darkSurface,
    surfaceRaised: WarangColors.darkSurfaceRaised,
    ink: WarangColors.darkInk,
    inkSoft: WarangColors.darkSoft,
    inkFaint: WarangColors.darkFaint,
    boundary: WarangColors.darkBoundary,
    hairline: WarangColors.darkLine,
    shadowTint: WarangColors.darkShadowTint,
  );

  static WarangNeutrals of(BuildContext context) =>
      Theme.of(context).extension<WarangNeutrals>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  WarangNeutrals copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? boundary,
    Color? hairline,
    Color? shadowTint,
  }) => WarangNeutrals(
    ground: ground ?? this.ground,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    inkFaint: inkFaint ?? this.inkFaint,
    boundary: boundary ?? this.boundary,
    hairline: hairline ?? this.hairline,
    shadowTint: shadowTint ?? this.shadowTint,
  );

  @override
  WarangNeutrals lerp(covariant WarangNeutrals? other, double t) {
    if (other == null) return this;
    return WarangNeutrals(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      boundary: Color.lerp(boundary, other.boundary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      shadowTint: Color.lerp(shadowTint, other.shadowTint, t)!,
    );
  }
}

abstract final class WarangGlass {
  static const lightAlpha = 0.88;
  static const darkAlpha = 0.90;
  static const blurSigma = 8.0;
}

abstract final class WarangLayout {
  /// C1 dock: a 72 tall pill, 12 from each side, 8 above the bottom inset.
  static const dockHeight = 72.0;
  static const dockMarginBottom = 8.0;
  static const dockMarginHorizontal = 12.0;

  /// The C2 capture button, with its 4 px ring, centred on the dock's top
  /// edge.
  static const captureOuterDiameter = 84.0;

  /// Screens at least this wide use the left rail instead of the dock.
  static const railBreakpoint = 900.0;

  static bool usesRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= railBreakpoint;

  /// The height the dock covers from the bottom of the screen, or zero when
  /// the rail is in use.
  static double navigationHeight(BuildContext context) {
    if (usesRail(context)) return 0.0;
    return dockHeight + dockMarginBottom + MediaQuery.paddingOf(context).bottom;
  }

  /// Content placed above this height clears the dock and the raised
  /// capture button.
  static double dockClearance(BuildContext context) {
    if (usesRail(context)) return 0.0;
    return navigationHeight(context) + captureOuterDiameter / 2;
  }
}

@immutable
class MapPalette extends ThemeExtension<MapPalette> {
  const MapPalette({
    required this.land,
    required this.landAlt,
    required this.water,
    required this.roads,
    required this.label,
    required this.labelWater,
  });

  final Color land;
  final Color landAlt;
  final Color water;
  final Color roads;
  final Color label;
  final Color labelWater;

  static const light = MapPalette(
    land: Color(0xFFE6E7E0),
    landAlt: Color(0xFFDCDED4),
    water: Color(0xFFCBD8DA),
    roads: Color(0xFFF6F7F2),
    label: WarangColors.lightMapLabel,
    labelWater: WarangColors.lightMapLabelWater,
  );
  static const dark = MapPalette(
    land: Color(0xFF1A1D18),
    landAlt: Color(0xFF22261F),
    water: Color(0xFF141B1E),
    roads: Color(0xFF2C3129),
    label: WarangColors.darkMapLabel,
    labelWater: WarangColors.darkMapLabelWater,
  );

  @override
  MapPalette copyWith({
    Color? land,
    Color? landAlt,
    Color? water,
    Color? roads,
    Color? label,
    Color? labelWater,
  }) => MapPalette(
    land: land ?? this.land,
    landAlt: landAlt ?? this.landAlt,
    water: water ?? this.water,
    roads: roads ?? this.roads,
    label: label ?? this.label,
    labelWater: labelWater ?? this.labelWater,
  );

  @override
  MapPalette lerp(covariant MapPalette? other, double t) {
    if (other == null) return this;
    return MapPalette(
      land: Color.lerp(land, other.land, t)!,
      landAlt: Color.lerp(landAlt, other.landAlt, t)!,
      water: Color.lerp(water, other.water, t)!,
      roads: Color.lerp(roads, other.roads, t)!,
      label: Color.lerp(label, other.label, t)!,
      labelWater: Color.lerp(labelWater, other.labelWater, t)!,
    );
  }
}

ThemeData buildWarangTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? WarangColors.darkInk : WarangColors.lightInk;
  final soft = dark ? WarangColors.darkSoft : WarangColors.lightSoft;
  final surface = dark ? WarangColors.darkSurface : WarangColors.lightSurface;
  final ground = dark ? WarangColors.darkGround : WarangColors.lightGround;
  final neutrals = dark ? WarangNeutrals.dark : WarangNeutrals.light;
  final line = neutrals.hairline;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: WarangColors.accent,
    onPrimary: WarangColors.accentInk,
    secondary: soft,
    onSecondary: surface,
    error: const Color(0xFFB8493D),
    onError: Colors.white,
    surface: surface,
    onSurface: ink,
    outline: neutrals.boundary,
    outlineVariant: line,
  );
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    fontFamily: WarangType.textFamily,
    useMaterial3: true,
  );
  return base.copyWith(
    extensions: [dark ? MapPalette.dark : MapPalette.light, neutrals],
    textTheme: base.textTheme.copyWith(
      displayLarge: WarangType.wordmark.copyWith(color: ink),
      displayMedium: WarangType.displayL.copyWith(color: ink),
      displaySmall: WarangType.displayL.copyWith(color: ink),
      headlineLarge: WarangType.displayL.copyWith(color: ink),
      headlineMedium: WarangType.displayM.copyWith(color: ink),
      headlineSmall: WarangType.stampNumber.copyWith(color: ink),
      titleLarge: WarangType.titleS.copyWith(color: ink),
      titleMedium: WarangType.titleS.copyWith(color: ink),
      titleSmall: WarangType.titleS.copyWith(color: ink),
      bodyLarge: WarangType.bodyL.copyWith(color: ink),
      bodyMedium: WarangType.body.copyWith(color: soft),
      bodySmall: WarangType.body.copyWith(fontSize: 13.5, color: soft),
      labelLarge: WarangType.button.copyWith(color: ink),
      labelMedium: WarangType.meta.copyWith(color: neutrals.inkFaint),
      labelSmall: WarangType.caption.copyWith(color: soft),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => const WarangIcon(WarangGlyphs.back),
      closeButtonIconBuilder: (context) => const WarangIcon(WarangGlyphs.close),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: WarangColors.accentText(brightness),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: neutrals.inkFaint),
      // Amber fails contrast as text on light surfaces, so a focused label
      // uses the darker accent text token instead of the primary colour.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? WarangColors.accentText(brightness)
              : soft,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutrals.boundary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutrals.boundary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WarangColors.accent, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: line),
      ),
    ),
  );
}
