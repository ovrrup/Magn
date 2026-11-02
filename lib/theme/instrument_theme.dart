import 'package:flutter/material.dart';

/// Available appearance options for the Precision Field Instrument.
enum InstrumentThemeMode {
  stoneLight,
  obsidianDark,
  pureBlackOled,
}

/// Exact solid color palette tokens for the Precision Field Instrument.
/// Shared identically across every screen and modal sheet with zero gradients.
class InstrumentPalette {
  final Color background;
  final Color cardSurface;
  final Color recessedSurface;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color hairlineBorder;
  final Color signalOrange;

  const InstrumentPalette({
    required this.background,
    required this.cardSurface,
    required this.recessedSurface,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.hairlineBorder,
    required this.signalOrange,
  });

  /// (1) Anodized Stone Light Mode (DEFAULT)
  /// Crisp, tactile, editorial aesthetic inspired by Braun and Teenage Engineering.
  static const InstrumentPalette stoneLight = InstrumentPalette(
    background: Color(0xFFE6E5E0),
    cardSurface: Color(0xFFF4F3EF),
    recessedSurface: Color(0xFFDAD8D0),
    inkPrimary: Color(0xFF141413),
    inkSecondary: Color(0xFF787670),
    hairlineBorder: Color(0xFFC8C6BE),
    signalOrange: Color(0xFFFF451A),
  );

  /// (2) Obsidian Field Recorder Dark Mode
  /// Matte noir carbon aesthetic for studio and field use.
  static const InstrumentPalette obsidianDark = InstrumentPalette(
    background: Color(0xFF0E0F12),
    cardSurface: Color(0xFF17181C),
    recessedSurface: Color(0xFF1F2127),
    inkPrimary: Color(0xFFF4F3EF),
    inkSecondary: Color(0xFF858890),
    hairlineBorder: Color(0xFF2B2E36),
    signalOrange: Color(0xFFFF451A),
  );

  /// (3) Pure Black OLED Mode
  /// True 0x000000 black canvas for maximum battery efficiency and monolith contrast.
  static const InstrumentPalette pureBlackOled = InstrumentPalette(
    background: Color(0xFF000000),
    cardSurface: Color(0xFF0B0B0D),
    recessedSurface: Color(0xFF141519),
    inkPrimary: Color(0xFFF4F3EF),
    inkSecondary: Color(0xFF787A82),
    hairlineBorder: Color(0xFF22242A),
    signalOrange: Color(0xFFFF451A),
  );
}

/// Theme manager and typography system for Precision Field Instrument.
class InstrumentTheme {
  InstrumentTheme._();

  static InstrumentPalette paletteOf(InstrumentThemeMode mode) {
    switch (mode) {
      case InstrumentThemeMode.stoneLight:
        return InstrumentPalette.stoneLight;
      case InstrumentThemeMode.obsidianDark:
        return InstrumentPalette.obsidianDark;
      case InstrumentThemeMode.pureBlackOled:
        return InstrumentPalette.pureBlackOled;
    }
  }

  static ThemeData buildThemeData(InstrumentThemeMode mode) {
    final palette = paletteOf(mode);
    final isDark = mode != InstrumentThemeMode.stoneLight;

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.cardSurface,
      dividerColor: palette.hairlineBorder,
      primaryColor: palette.signalOrange,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: palette.signalOrange,
        onPrimary: palette.cardSurface,
        secondary: palette.inkPrimary,
        onSecondary: palette.cardSurface,
        surface: palette.cardSurface,
        onSurface: palette.inkPrimary,
        error: palette.signalOrange,
        onError: palette.cardSurface,
      ),
      fontFamily: 'monospace',
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: palette.inkPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: palette.inkPrimary,
          letterSpacing: 1.2,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        modalBackgroundColor: palette.background,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  // --- Monospace / Tabular Typography Helpers ---

  static TextStyle displayLarge(InstrumentPalette p) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: p.inkPrimary,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle displayMedium(InstrumentPalette p) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: p.inkPrimary,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle headline(InstrumentPalette p) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: p.inkPrimary,
        letterSpacing: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(InstrumentPalette p) => TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: p.inkPrimary,
        letterSpacing: 0.2,
      );

  static TextStyle micro(InstrumentPalette p, {bool secondary = true}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: secondary ? p.inkSecondary : p.inkPrimary,
        letterSpacing: 1.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle nano(InstrumentPalette p, {bool secondary = true}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: secondary ? p.inkSecondary : p.inkPrimary,
        letterSpacing: 1.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
