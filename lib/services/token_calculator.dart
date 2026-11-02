import 'dart:math' as math;

/// Token Calculation Result Breakdown.
class TokenRewardBreakdown {
  final int baseTokens;
  final int flowTokens;
  final double windowMultiplier;
  final int totalTokens;
  final double elapsedMinutes;
  final double flowMinutes;
  final bool isFlowMultiplierActive;

  const TokenRewardBreakdown({
    required this.baseTokens,
    required this.flowTokens,
    required this.windowMultiplier,
    required this.totalTokens,
    required this.elapsedMinutes,
    required this.flowMinutes,
    required this.isFlowMultiplierActive,
  });
}

/// Token Calculator for Focus Sessions.
///
/// Implements deterministic reward calculations:
/// - Base: 1 token per focus minute.
/// - Flow Zone: 1.5x multiplier for minutes beyond personal Flow Entry Threshold (after $\ge 5$ sessions).
/// - Window Multiplier: 1.25x (Inside), 1.0x (Before), 0.75x (After).
/// - Multiplicative combination, rounded down (.floor()) exactly once at completion.
class TokenCalculator {
  static const double flowMultiplier = 1.5;

  /// Calculates token reward from actual elapsed seconds.
  static TokenRewardBreakdown calculate({
    required int elapsedSeconds,
    required double? flowThresholdMinutes,
    required bool hasSufficientSessionsForFlow,
    required double windowMultiplier,
    required bool isCancelled,
  }) {
    // Cancelled or sessions with less than 60 seconds earn 0 tokens
    if (isCancelled || elapsedSeconds < 60) {
      return TokenRewardBreakdown(
        baseTokens: 0,
        flowTokens: 0,
        windowMultiplier: windowMultiplier,
        totalTokens: 0,
        elapsedMinutes: elapsedSeconds / 60.0,
        flowMinutes: 0.0,
        isFlowMultiplierActive: false,
      );
    }

    final totalMinutes = elapsedSeconds / 60.0;
    double regularMinutes = totalMinutes;
    double flowMinutes = 0.0;
    bool isFlowActive = false;

    if (hasSufficientSessionsForFlow &&
        flowThresholdMinutes != null &&
        totalMinutes > flowThresholdMinutes) {
      isFlowActive = true;
      regularMinutes = flowThresholdMinutes;
      flowMinutes = totalMinutes - flowThresholdMinutes;
    }

    // Base tokens: 1.0 per minute for regular minutes
    final rawBase = regularMinutes * 1.0;
    // Flow tokens: 1.5 per minute for flow minutes
    final rawFlow = flowMinutes * flowMultiplier;

    final unmultipliedTotal = rawBase + rawFlow;
    final finalMultiplied = unmultipliedTotal * windowMultiplier;

    final totalTokensEarned = math.max(0, finalMultiplied.floor());
    final baseTokensFloored = math.max(0, (rawBase * windowMultiplier).floor());
    final flowTokensFloored = math.max(0, totalTokensEarned - baseTokensFloored);

    return TokenRewardBreakdown(
      baseTokens: baseTokensFloored,
      flowTokens: flowTokensFloored,
      windowMultiplier: windowMultiplier,
      totalTokens: totalTokensEarned,
      elapsedMinutes: totalMinutes,
      flowMinutes: flowMinutes,
      isFlowMultiplierActive: isFlowActive,
    );
  }
}
