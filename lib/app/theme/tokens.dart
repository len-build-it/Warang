import 'package:flutter/material.dart';

abstract final class WarangColors {
  static const accent = Color(0xFFE8A020);
  static const accentInk = Color(0xFF231F0E);
  static const lightGround = Color(0xFFECEDE8);
  static const lightSurface = Color(0xFFF7F8F3);
  static const lightLine = Color(0xFFD2D5CB);
  static const lightInk = Color(0xFF1A1D18);
  static const lightSoft = Color(0xFF5C6157);
  static const lightFaint = Color(0xFF8A8F83);
  static const darkGround = Color(0xFF121410);
  static const darkSurface = Color(0xFF1B1E18);
  static const darkLine = Color(0xFF2E332A);
  static const darkInk = Color(0xFFE9EBE3);
  static const darkSoft = Color(0xFFA0A697);
  static const darkFaint = Color(0xFF767C6D);
  static const lightAccentText = Color(0xFF8A6412);
  static const darkAccentText = Color(0xFFE8A020);
  static const lightDotInactive = Color(0xFFC3C7BC);
  static const darkDotInactive = Color(0xFF3A4035);
  static const lightMapLabel = Color(0xFF8A8F83);
  static const darkMapLabel = Color(0xFF767C6D);
  static const lightMapLabelWater = Color(0xFF93A2A4);
  static const darkMapLabelWater = Color(0xFF5D6A6B);
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
  final line = dark ? WarangColors.darkLine : WarangColors.lightLine;
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
    outline: line,
  );
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    fontFamily: 'Public Sans',
    useMaterial3: true,
  );
  return base.copyWith(
    extensions: [dark ? MapPalette.dark : MapPalette.light],
    textTheme: base.textTheme.copyWith(
      displayLarge: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 54,
        height: 1.0,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -2.16,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 30,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.9,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 28,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.84,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 21,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.525,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 15.5, height: 1.45, color: soft),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.6, color: soft),
      labelLarge: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(fontSize: 13.5, color: soft),
      labelSmall: TextStyle(fontSize: 10, color: soft),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: soft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WarangColors.accent, width: 1),
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
