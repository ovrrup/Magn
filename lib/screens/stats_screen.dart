import 'package:flutter/material.dart';
import '../models/app_models.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          const SizedBox(height: 8),

          // Header
          Text(
            'Consistency & Telemetry',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.primaryText,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dynamic cadence history and focus consistency metrics.',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 13,
              color: palette.secondaryText,
            ),
          ),

          const SizedBox(height: 16),

          // 1. Three Calm Summary Cards
          _buildSummaryCards(controller, totalFocusHours, palette),

          const SizedBox(height: 16),

          // 2. GitHub-Style Multi-Week Consistency Heatmap Grid
          _buildHeatmapCard(controller, palette),

          const SizedBox(height: 18),

          // 3. Chronological Session History List
          _buildSessionHistorySection(controller, palette),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AppController controller, String totalFocusHours, SkyPalette palette) {
    return Row(
      children: [
        // Active Streak Card
        Expanded(
          child: SkyGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE STREAK',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: palette.secondaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Text(
                        '${controller.currentStreak}',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: palette.amberGold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Days',
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
                const SizedBox(height: 2),
                Text(
                  'Consecutive',
                  style: TextStyle(fontFamily: 'sans-serif', fontSize: 11, color: palette.secondaryText),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Total Tokens Card
        Expanded(
          child: SkyGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL TOKENS',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: palette.secondaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Text(
                        '${controller.walletTokenBalance}',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: palette.primaryText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.auto_awesome_rounded, color: palette.amberGold, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wallet Balance',
                  style: TextStyle(fontFamily: 'sans-serif', fontSize: 11, color: palette.secondaryText),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Total Focus Hours Card
        Expanded(
          child: SkyGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL FOCUS',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: palette.secondaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Text(
                        '${totalFocusHours}h',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: palette.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Completed Time',
                  style: TextStyle(fontFamily: 'sans-serif', fontSize: 11, color: palette.secondaryText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Multi-week GitHub-style Consistency Heatmap Grid.
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
    final totalDays = weeksCount * 7;
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: totalDays - 1));

    return SkyGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Focus Consistency Matrix',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
              Text(
                'Last 12 Weeks',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Scrollable Grid Layout
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(weeksCount, (weekIdx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    children: List.generate(7, (dayIdx) {
                      final dayOffset = (weekIdx * 7) + dayIdx;
                      final dayDate = startDate.add(Duration(days: dayOffset));
                      final key = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
                      final minutes = dailyMinutesMap[key] ?? 0;

                      return Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(vertical: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _getHeatmapColor(minutes, palette),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.5,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chronological Session History',
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.primaryText,
          ),
        ),
        const SizedBox(height: 10),

        if (sessions.isEmpty)
          SkyGlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Text(
                'No completed sessions logged yet.\nComplete focus sessions to see historical telemetry.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: palette.secondaryText, height: 1.3),
              ),
            ),
          )
        else
          ...sessions.map((s) {
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
