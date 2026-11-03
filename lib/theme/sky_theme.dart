import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized 3-font typography system using Google Fonts:
/// 1. Display & Headings: GoogleFonts.plusJakartaSans (FontWeight.w700, letterSpacing: -0.5)
///    Used for modal titles ("New Session", "New Goal", "Settings"), carousel primary titles, and dialog headers.
/// 2. Numeric & Telemetry Readouts: GoogleFonts.spaceGrotesk (FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()], letterSpacing: -1.0)
///    Used for Active Focus timer digits (76px main digits, 32px centiseconds), top Streak and Token counters, duration chips (15m-90m), and Stats numbers.
/// 3. Clean UI Labels & Buttons: GoogleFonts.inter
///    - Buttons and segmented tabs: FontWeight.w600
///    - Compact card micro-labels: FontWeight.w600, fontSize 11, letterSpacing: 1.1
class AppTypography {
  /// (1) Display & Headings using Plus Jakarta Sans
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.5,
    Color? color,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
      shadows: shadows,
    );
  }

  /// (2) Numeric & Telemetry Readouts using Space Grotesk
  static TextStyle numeric({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -1.0,
    Color? color,
    List<FontFeature>? fontFeatures,
    double? height,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      fontFeatures: fontFeatures ?? const [FontFeature.tabularFigures()],
      color: color,
      height: height,
    );
  }

  /// (3) Clean UI Labels & Buttons using Inter
  static TextStyle label({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }

  /// (3b) Compact Card Micro-labels (11px uppercase, 1.1 letterSpacing)
  static TextStyle microLabel({
    Color? color,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 1.1,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Convenience for Pill Buttons and Action Labels
  static TextStyle button({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}

/// User-selectable theme mode preferences.
enum SkyThemeMode {
  system,
  sereneSky,
  midnightSky,
  oledBlack,
}

extension SkyThemeModeExtension on SkyThemeMode {
  String toKey() {
    switch (this) {
      case SkyThemeMode.system:
        return 'system';
      case SkyThemeMode.sereneSky:
        return 'sereneSky';
      case SkyThemeMode.midnightSky:
        return 'midnightSky';
      case SkyThemeMode.oledBlack:
        return 'oledBlack';
    }
  }

  static SkyThemeMode fromString(String val) {
    switch (val) {
      case 'system':
        return SkyThemeMode.system;
      case 'midnightSky':
      case 'dark':
        return SkyThemeMode.midnightSky;
      case 'oledBlack':
      case 'oled':
        return SkyThemeMode.oledBlack;
      case 'sereneSky':
      case 'light':
      default:
        return SkyThemeMode.sereneSky;
    }
  }
}

/// Resolved visual palettes for rendering.
enum SkyThemePalette {
  sereneSky,
  midnightSky,
  oledBlack,
}

/// Color tokens, gradients, and styling parameters for a Serene Sky Sanctuary palette.
class SkyPalette {
  final SkyThemePalette type;
  final String name;
  final LinearGradient? backgroundGradient;
  final Color backgroundColor;
  final Color modalBackground;
  final Color glassSurfaceColor;
  final Color glassBorderColor;
  final double glassBorderWidth;
  final double glassRadius;
  final Color primaryText;
  final Color secondaryText;
  final Color amberGold;
  final Color mintAura;
  final Color deadlineAlertCoral;
  final Color iceBlueShadow;
  final Color pillButtonBg;
  final Color pillButtonText;
  final Color dockBg;
  final Color navActiveIcon;
  final Color navInactiveIcon;
  final Brightness systemBrightness;

  const SkyPalette({
    required this.type,
    required this.name,
    this.backgroundGradient,
    required this.backgroundColor,
    required this.modalBackground,
    required this.glassSurfaceColor,
    required this.glassBorderColor,
    this.glassBorderWidth = 1.0,
    this.glassRadius = 24.0,
    required this.primaryText,
    required this.secondaryText,
    required this.amberGold,
    required this.mintAura,
    required this.deadlineAlertCoral,
    required this.iceBlueShadow,
    required this.pillButtonBg,
    required this.pillButtonText,
    required this.dockBg,
    required this.navActiveIcon,
    required this.navInactiveIcon,
    required this.systemBrightness,
  });

  bool get isDark => type != SkyThemePalette.sereneSky;
  bool get isOled => type == SkyThemePalette.oledBlack;

  /// Serene Sky Default Palette (Light mode)
  static const SkyPalette sereneSky = SkyPalette(
    type: SkyThemePalette.sereneSky,
    name: 'Serene Sky Default',
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2B6CB0), // Deeper, richer matte slate-cerulean top
        Color(0xFF3B82F6), // Cerulean mid
        Color(0xFF60A5FA), // Soft luminous sky bottom
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    backgroundColor: Color(0xFF2B6CB0),
    modalBackground: Color(0xFF1E3A8A),
    glassSurfaceColor: Color(0x3DFFFFFF), // White at 0.24 opacity
    glassBorderColor: Color(0x6BFFFFFF), // White at 0.42 opacity
    glassBorderWidth: 1.2,
    glassRadius: 24.0,
    primaryText: Color(0xFFFFFFFF), // Cloud White
    secondaryText: Color(0xFFDBEAFE), // Soft Sky Blue
    amberGold: Color(0xFFFFB547), // Warm Amber Gold
    mintAura: Color(0xFF6EE7B7), // Soft Mint Glow
    deadlineAlertCoral: Color(0xFFFF6B6B), // Deadline Alert Coral
    iceBlueShadow: Color(0xFFD0E4FF), // Soft Ice-Blue 3D shadow
    pillButtonBg: Color(0xFFFFFFFF), // Cloud White
    pillButtonText: Color(0xFF0F172A), // Deep Navy #0F172A
    dockBg: Color(0x38FFFFFF), // Frosted glass dock
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xB3D6E8FF),
    systemBrightness: Brightness.light,
  );

  /// Midnight Sky Dark Mode Palette (Rich atmospheric, non-washed-out)
  static const SkyPalette midnightSky = SkyPalette(
    type: SkyThemePalette.midnightSky,
    name: 'Midnight Sky Dark',
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF060B19), // Deep atmospheric navy top
        Color(0xFF0F172A), // Slate center
        Color(0xFF1A2639), // Atmospheric slate bottom
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    backgroundColor: Color(0xFF060B19),
    modalBackground: Color(0xFF0F172A),
    glassSurfaceColor: Color(0xB81E293B), // Translucent slate (Color(0xFF1E293B) at 0.72 opacity)
    glassBorderColor: Color(0x1FFFFFFF), // Crisp 1px specular border (Color(0xFFFFFFFF) at 0.12 opacity)
    glassBorderWidth: 1.0,
    glassRadius: 22.0,
    primaryText: Color(0xFFF8FAFC), // Crisp Slate 50
    secondaryText: Color(0xFF94A3B8), // Slate 400
    amberGold: Color(0xFFFFB547), // Warm Amber
    mintAura: Color(0xFF34D399), // Luminous Mint #34D399
    deadlineAlertCoral: Color(0xFFFF6B6B),
    iceBlueShadow: Color(0xFF060B19),
    pillButtonBg: Color(0xFFFFFFFF), // Cloud White
    pillButtonText: Color(0xFF060B19), // Deep Navy #060B19
    dockBg: Color(0xD90F172A), // Translucent deep slate dock
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0x8094A3B8),
    systemBrightness: Brightness.dark,
  );

  /// Pure Black OLED Mode Palette (True 0-nit pixel shutoff)
  static const SkyPalette oledBlack = SkyPalette(
    type: SkyThemePalette.oledBlack,
    name: 'Pure Black OLED',
    backgroundGradient: null,
    backgroundColor: Color(0xFF000000), // Solid Black #000000
    modalBackground: Color(0xFF000000), // Solid Black #000000
    glassSurfaceColor: Color(0xFF090D14), // Subtle elevated card surface #090D14
    glassBorderColor: Color(0xFF1E293B), // Crisp 1px border #1E293B
    glassBorderWidth: 1.0,
    glassRadius: 22.0,
    primaryText: Color(0xFFFFFFFF), // Pure White #FFFFFF
    secondaryText: Color(0xFF78849B), // Crisp Subdued Gray #78849B
    amberGold: Color(0xFFFFB547), // Warm Amber
    mintAura: Color(0xFF34D399), // Luminous Mint
    deadlineAlertCoral: Color(0xFFFF6B6B),
    iceBlueShadow: Color(0xFF000000),
    pillButtonBg: Color(0xFFFFFFFF),
    pillButtonText: Color(0xFF000000),
    dockBg: Color(0xFF000000), // Pure Black dock
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xFF78849B),
    systemBrightness: Brightness.dark,
  );

  static SkyPalette of(SkyThemePalette palette) {
    switch (palette) {
      case SkyThemePalette.sereneSky:
        return sereneSky;
      case SkyThemePalette.midnightSky:
        return midnightSky;
      case SkyThemePalette.oledBlack:
        return oledBlack;
    }
  }

  static SkyThemePalette fromString(String val) {
    switch (val) {
      case 'midnightSky':
      case 'dark':
        return SkyThemePalette.midnightSky;
      case 'oledBlack':
      case 'oled':
        return SkyThemePalette.oledBlack;
      case 'sereneSky':
      case 'light':
      default:
        return SkyThemePalette.sereneSky;
    }
  }
}

/// Global controller to manage and observe theme modes and system resolution.
class SkyThemeController extends ChangeNotifier {
  SkyThemeMode _mode = SkyThemeMode.system;
  bool _usePureBlackForDark = false;

  SkyThemeMode get mode => _mode;
  bool get usePureBlackForDark => _usePureBlackForDark;

  SkyThemeController({
    SkyThemeMode initialMode = SkyThemeMode.system,
    bool initialUsePureBlackForDark = false,
  })  : _mode = initialMode,
        _usePureBlackForDark = initialUsePureBlackForDark;

  /// Resolves the concrete [SkyPalette] given platform brightness.
  SkyPalette resolveForBrightness(Brightness brightness) {
    switch (_mode) {
      case SkyThemeMode.sereneSky:
        return SkyPalette.sereneSky;
      case SkyThemeMode.midnightSky:
        return SkyPalette.midnightSky;
      case SkyThemeMode.oledBlack:
        return SkyPalette.oledBlack;
      case SkyThemeMode.system:
        if (brightness == Brightness.dark) {
          return _usePureBlackForDark ? SkyPalette.oledBlack : SkyPalette.midnightSky;
        }
        return SkyPalette.sereneSky;
    }
  }

  /// Current palette using fallback platform dispatcher brightness.
  SkyPalette get current => resolveForBrightness(
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );

  /// Backwards-compatible palette enum getter.
  SkyThemePalette get palette => current.type;

  void setMode(SkyThemeMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      notifyListeners();
    }
  }

  void setUsePureBlackForDark(bool value) {
    if (_usePureBlackForDark != value) {
      _usePureBlackForDark = value;
      notifyListeners();
    }
  }

  /// Backwards-compatible setter for legacy callers.
  void setPalette(SkyThemePalette newPalette) {
    switch (newPalette) {
      case SkyThemePalette.sereneSky:
        setMode(SkyThemeMode.sereneSky);
        break;
      case SkyThemePalette.midnightSky:
        setMode(SkyThemeMode.midnightSky);
        break;
      case SkyThemePalette.oledBlack:
        setMode(SkyThemeMode.oledBlack);
        break;
    }
  }

  void cyclePalette() {
    switch (_mode) {
      case SkyThemeMode.system:
        setMode(SkyThemeMode.sereneSky);
        break;
      case SkyThemeMode.sereneSky:
        setMode(SkyThemeMode.midnightSky);
        break;
      case SkyThemeMode.midnightSky:
        setMode(SkyThemeMode.oledBlack);
        break;
      case SkyThemeMode.oledBlack:
        setMode(SkyThemeMode.system);
        break;
    }
  }
}

/// InheritedWidget providing reactive access to [SkyPalette] and [SkyThemeController].
class SkyThemeScope extends InheritedNotifier<SkyThemeController> {
  const SkyThemeScope({
    super.key,
    required SkyThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Resolves the active [SkyPalette] dynamically by registering a dependency on
  /// [MediaQuery.platformBrightnessOf(context)] when in system theme mode.
  static SkyPalette paletteOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkyThemeScope>();
    final controller = scope?.notifier;
    if (controller == null) {
      return SkyPalette.sereneSky;
    }
    final brightness = MediaQuery.maybePlatformBrightnessOf(context) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return controller.resolveForBrightness(brightness);
  }

  static SkyThemeController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkyThemeScope>();
    assert(scope != null, 'No SkyThemeScope found in context');
    return scope!.notifier!;
  }
}
