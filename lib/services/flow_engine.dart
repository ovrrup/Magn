import 'dart:math' as math;
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

    // Partition into early bailouts (< 20m) vs sustained sessions (>= 20m)
    final earlyBailouts = durationsMinutes.where((d) => d < 20.0).toList();
    final sustainedSessions = durationsMinutes.where((d) => d >= 20.0).toList();

    double calculatedThreshold = defaultThresholdMinutes;

    if (sustainedSessions.isNotEmpty) {
      if (earlyBailouts.isNotEmpty) {
        // Find the 80th percentile of early drop-offs
        final index = (earlyBailouts.length * 0.80).clamp(0, earlyBailouts.length - 1).toInt();
        calculatedThreshold = earlyBailouts[index];
      } else {
        // No early drop-offs logged; use lower quartile of sustained sessions
        final index = (sustainedSessions.length * 0.25).clamp(0, sustainedSessions.length - 1).toInt();
        calculatedThreshold = sustainedSessions[index];
      }
    }

    // Clamp personal threshold within reasonable bounds [10m, 25m]
    calculatedThreshold = calculatedThreshold.clamp(10.0, 25.0);

    // Calculate Flow Readiness %
    final readiness = _calculateReadiness(
      validSessions: validSessions,
      plannedSessions: plannedSessions,
      thresholdMinutes: calculatedThreshold,
    );

    String label;
    if (readiness >= 75.0) {
      label = 'High Likelihood';
    } else if (readiness >= 50.0) {
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

  /// Calculates Flow Readiness % based on session recency, regularity, and completion.
  static double _calculateReadiness({
    required List<CompletedSession> validSessions,
    required List<PlannedSession> plannedSessions,
    required double thresholdMinutes,
  }) {
    if (validSessions.isEmpty) return 40.0;

    double score = 20.0; // Baseline

    // 1. Recency of latest session (Max 35 points)
    final latest = validSessions.reduce((a, b) => a.endTime.isAfter(b.endTime) ? a : b);
    final hoursSince = DateTime.now().difference(latest.endTime).inHours;

    if (hoursSince <= 18) {
      score += 35.0;
    } else if (hoursSince <= 36) {
      score += 25.0;
    } else if (hoursSince <= 60) {
      score += 15.0;
    } else {
      score += 5.0;
    }

    // 2. Planning and Completion Integrity (Max 25 points)
    if (plannedSessions.isNotEmpty) {
      final completedPlanned = plannedSessions.where((p) => p.isCompleted).length;
      final completionRatio = completedPlanned / plannedSessions.length;
      score += (completionRatio * 25.0);
    } else {
      score += 15.0;
    }

    // 3. Sustained Flow Frequency (Max 20 points)
    final flowSessions = validSessions
        .where((s) => (s.elapsedSeconds / 60.0) >= thresholdMinutes)
        .length;
    final flowRatio = flowSessions / validSessions.length;
    score += (flowRatio * 20.0);

    return score.clamp(15.0, 95.0);
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
