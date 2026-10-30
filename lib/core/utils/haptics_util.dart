import 'package:flutter/services.dart';

/// Haptic and tactile feedback utility for stopwatch interactions.
class HapticsUtil {
  HapticsUtil._();

  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Gracefully ignore on unsupported platforms or during tests
    }
  }

  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Gracefully ignore on unsupported platforms or during tests
    }
  }

  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Gracefully ignore on unsupported platforms or during tests
    }
  }

  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Gracefully ignore on unsupported platforms or during tests
    }
  }
}
