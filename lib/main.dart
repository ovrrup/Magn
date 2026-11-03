import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/app_shell.dart';
import 'state/app_controller.dart';
import 'theme/sky_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive edge-to-edge transparent system overlay bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SereneSkyApp());
}

/// Root application widget for Serene Sky Sanctuary.
///
/// Provides [AppControllerScope] and [SkyThemeScope] to the entire widget tree,
/// and synchronizes system navigation chrome dynamically with the active [SkyThemePalette].
class SereneSkyApp extends StatefulWidget {
  final AppController? controller;
  final SkyThemeController? themeController;

  const SereneSkyApp({
    super.key,
    this.controller,
    this.themeController,
  });

  @override
  State<SereneSkyApp> createState() => _SereneSkyAppState();
}

class _SereneSkyAppState extends State<SereneSkyApp> {
  late final SkyThemeController _themeController;
  late final AppController _appController;
  bool _ownsControllers = false;

  @override
  void initState() {
    super.initState();
    _appController = widget.controller ?? AppController();
    _themeController = widget.themeController ??
        SkyThemeController(
          initialMode: SkyThemeModeExtension.fromString(_appController.settings.themeMode),
          initialUsePureBlackForDark: _appController.settings.usePureBlackForDark,
        );
    if (widget.controller == null && widget.themeController == null) {
      _ownsControllers = true;
    }
    _syncTheme();
    _appController.addListener(_syncTheme);
  }

  void _syncTheme() {
    final mode = SkyThemeModeExtension.fromString(_appController.settings.themeMode);
    _themeController.setMode(mode);
    _themeController.setUsePureBlackForDark(_appController.settings.usePureBlackForDark);
  }

  @override
  void dispose() {
    _appController.removeListener(_syncTheme);
    if (_ownsControllers) {
      _themeController.dispose();
      _appController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppControllerScope(
      controller: _appController,
      child: SkyThemeScope(
        controller: _themeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([_themeController, _appController]),
          builder: (context, _) {
            final palette = _themeController.current;

            // Synchronize system UI icon brightness with active palette
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    palette.isDark ? Brightness.light : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    palette.isDark ? Brightness.light : Brightness.light,
              ),
            );

            return MaterialApp(
              title: 'Serene Sky Sanctuary',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                brightness: palette.isDark ? Brightness.dark : Brightness.light,
                scaffoldBackgroundColor: palette.backgroundColor,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF3888E6),
                  brightness: palette.isDark ? Brightness.dark : Brightness.light,
                  primary: const Color(0xFF3888E6),
                  secondary: palette.amberGold,
                  tertiary: palette.mintAura,
                  surface: palette.glassSurfaceColor,
                ),
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              home: const AppShell(),
            );
          },
        ),
      ),
    );
  }
}
