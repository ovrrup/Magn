import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/lap_model.dart';

/// Scrollable lap split list with fastest and slowest lap highlighting.
class LapListView extends StatelessWidget {
  final List<LapModel> laps;
  final LapModel? fastestLap;
  final LapModel? slowestLap;

  const LapListView({
    super.key,
    required this.laps,
    this.fastestLap,
    this.slowestLap,
  });

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return const SizedBox.shrink();
    }

    final reversedLaps = laps.reversed.toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.creamTranslucent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warmCream.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: reversedLaps.length,
        separatorBuilder: (_, __) => Divider(
          color: AppColors.warmCream.withValues(alpha: 0.15),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final lap = reversedLaps[index];
          final isFastest = fastestLap != null && lap == fastestLap;
          final isSlowest = slowestLap != null && lap == slowestLap;

          Color textColor = AppColors.warmCream;
          if (isFastest) textColor = AppColors.lapFastest;
          if (isSlowest) textColor = AppColors.lapSlowest;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: 6.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lap ${lap.lapNumber.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  '+${TimeFormatter.formatLapTime(lap.splitTimeMs)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  TimeFormatter.formatLapTime(lap.totalTimeMs),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.warmCream.withValues(alpha: 0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
