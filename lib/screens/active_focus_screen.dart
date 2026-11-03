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

    // Compact combined topic and active multiplier string (e.g. "Assignment • 1.25x")
    final mult = controller.activeWindowMultiplier;
    final multStr = mult == 1.0 ? '1.0x' : '${mult}x';
    final combinedTopicMultiplier = '${controller.activeTopic} • $multStr';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmAbandonSession(context, controller);
        }
      },
      child: Scaffold(
        backgroundColor: palette.backgroundColor,
        body: MatteGranularBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Top Bar: Top-left circular close/abort IconButton ONLY
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SkyGlassCard(
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
                  ),

                  // Center Stage: Numbers sitting directly on open sky canvas without outer container
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Single compact frosted pill combining topic and active multiplier
                          SkyGlassPill(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: Colors.white.withOpacity(0.18),
                            borderColor: Colors.white.withOpacity(0.32),
                            child: Text(
                              combinedTopicMultiplier,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFFFFF), // Cloud White
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Tabular-figures digits in pure Cloud White (fontSize 76, FontWeight.w700, zero shadow)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$minutesStr:$secondsStr',
                                  style: AppTypography.numeric(
                                    fontSize: 76,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.0,
                                    color: const Color(0xFFFFFFFF), // Cloud White
                                  ),
                                ),
                                if (showCentiseconds) ...[
                                  Text(
                                    '.$centiStr',
                                    style: AppTypography.numeric(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -1.0,
                                      color: const Color(0xFFFFFFFF).withOpacity(0.80),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Button: "Finish • +[X] Tokens" strictly without parenthetical suffixes
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFFFF), // Cloud White #FFFFFF
                          foregroundColor: const Color(0xFF0F172A), // Deep navy #0F172A
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        onPressed: () async {
                          final completed = await controller.finishFocusSession();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            if (completed != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Session completed! +${completed.totalTokensEarned} Tokens added to wallet.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Finish • +${reward.totalTokens} Tokens',
                            style: AppTypography.button(
                              fontSize: 16,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
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
      barrierColor: const Color(0xFF090D16).withOpacity(0.45),
      builder: (ctx) {
        final palette = SkyThemeScope.paletteOf(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SkyGlassModal(
            isBottomSheet: false,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abandon Session?',
                  style: AppTypography.display(
                    fontSize: 18,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cancelling will discard elapsed focus time and no token reward will be awarded.',
                  style: AppTypography.label(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: palette.secondaryText,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Keep Focusing',
                        style: AppTypography.button(fontSize: 14, color: palette.primaryText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // close dialog
                        controller.cancelFocusSession();
                        Navigator.of(context).pop(); // close screen
                      },
                      child: Text(
                        'Abandon',
                        style: AppTypography.button(fontSize: 14, color: palette.deadlineAlertCoral),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
