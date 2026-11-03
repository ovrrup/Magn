import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';

/// Settings Sheet (Serene Sky Sanctuary).
///
/// Features:
/// - 3-Option Theme Palette Selector: Serene Sky, Midnight, Pure Black.
/// - Precision Toggle: Shows/hides .00 centiseconds on Active Focus.
/// - File-Based JSON Backup & Atomic Restore: Export / Import.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final themeController = SkyThemeScope.controllerOf(context);
    final controller = AppControllerScope.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.isDark ? const Color(0xFF0F172A) : const Color(0xFF285CB2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.40),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Top Drag Handle (centered 36x4px, white at 0.35 opacity)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title Bar ("Settings" + X button, no divider line)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    // 1. 3-Option Theme Segmented Bar ("Serene Sky", "Midnight", "Pure Black", height 48px, borderRadius 24px)
                    _buildThemeSelector(themeController, controller, palette),

                    const SizedBox(height: 14),

                    // 2. 56px Frosted Row with "Precision (.00)" and Switch
                    _buildPrecisionSwitch(controller, palette),

                    const SizedBox(height: 14),

                    // 3. Row of two 52px horizontal frosted pill buttons: "Export" & "Import"
                    _buildDataManagementSection(context, controller, palette),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector(
    SkyThemeController themeController,
    AppController appController,
    SkyPalette palette,
  ) {
    final options = [
      {'name': 'Serene Sky', 'type': SkyThemePalette.sereneSky, 'key': 'sereneSky'},
      {'name': 'Midnight', 'type': SkyThemePalette.midnightSky, 'key': 'midnightSky'},
      {'name': 'Pure Black', 'type': SkyThemePalette.oledBlack, 'key': 'oledBlack'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(palette.isDark ? 0.18 : 0.30),
          width: 1.0,
        ),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = themeController.palette == opt['type'];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                themeController.setPalette(opt['type'] as SkyThemePalette);
                appController.updateSettings(
                  appController.settings.copyWith(themeMode: opt['key'] as String),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFFFFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  opt['name'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : palette.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrecisionSwitch(AppController controller, SkyPalette palette) {
    final isPrecision = controller.settings.precisionShowCentiseconds;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Precision (.00)',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
            ),
          ),
          Switch.adaptive(
            value: isPrecision,
            onChanged: (val) => controller.togglePrecision(),
            activeColor: const Color(0xFFFFFFFF),
            activeTrackColor: const Color(0xFFFFB547),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.20),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementSection(
    BuildContext context,
    AppController controller,
    SkyPalette palette,
  ) {
    return Row(
      children: [
        // Export button
        Expanded(
          child: GestureDetector(
            onTap: () => controller.exportToFileAndShare(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Export',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Import button
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final success = await controller.pickAndRestoreFile(context);
              if (context.mounted && success != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Backup restored successfully! Streak recalculated.'
                          : 'Restoration failed: Invalid backup structure or schema.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Import',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
