import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../controllers/stopwatch_controller.dart';
import '../widgets/control_buttons.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/lap_list_view.dart';
import '../widgets/timer_display.dart';
import 'history_bottom_sheet.dart';

/// Primary stopwatch presentation screen.
class StopwatchScreen extends StatelessWidget {
  final StopwatchController controller;

  const StopwatchScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return GradientScaffold(
          child: Stack(
            children: [
              // Top Navigation Header
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Tagline
                      TextButton.icon(
                        onPressed: controller.toggleMilliseconds,
                        icon: Icon(
                          controller.showMilliseconds
                              ? Icons.timer_outlined
                              : Icons.timer_off_outlined,
                          size: 18,
                          color: AppColors.warmCream.withValues(alpha: 0.8),
                        ),
                        label: Text(
                          controller.showMilliseconds ? 'PRECISION' : 'STANDARD',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warmCream.withValues(alpha: 0.9),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.creamTranslucent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                      // History Modal Action
                      IconButton(
                        iconSize: AppDimensions.topIconSize,
                        color: AppColors.warmCream,
                        icon: const Icon(
                          Icons.history_rounded,
                          size: AppDimensions.topIconSize,
                          color: AppColors.warmCream,
                        ),
                        onPressed: () => HistoryBottomSheet.show(
                          context,
                          controller: controller,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Central Elapsed Time Display
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TimerDisplay(
                      elapsedSeconds: controller.elapsedSeconds,
                      elapsedMilliseconds: controller.elapsedMilliseconds,
                      showMilliseconds: controller.showMilliseconds,
                      onTap: controller.toggleMilliseconds,
                    ),
                    if (controller.laps.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.md),
                      LapListView(
                        laps: controller.laps,
                        fastestLap: controller.fastestLap,
                        slowestLap: controller.slowestLap,
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom Control Pill Button (64px offset)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.bottomButtonOffset,
                  ),
                  child: ControlButtons(
                    isRunning: controller.isRunning,
                    onToggle: controller.toggle,
                    onLap: controller.recordLap,
                    hasLaps: controller.laps.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
