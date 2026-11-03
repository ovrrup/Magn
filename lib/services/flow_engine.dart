import '../models/app_models.dart';

/// Hidden Background Flow State Engine.
///
/// Silently analyzes historical completed session durations to compute:
/// 1. Personal Flow Entry Threshold ($T_{flow}$): Identifies the inflection point
///    where early session drop-offs subside into sustained deep focus. Requires $\ge 5$ sessions.
/// 2. Flow Readiness Percentage: An estimated likelihood (0-100%) of entering Flow State,
///    calibrated against recent regularity, session completion cadence, and historical depth.
class FlowEngine {
  static const int minSessionsRequired = 5;
  static const double defaultThresholdMinutes = 15.0;

  /// Analyzes historical session records to discover personal Flow Entry Threshold.
  static FlowStateProfile evaluateProfile({
    required List<CompletedSession> completedSessions,
    required List<PlannedSession> plannedSessions,
  }) {
    final validSessions = completedSessions
        .where((s) => !s.isCancelled && s.elapsedSeconds >= 60)
        .toList();

    if (validSessions.length < minSessionsRequired) {
      final readiness = _estimateReadinessWithInsufficientData(
        validSessions: validSessions,
        plannedSessions: plannedSessions,
      );
      return FlowStateProfile(
        flowEntryThresholdMinutes: defaultThresholdMinutes,
        flowReadinessPercent: readiness,
        hasSufficientData: false,
        readinessLabel: 'Calibrating ($minSessionsRequired sessions needed)',
      );
    }

    // Mathematical inflection detection across completed durations
    final durationsMinutes = validSessions
        .map((s) => s.elapsedSeconds / 60.0)
        .toList()
      ..sort();

    // Partition into early bailouts (< 25m) vs sustained sessions (>= 25m)
    final earlyBailouts = durationsMinutes.where((d) => d < 25.0).toList();
    final sustainedSessions = durationsMinutes.where((d) => d >= 25.0).toList();

    double calculatedThreshold = defaultThresholdMinutes;

    if (earlyBailouts.isNotEmpty) {
      // Find the 85th percentile of early drop-offs
      final index = (earlyBailouts.length * 0.85).clamp(0, earlyBailouts.length - 1).toInt();
      calculatedThreshold = earlyBailouts[index];
    } else if (sustainedSessions.isNotEmpty) {
      // No early drop-offs logged; use lower quartile of sustained sessions
      final index = (sustainedSessions.length * 0.25).clamp(0, sustainedSessions.length - 1).toInt();
      calculatedThreshold = sustainedSessions[index];
    }

    // Clamp personal threshold within reasonable bounds [10m, 25m]
    calculatedThreshold = calculatedThreshold.clamp(10.0, 25.0);

    // Calculate Flow Readiness % (0 to 95%) based on recent completion rate exceeding threshold
    final recent = validSessions.length > 10 ? validSessions.sublist(0, 10) : validSessions;
    final exceeding = recent.where((s) => (s.elapsedSeconds / 60.0) >= calculatedThreshold).length;
    final completionRate = exceeding / recent.length;
    final readiness = (completionRate * 95.0).clamp(0.0, 95.0);

    String label;
    if (readiness >= 75.0) {
      label = 'High Likelihood';
    } else if (readiness >= 45.0) {
      label = 'Moderate Likelihood';
    } else {
      label = 'Building Cadence';
    }

    return FlowStateProfile(
      flowEntryThresholdMinutes: calculatedThreshold,
      flowReadinessPercent: readiness,
      hasSufficientData: true,
      readinessLabel: label,
    );
  }

  static double _estimateReadinessWithInsufficientData({
    required List<CompletedSession> validSessions,
    required List<PlannedSession> plannedSessions,
  }) {
    if (validSessions.isEmpty) return 45.0;
    final count = validSessions.length;
    return (40.0 + (count * 6.0)).clamp(40.0, 70.0);
  }
}
