import 'package:flutter/material.dart';

/// Available visual palettes for the Serene Sky Sanctuary design system.
enum SkyThemePalette {
  /// Default serene vertical celestial gradient.
  sereneSky,

  /// Deep slate midnight gradient with preserved luminous accents.
  midnightSky,

  /// Pure black OLED mode with obsidian surface tones.
  oledBlack,
}

/// Color tokens, gradients, and styling parameters for a Serene Sky palette.
class SkyPalette {
  final SkyThemePalette type;
  final String name;
  final LinearGradient? backgroundGradient;
  final Color backgroundColor;
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

  /// Serene Sky Default Palette (matches reference image & exact prompt tokens).
  static const SkyPalette sereneSky = SkyPalette(
    type: SkyThemePalette.sereneSky,
    name: 'Serene Sky Default',
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF3888E6), // Cerulean Blue
        Color(0xFF5CA3F5), // Airy Sky
        Color(0xFF7CB8FA), // Soft Horizon Blue
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    backgroundColor: Color(0xFF3888E6),
    glassSurfaceColor: Color(0x2EFFFFFF), // White at 0.18 opacity
    glassBorderColor: Color(0x52FFFFFF), // White at 0.32 opacity
    glassBorderWidth: 1.0,
    glassRadius: 24.0,
    primaryText: Color(0xFFFFFFFF), // Cloud White
    secondaryText: Color(0xFFD6E8FF), // Soft Sky Blue
    amberGold: Color(0xFFFFB547), // Warm Amber Gold
    mintAura: Color(0xFF6EE7B7), // Soft Mint Glow
    deadlineAlertCoral: Color(0xFFFF6B6B), // Deadline Alert Coral
    iceBlueShadow: Color(0xFFD0E4FF), // Soft Ice-Blue 3D shadow
    pillButtonBg: Color(0xFFFFFFFF), // Cloud White
    pillButtonText: Color(0xFF1E293B), // Deep Navy
    dockBg: Color(0x38FFFFFF), // Frosted glass dock
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xB3D6E8FF),
    systemBrightness: Brightness.light,
  );

  /// Midnight Sky Dark Mode Palette.
  static const SkyPalette midnightSky = SkyPalette(
    type: SkyThemePalette.midnightSky,
    name: 'Midnight Sky Dark',
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0F172A), // Deep Slate Top
        Color(0xFF1E293B), // Midnight Slate Bottom
      ],
    ),
    backgroundColor: Color(0xFF0F172A),
    glassSurfaceColor: Color(0x1FFFFFFF), // White at ~0.12 opacity
    glassBorderColor: Color(0x3DFFFFFF), // White at ~0.24 opacity
    glassBorderWidth: 1.0,
    glassRadius: 24.0,
    primaryText: Color(0xFFFFFFFF), // Cloud White
    secondaryText: Color(0xFF94A3B8), // Slate Light
    amberGold: Color(0xFFFFB547), // Warm Amber Gold
    mintAura: Color(0xFF6EE7B7), // Soft Mint Glow
    deadlineAlertCoral: Color(0xFFFF6B6B), // Deadline Alert Coral
    iceBlueShadow: Color(0xFF1E293B), // Darker shadow
    pillButtonBg: Color(0xFFFFFFFF),
    pillButtonText: Color(0xFF0F172A),
    dockBg: Color(0x520F172A),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0x8094A3B8),
    systemBrightness: Brightness.dark,
  );

  /// Pure Black OLED Mode Palette.
  static const SkyPalette oledBlack = SkyPalette(
    type: SkyThemePalette.oledBlack,
    name: 'Pure Black OLED',
    backgroundGradient: null,
    backgroundColor: Color(0xFF000000), // Solid Black
    glassSurfaceColor: Color(0xFF0B0F17), // Deep Obsidian Surface
    glassBorderColor: Color(0xFF1E293B), // Crisp 1px border
    glassBorderWidth: 1.0,
    glassRadius: 24.0,
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xFF94A3B8),
    amberGold: Color(0xFFFFB547),
    mintAura: Color(0xFF6EE7B7),
    deadlineAlertCoral: Color(0xFFFF6B6B),
    iceBlueShadow: Color(0xFF05070B),
    pillButtonBg: Color(0xFFFFFFFF),
    pillButtonText: Color(0xFF000000),
    dockBg: Color(0xE6000000),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0x8094A3B8),
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
        return SkyThemePalette.midnightSky;
      case 'oledBlack':
        return SkyThemePalette.oledBlack;
      case 'sereneSky':
      default:
        return SkyThemePalette.sereneSky;
    }
  }
}

/// Global controller to toggle and observe visual theme palette previews.
class SkyThemeController extends ChangeNotifier {
  SkyThemePalette _palette = SkyThemePalette.sereneSky;

  SkyThemePalette get palette => _palette;
  SkyPalette get current => SkyPalette.of(_palette);

  void setPalette(SkyThemePalette newPalette) {
    if (_palette != newPalette) {
      _palette = newPalette;
      notifyListeners();
    }
  }

  void cyclePalette() {
    switch (_palette) {
      case SkyThemePalette.sereneSky:
        setPalette(SkyThemePalette.midnightSky);
        break;
      case SkyThemePalette.midnightSky:
        setPalette(SkyThemePalette.oledBlack);
        break;
      case SkyThemePalette.oledBlack:
        setPalette(SkyThemePalette.sereneSky);
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

  static SkyPalette paletteOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkyThemeScope>();
    return scope?.notifier?.current ?? SkyPalette.sereneSky;
  }

  static SkyThemeController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkyThemeScope>();
    assert(scope != null, 'No SkyThemeScope found in context');
    return scope!.notifier!;
  }
}
