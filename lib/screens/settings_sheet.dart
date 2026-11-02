import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/sky_glass_widgets.dart';

/// Settings & System Calibration Sheet (Serene Sky Sanctuary).
///
/// Features:
/// - Precision Toggle: Shows/hides .00 centiseconds on the Active Focus Screen.
///   (No separate toggle to hide main timer digits).
/// - 3-Option Theme Palette Selector: Serene Sky, Midnight Sky, Pure Black OLED.
/// - File-Based JSON Backup & Atomic Restore:
///   * Validates schema version (serene_sky_backup_v2), fields, and data types.
///   * Preserves existing data safely if import fails.
///   * Dynamically recalculates streak against DateTime.now() in device local timezone.
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
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.isDark ? const Color(0xFF0F172A) : const Color(0xFF285CB2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              const SizedBox(height: 10),

              // Top Drag Handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 12),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sanctuary Calibration & Settings',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 1),

              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(18.0),
                  children: [
                    // Section 1: Appearance & Tri-Theme Palettes
                    _buildSectionHeader('APPEARANCE & THEME PALETTES', palette),
                    const SizedBox(height: 10),
                    _buildThemeSelector(themeController, controller, palette),

                    const SizedBox(height: 20),

                    // Section 2: Timer Precision (Centiseconds Toggle)
                    _buildSectionHeader('TIMER PRECISION & DISPLAY', palette),
                    const SizedBox(height: 10),
                    _buildPrecisionSwitch(controller, palette),

                    const SizedBox(height: 20),

                    // Section 3: File-Based JSON Backup & Atomic Restore
                    _buildSectionHeader('DATA MANAGEMENT & ARCHIVE', palette),
                    const SizedBox(height: 10),
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

  Widget _buildSectionHeader(String title, SkyPalette palette) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: palette.secondaryText,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildThemeSelector(
    SkyThemeController themeController,
    AppController appController,
    SkyPalette palette,
  ) {
    final options = [
      {'name': 'Serene Sky', 'type': SkyThemePalette.sereneSky, 'key': 'sereneSky'},
      {'name': 'Midnight Dark', 'type': SkyThemePalette.midnightSky, 'key': 'midnightSky'},
      {'name': 'Pure Black', 'type': SkyThemePalette.oledBlack, 'key': 'oledBlack'},
    ];

    return SkyGlassCard(
      padding: const EdgeInsets.all(6),
      borderRadius: BorderRadius.circular(20),
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(palette.isDark ? 0.28 : 0.38)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Colors.white.withOpacity(0.50), width: 1.0)
                      : null,
                ),
                child: Center(
                  child: Text(
                    opt['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? palette.primaryText : palette.secondaryText,
                    ),
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

    return SkyGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timer Precision (.00 centiseconds)',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Shows sub-second high-cadence digits in Active Focus.',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 11,
                    color: palette.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isPrecision,
            onChanged: (val) => controller.togglePrecision(),
            activeColor: palette.amberGold,
            activeTrackColor: palette.amberGold.withOpacity(0.40),
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
        // Backup
        Expanded(
          child: SkyGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            borderRadius: BorderRadius.circular(20),
            onTap: () => controller.exportToFileAndShare(context),
            child: Column(
              children: [
                Icon(Icons.upload_file_rounded, color: palette.amberGold, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Export Backup',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'JSON Archive',
                  style: TextStyle(fontFamily: 'sans-serif', fontSize: 10, color: palette.secondaryText),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Restore
        Expanded(
          child: SkyGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            borderRadius: BorderRadius.circular(20),
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
            child: Column(
              children: [
                Icon(Icons.restore_page_rounded, color: palette.mintAura, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Restore Archive',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Atomic Verify',
                  style: TextStyle(fontFamily: 'sans-serif', fontSize: 10, color: palette.secondaryText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
