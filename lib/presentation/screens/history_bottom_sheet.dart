import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/session_model.dart';
import '../controllers/stopwatch_controller.dart';

/// Modal bottom sheet displaying chronological session history, lap breakdowns, and session management.
class HistoryBottomSheet extends StatelessWidget {
  final StopwatchController controller;

  const HistoryBottomSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required StopwatchController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.warmCream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.bottomSheetRadius),
        ),
      ),
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HistoryBottomSheet(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sessions;
    final reversedSessions = sessions.reversed.toList();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.lg,
                AppDimensions.lg,
                AppDimensions.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: AppDimensions.headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepRed,
                    ),
                  ),
                  if (sessions.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmClearAll(context),
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        size: 18,
                        color: AppColors.coralPink,
                      ),
                      label: const Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.coralPink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(
              color: AppColors.coralTranslucent,
              height: 1,
            ),
            if (sessions.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No sessions recorded',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.coralPink,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  itemCount: reversedSessions.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: AppColors.coralPink,
                    height: 1,
                    thickness: 0.5,
                  ),
                  itemBuilder: (context, index) {
                    final session = reversedSessions[index];
                    return _buildSessionTile(context, session);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, SessionModel session) {
    final hasLaps = session.laps.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    TimeFormatter.formatDuration(session.durationInSeconds),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.itemTitleFontSize,
                      color: AppColors.deepRed,
                    ),
                  ),
                  if (hasLaps) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coralTranslucent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${session.laps.length} laps',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepRed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    TimeFormatter.formatTimestamp(session.timestamp),
                    style: const TextStyle(
                      fontSize: AppDimensions.itemSubtitleFontSize,
                      color: AppColors.coralPink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.coralPink,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => controller.deleteSession(session.id),
                  ),
                ],
              ),
            ],
          ),
          if (hasLaps) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: session.laps.take(4).map((lap) {
                return Text(
                  'L${lap.lapNumber}: ${TimeFormatter.formatLapTime(lap.splitTimeMs)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.deepRed.withValues(alpha: 0.75),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.warmCream,
        title: const Text(
          'Clear History?',
          style: TextStyle(
            color: AppColors.deepRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete all recorded stopwatch sessions.',
          style: TextStyle(color: AppColors.deepRed),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.coralPink),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              controller.clearAllHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepRed,
              foregroundColor: AppColors.warmCream,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
