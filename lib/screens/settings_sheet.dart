import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/sky_glass_widgets.dart';

/// Settings Sheet (Serene Sky Sanctuary).
///
/// Features:
/// - 4-Segment Theme Mode Selector: System, Sky, Midnight, OLED.
/// - Pure Black for Dark Mode toggle: Allows 0-nit OLED even when using System theme.
/// - Precision Toggle: Shows/hides .00 centiseconds on Active Focus.
/// - File-Based JSON Backup & Atomic Restore: Export / Import.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF090D16).withOpacity(0.45),
      builder: (context) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final themeController = SkyThemeScope.controllerOf(context);
    final controller = AppControllerScope.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      builder: (context, scrollController) {
        return SkyGlassModal(
          isBottomSheet: true,
          padding: EdgeInsets.zero,
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
                  children: [
                    Expanded(
                      child: Text(
                        'Settings',
                        style: AppTypography.display(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF),
                        ),
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
                    // 1. 4-Option Theme Segmented Bar ("System", "Sky", "Midnight", "OLED", height 48px, borderRadius 24px)
                    _buildThemeSelector(themeController, controller, palette),

                    const SizedBox(height: 14),

                    // 2. Pure Black for Dark Mode toggle
                    _buildOledToggle(themeController, controller, palette),

                    const SizedBox(height: 14),

                    // 3. 56px Frosted Row with "Precision (.00)" and Switch
                    _buildPrecisionSwitch(controller, palette),

                    const SizedBox(height: 14),

                    // 4. Row of two 52px horizontal frosted pill buttons: "Export" & "Import"
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
      {'name': 'System', 'mode': SkyThemeMode.system, 'key': 'system'},
      {'name': 'Sky', 'mode': SkyThemeMode.sereneSky, 'key': 'sereneSky'},
      {'name': 'Midnight', 'mode': SkyThemeMode.midnightSky, 'key': 'midnightSky'},
      {'name': 'OLED', 'mode': SkyThemeMode.oledBlack, 'key': 'oledBlack'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: SkyGlassWell.decoration(palette, borderRadius: 24),
      child: Row(
        children: options.map((opt) {
          final isSelected = themeController.mode == opt['mode'];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                final mode = opt['mode'] as SkyThemeMode;
                themeController.setMode(mode);
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    opt['name'] as String,
                    textAlign: TextAlign.center,
                    style: AppTypography.label(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0F172A) : palette.secondaryText,
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

  Widget _buildOledToggle(
    SkyThemeController themeController,
    AppController controller,
    SkyPalette palette,
  ) {
    final usePureBlack = controller.settings.usePureBlackForDark;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: SkyGlassWell.decoration(palette, borderRadius: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pure Black for Dark Mode',
              style: AppTypography.label(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
          Switch.adaptive(
            value: usePureBlack,
            onChanged: (val) {
              themeController.setUsePureBlackForDark(val);
              controller.togglePureBlackForDark();
            },
            activeColor: const Color(0xFFFFFFFF),
            activeTrackColor: const Color(0xFFFFB547),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.20),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecisionSwitch(AppController controller, SkyPalette palette) {
    final isPrecision = controller.settings.precisionShowCentiseconds;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: SkyGlassWell.decoration(palette, borderRadius: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Precision (.00)',
              style: AppTypography.label(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFFFFF),
              ),
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
              decoration: SkyGlassWell.decoration(palette, borderRadius: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Export',
                    style: AppTypography.button(
                      fontSize: 14,
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
              decoration: SkyGlassWell.decoration(palette, borderRadius: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Import',
                    style: AppTypography.button(
                      fontSize: 14,
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
