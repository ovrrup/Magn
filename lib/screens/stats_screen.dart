import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/sky_glass_widgets.dart';

/// Tab 3: Stats Screen (Serene Sky Sanctuary).
///
/// Features:
/// - Three calm summary cards: Active Streak, Total Tokens, Total Focus Hours.
/// - GitHub-style multi-week Consistency Heatmap Grid with intensity-shaded rounded squares.
/// - Chronological Session History list displaying actual application records.
/// - Dynamically recalculated streak from local timezone calendar dates.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final controller = AppControllerScope.of(context);

    // Calculate actual cumulative focus time
    final totalFocusSeconds = controller.completedSessions
        .where((s) => !s.isCancelled)
        .fold<int>(0, (sum, s) => sum + s.elapsedSeconds);
    final totalFocusHours = (totalFocusSeconds / 3600.0).toStringAsFixed(1);

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 32.0),
        children: [
          // 1. Three Calm Summary Cards (fixed 82px height, 10px gap)
          _buildSummaryCards(controller, totalFocusHours, palette),

          const SizedBox(height: 16),

          // 2. GitHub-Style Multi-Week Consistency Heatmap Grid (dynamic edge-to-edge)
          _buildHeatmapCard(controller, palette),

          const SizedBox(height: 18),

          // 3. Recent Sessions List (or SizedBox.shrink() when empty)
          _buildSessionHistorySection(controller, palette),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AppController controller, String totalFocusHours, SkyPalette palette) {
    return Row(
      children: [
        // Active Streak Card (82px fixed height)
        Expanded(
          child: SizedBox(
            height: 82,
            child: SkyGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STREAK',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.secondaryText,
                      letterSpacing: 0.8,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${controller.currentStreak}d',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: palette.amberGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Total Tokens Card (82px fixed height)
        Expanded(
          child: SizedBox(
            height: 82,
            child: SkyGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOKENS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.secondaryText,
                      letterSpacing: 0.8,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${controller.walletTokenBalance}',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Total Focus Hours Card (82px fixed height)
        Expanded(
          child: SizedBox(
            height: 82,
            child: SkyGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HOURS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.secondaryText,
                      letterSpacing: 0.8,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${totalFocusHours}h',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
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

  /// Multi-week GitHub-style Consistency Heatmap Grid stretching edge-to-edge dynamically.
  Widget _buildHeatmapCard(AppController controller, SkyPalette palette) {
    // Map sessions into daily intensity (minutes per day)
    final dailyMinutesMap = <String, int>{};
    for (final s in controller.completedSessions) {
      if (s.isCancelled) continue;
      final key = '${s.endTime.year}-${s.endTime.month.toString().padLeft(2, '0')}-${s.endTime.day.toString().padLeft(2, '0')}';
      dailyMinutesMap[key] = (dailyMinutesMap[key] ?? 0) + s.elapsedMinutes;
    }

    final now = DateTime.now();
    const weeksCount = 12;
    const totalDays = weeksCount * 7;
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: totalDays - 1));

    return SkyGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '12 Weeks',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Edge-to-edge dynamic LayoutBuilder grid
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              const columns = 12;
              const rows = 7;
              const gap = 4.0;
              final squareSize = ((availableWidth - ((columns - 1) * gap)) / columns).clamp(8.0, 36.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(columns, (weekIdx) {
                  return Column(
                    children: List.generate(rows, (dayIdx) {
                      final dayOffset = (weekIdx * 7) + dayIdx;
                      final dayDate = startDate.add(Duration(days: dayOffset));
                      final key =
                          '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
                      final minutes = dailyMinutesMap[key] ?? 0;

                      return Container(
                        width: squareSize,
                        height: squareSize,
                        margin: EdgeInsets.only(bottom: dayIdx < rows - 1 ? gap : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _getHeatmapColor(minutes, palette),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.5,
                          ),
                        ),
                      );
                    }),
                  );
                }),
              );
            },
          ),

          const SizedBox(height: 12),

          // Heatmap Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(fontSize: 10, color: palette.secondaryText),
              ),
              const SizedBox(width: 6),
              _buildLegendSquare(Colors.white.withOpacity(0.08)),
              const SizedBox(width: 4),
              _buildLegendSquare(palette.mintAura.withOpacity(0.35)),
              const SizedBox(width: 4),
              _buildLegendSquare(palette.mintAura.withOpacity(0.70)),
              const SizedBox(width: 4),
              _buildLegendSquare(palette.mintAura),
              const SizedBox(width: 6),
              Text(
                'More',
                style: TextStyle(fontSize: 10, color: palette.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(int minutes, SkyPalette palette) {
    if (minutes == 0) {
      return Colors.white.withOpacity(palette.isDark ? 0.05 : 0.10);
    } else if (minutes < 25) {
      return palette.mintAura.withOpacity(0.35);
    } else if (minutes < 50) {
      return palette.mintAura.withOpacity(0.70);
    } else {
      return palette.mintAura;
    }
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSessionHistorySection(AppController controller, SkyPalette palette) {
    final sessions = controller.completedSessions;
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.primaryText,
          ),
        ),
        const SizedBox(height: 10),
            final dateStr = '${s.endTime.month}/${s.endTime.day} • ${s.endTime.hour.toString().padLeft(2, '0')}:${s.endTime.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SkyGlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Icon(
                        s.isCancelled ? Icons.close_rounded : Icons.check_rounded,
                        color: s.isCancelled ? palette.deadlineAlertCoral : palette.mintAura,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.topic,
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.elapsedMinutes}m Focus • ${s.windowMultiplier}x Window',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 11,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${s.totalTokensEarned} Tokens',
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.amberGold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 10,
                            color: palette.secondaryText.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
