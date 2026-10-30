import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// Control action buttons for starting, stopping, and recording lap splits.
class ControlButtons extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onToggle;
  final VoidCallback onLap;
  final bool hasLaps;

  const ControlButtons({
    super.key,
    required this.isRunning,
    required this.onToggle,
    required this.onLap,
    this.hasLaps = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRunning) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: TextButton.icon(
              onPressed: onLap,
              icon: const Icon(
                Icons.flag_rounded,
                size: 20,
                color: AppColors.warmCream,
              ),
              label: const Text(
                'LAP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.warmCream,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.creamTranslucent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
        ElevatedButton(
          onPressed: onToggle,
          style: ElevatedButton.styleFrom(
            backgroundColor: isRunning ? AppColors.warmCream : AppColors.deepRed,
            foregroundColor: isRunning ? AppColors.deepRed : AppColors.warmCream,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.buttonPaddingHorizontal,
              vertical: AppDimensions.buttonPaddingVertical,
            ),
            shape: StadiumBorder(
              side: isRunning
                  ? const BorderSide(color: AppColors.deepRed, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            isRunning ? 'STOP' : 'START',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isRunning ? AppColors.deepRed : AppColors.warmCream,
            ),
          ),
        ),
      ],
    );
  }
}
