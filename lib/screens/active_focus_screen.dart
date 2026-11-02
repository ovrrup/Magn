import 'dart:ui';
import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/sky_glass_widgets.dart';

/// Active Focus Screen (Serene Sky Sanctuary).
///
/// Features:
/// - Distraction-free sky canvas with decorative animations stripped out.
/// - Centered cohesive frosted Timer Capsule with:
///   * Tabular-figures Cloud White stopwatch digits (fontSize: 72, FontWeight.w700).
///   * Optional .00 centiseconds (fontSize: 32, Color(0xFFD6E8FF)) when Precision setting is active.
///   * Active session Topic pill above the timer.
///   * Live reward multiplier pill below the timer (e.g. 1.25x Window Bonus, 1.5x Flow Zone).
/// - Bottom Cloud White pill button: "Finish • +[X] Tokens" dynamically calculating actual reward.
/// - Reliable monotonic elapsed time tracking (Stopwatch-backed).
class ActiveFocusScreen extends StatelessWidget {
  const ActiveFocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final controller = AppControllerScope.of(context);

    final elapsedSeconds = controller.activeElapsedSeconds;
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final centiseconds = (controller.activeElapsedMilliseconds % 1000) ~/ 10;

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    final centiStr = centiseconds.toString().padLeft(2, '0');

    final reward = controller.liveRewardBreakdown;
    final showCentiseconds = controller.settings.precisionShowCentiseconds;

    // Multiplier description string
    String multiplierLabel;
    if (reward.isFlowMultiplierActive) {
      final combined = (reward.windowMultiplier * 1.5).toStringAsFixed(2);
      multiplierLabel = '${combined}x (Window + Flow Zone)';
    } else if (controller.activeWindowMultiplier == 1.25) {
      multiplierLabel = '1.25x Window Bonus';
    } else if (controller.activeWindowMultiplier == 0.75) {
      multiplierLabel = '0.75x Post-Window';
    } else {
      multiplierLabel = '1.0x Standard Rate';
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _confirmAbandonSession(context, controller);
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: palette.backgroundColor,
            gradient: palette.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Top Bar: Cancel button & Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkyGlassCard(
                        padding: EdgeInsets.zero,
                        width: 42,
                        height: 42,
                        borderRadius: BorderRadius.circular(21),
                        onTap: () => _confirmAbandonSession(context, controller),
                        child: Center(
                          child: Icon(
                            Icons.close_rounded,
                            color: palette.primaryText,
                            size: 20,
                          ),
                        ),
                      ),
                      SkyGlassPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.mintAura,
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.mintAura.withOpacity(0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Focus Sanctuary',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 42), // Balance symmetry
                    ],
                  ),

                  // Center Stage: Cohesive Frosted Timer Capsule
                  Expanded(
                    child: Center(
                      child: SkyGlassCard(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                        borderRadius: BorderRadius.circular(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Topic Pill above timer
                            SkyGlassPill(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              backgroundColor: Colors.white.withOpacity(0.15),
                              borderColor: Colors.white.withOpacity(0.35),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.layers_rounded,
                                    color: palette.amberGold,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      controller.activeTopic,
                                      style: TextStyle(
                                        fontFamily: 'sans-serif',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: palette.primaryText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 2. Main Tabular Digits (72px, 700 weight) + Optional Centiseconds
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$minutesStr:$secondsStr',
                                    style: TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontSize: 72,
                                      fontWeight: FontWeight.w700,
                                      color: palette.primaryText,
                                      letterSpacing: 2.0,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (showCentiseconds) ...[
                                    Text(
                                      '.$centiStr',
                                      style: TextStyle(
                                        fontFamily: 'sans-serif',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w600,
                                        color: palette.secondaryText,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 3. Live Reward Multiplier Pill below timer
                            SkyGlassPill(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              backgroundColor: reward.isFlowMultiplierActive
                                  ? palette.amberGold.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.12),
                              borderColor: reward.isFlowMultiplierActive
                                  ? palette.amberGold
                                  : Colors.white.withOpacity(0.30),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    reward.isFlowMultiplierActive
                                        ? Icons.bolt_rounded
                                        : Icons.timer_outlined,
                                    color: reward.isFlowMultiplierActive
                                        ? palette.amberGold
                                        : palette.mintAura,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    multiplierLabel,
                                    style: TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: palette.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Button: "Finish • +[X] Tokens"
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SkyPillButton(
                      height: 58,
                      icon: Icons.check_circle_rounded,
                      label: 'Finish • +${reward.totalTokens} Tokens',
                      onPressed: () async {
                        final completed = await controller.finishFocusSession();
                        if (context.mounted && completed != null) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Session completed! +${completed.totalTokensEarned} Tokens added to sanctuary wallet.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAbandonSession(BuildContext context, AppController controller) {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = SkyThemeScope.paletteOf(ctx);
        return AlertDialog(
          backgroundColor: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.35)),
          ),
          title: Text(
            'Abandon Session?',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.primaryText,
            ),
          ),
          content: Text(
            'Cancelling will discard elapsed focus time and no token reward will be awarded.',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 14,
              color: palette.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Keep Focusing', style: TextStyle(color: palette.primaryText)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // close dialog
                controller.cancelFocusSession();
                Navigator.of(context).pop(); // close screen
              },
              child: Text('Abandon', style: TextStyle(color: palette.deadlineAlertCoral)),
            ),
          ],
        );
      },
    );
  }
}
