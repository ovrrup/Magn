import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/time_formatter.dart';

/// Tabular-figured high-precision timer display widget.
class TimerDisplay extends StatelessWidget {
  final int elapsedSeconds;
  final int elapsedMilliseconds;
  final bool showMilliseconds;
  final VoidCallback? onTap;

  const TimerDisplay({
    super.key,
    required this.elapsedSeconds,
    required this.elapsedMilliseconds,
    this.showMilliseconds = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = TimeFormatter.formatElapsedSeconds(elapsedSeconds);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: AppDimensions.timerFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warmCream,
                    fontFeatures: [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (showMilliseconds) ...[
                  const SizedBox(width: 4),
                  Text(
                    '.${((elapsedMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: AppDimensions.timerMsFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warmCream.withValues(alpha: 0.8),
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
