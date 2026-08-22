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
}

@immutable
class MapPalette extends ThemeExtension<MapPalette> {
  const MapPalette({
    required this.land,
    required this.landAlt,
    required this.water,
    required this.roads,
  });

  final Color land;
  final Color landAlt;
  final Color water;
  final Color roads;

  static const light = MapPalette(
    land: Color(0xFFE6E7E0),
    landAlt: Color(0xFFDCDED4),
    water: Color(0xFFCBD8DA),
    roads: Color(0xFFF6F7F2),
  );
  static const dark = MapPalette(
    land: Color(0xFF1A1D18),
    landAlt: Color(0xFF22261F),
    water: Color(0xFF141B1E),
    roads: Color(0xFF2C3129),
  );

  @override
  MapPalette copyWith({
    Color? land,
    Color? landAlt,
    Color? water,
    Color? roads,
  }) => MapPalette(
    land: land ?? this.land,
    landAlt: landAlt ?? this.landAlt,
    water: water ?? this.water,
    roads: roads ?? this.roads,
  );

  @override
  MapPalette lerp(covariant MapPalette? other, double t) {
    if (other == null) return this;
    return MapPalette(
      land: Color.lerp(land, other.land, t)!,
      landAlt: Color.lerp(landAlt, other.landAlt, t)!,
      water: Color.lerp(water, other.water, t)!,
      roads: Color.lerp(roads, other.roads, t)!,
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
        fontSize: 42,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -1.1,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 30,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.7,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Bricolage Grotesque',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: soft),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
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
