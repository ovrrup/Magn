import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magn/models/app_models.dart';
import 'package:magn/services/flow_engine.dart';
import 'package:magn/services/token_calculator.dart';
import 'package:magn/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenCalculator Unit Tests', () {
    test('Base rate awards 1 token per full minute', () {
      final reward = TokenCalculator.calculate(
        elapsedSeconds: 25 * 60,
        flowThresholdMinutes: null,
        hasSufficientSessionsForFlow: false,
        windowMultiplier: 1.0,
        isCancelled: false,
      );
      expect(reward.totalTokens, 25);
      expect(reward.baseTokens, 25);
      expect(reward.flowTokens, 0);
      expect(reward.windowMultiplier, 1.0);
    });

    test('Inside preferred window awards 1.25x bonus multiplier', () {
      final reward = TokenCalculator.calculate(
        elapsedSeconds: 20 * 60,
        flowThresholdMinutes: null,
        hasSufficientSessionsForFlow: false,
        windowMultiplier: 1.25,
        isCancelled: false,
      );
      // 20 * 1.25 = 25
      expect(reward.totalTokens, 25);
      expect(reward.windowMultiplier, 1.25);
    });

    test('After preferred window applies 0.75x penalty multiplier', () {
      final reward = TokenCalculator.calculate(
        elapsedSeconds: 20 * 60,
        flowThresholdMinutes: null,
        hasSufficientSessionsForFlow: false,
        windowMultiplier: 0.75,
        isCancelled: false,
      );
      // 20 * 0.75 = 15
      expect(reward.totalTokens, 15);
      expect(reward.windowMultiplier, 0.75);
    });

    test('Flow Zone 1.5x multiplier applies only beyond threshold', () {
      // 30 min duration with 20 min flow threshold
      // Pre-threshold: 20 min * 1.0 = 20
      // Flow zone: 10 min * 1.5 = 15
      // Subtotal = 35. With inside window 1.25x: 35 * 1.25 = 43.75 -> 43
      final reward = TokenCalculator.calculate(
        elapsedSeconds: 30 * 60,
        flowThresholdMinutes: 20.0,
        hasSufficientSessionsForFlow: true,
        windowMultiplier: 1.25,
        isCancelled: false,
      );
      expect(reward.baseTokens, 25);
      expect(reward.flowTokens, 18);
      expect(reward.totalTokens, 43); // floor(35 * 1.25)
    });

    test('Single integer rounding floor at end avoids premature fractional rounding', () {
      // 15 min duration * 1.25 = 18.75 -> 18
      final reward = TokenCalculator.calculate(
        elapsedSeconds: 15 * 60,
        flowThresholdMinutes: null,
        hasSufficientSessionsForFlow: false,
        windowMultiplier: 1.25,
        isCancelled: false,
      );
      expect(reward.totalTokens, 18);
    });
  });

  group('FlowEngine Unit Tests', () {
    test('Requires at least 5 completed sessions to establish Flow Threshold', () {
      final now = DateTime.now();
      final fourSessions = List.generate(
        4,
        (i) => CompletedSession(
          id: 's$i',
          topicTitle: 'Deep Work',
          completedAtIso: now.subtract(Duration(days: i, minutes: 25)).toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.25,
        ),
      );

      final profile = FlowEngine.evaluateProfile(
        completedSessions: fourSessions,
        plannedSessions: [],
      );
      expect(profile.hasSufficientData, isFalse);
      expect(profile.flowReadinessPercent, greaterThan(0));
    });

    test('Calculates inflection threshold when 5 or more sessions exist', () {
      final now = DateTime.now();
      final sessions = [
        CompletedSession(
          id: '1',
          topicTitle: 'Dev',
          completedAtIso: now.subtract(const Duration(days: 4, minutes: 20)).toIso8601String(),
          durationSeconds: 20 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.25,
        ),
        CompletedSession(
          id: '2',
          topicTitle: 'Dev',
          completedAtIso: now.subtract(const Duration(days: 3, minutes: 25)).toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 31,
          multiplierApplied: 1.25,
        ),
        CompletedSession(
          id: '3',
          topicTitle: 'Dev',
          completedAtIso: now.subtract(const Duration(days: 2, minutes: 35)).toIso8601String(),
          durationSeconds: 35 * 60,
          tokensEarned: 43,
          multiplierApplied: 1.25,
        ),
        CompletedSession(
          id: '4',
          topicTitle: 'Dev',
          completedAtIso: now.subtract(const Duration(days: 1, minutes: 40)).toIso8601String(),
          durationSeconds: 40 * 60,
          tokensEarned: 50,
          multiplierApplied: 1.25,
        ),
        CompletedSession(
          id: '5',
          topicTitle: 'Dev',
          completedAtIso: now.toIso8601String(),
          durationSeconds: 45 * 60,
          tokensEarned: 56,
          multiplierApplied: 1.25,
        ),
      ];

      final profile = FlowEngine.evaluateProfile(
        completedSessions: sessions,
        plannedSessions: [],
      );
      expect(profile.hasSufficientData, isTrue);
      expect(profile.flowEntryThresholdMinutes, inInclusiveRange(10, 25));
      expect(profile.flowReadinessPercent, inInclusiveRange(0, 95));
    });
  });

  group('AppController Dynamic Streak Calculation Tests', () {
    late AppController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = AppController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Calculates streak consecutively backwards from local calendar dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      // Initially empty: 0 streak
      expect(controller.currentStreak, 0);

      // Add session today and yesterday
      controller.addCompletedSessionForTesting(
        CompletedSession(
          id: 's-today',
          topicTitle: 'Focus',
          completedAtIso: today.toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.0,
        ),
      );
      controller.addCompletedSessionForTesting(
        CompletedSession(
          id: 's-yesterday',
          topicTitle: 'Focus',
          completedAtIso: yesterday.toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.0,
        ),
      );
      controller.addCompletedSessionForTesting(
        CompletedSession(
          id: 's-2days',
          topicTitle: 'Focus',
          completedAtIso: twoDaysAgo.toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.0,
        ),
      );

      expect(controller.calculateDynamicStreak(), 3);
    });

    test('Streak breaks if a calendar day was skipped', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      // Three days ago (skipped yesterday and 2 days ago)
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      controller.addCompletedSessionForTesting(
        CompletedSession(
          id: 's-today',
          topicTitle: 'Focus',
          completedAtIso: today.toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.0,
        ),
      );
      controller.addCompletedSessionForTesting(
        CompletedSession(
          id: 's-old',
          topicTitle: 'Focus',
          completedAtIso: threeDaysAgo.toIso8601String(),
          durationSeconds: 25 * 60,
          tokensEarned: 25,
          multiplierApplied: 1.0,
        ),
      );

      expect(controller.calculateDynamicStreak(), 1);
    });
  });

  group('Backup and Restore Roundtrip Tests', () {
    late AppController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = AppController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Exports JSON with schema version serene_sky_backup_v2', () {
      final jsonStr = controller.exportBackupJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['schemaVersion'], 'serene_sky_backup_v2');
      expect(map.containsKey('exportedAt'), isTrue);
      expect(map.containsKey('plannedSessions'), isTrue);
      expect(map.containsKey('completedSessions'), isTrue);
      expect(map.containsKey('goals'), isTrue);
      expect(map.containsKey('walletTokenBalance'), isTrue);
      expect(map.containsKey('settings'), isTrue);
    });

    test('Restores JSON backup accurately and rejects corrupted data', () async {
      final validBackup = jsonEncode({
        'schemaVersion': 'serene_sky_backup_v2',
        'exportedAt': DateTime.now().toIso8601String(),
        'walletTokenBalance': 150,
        'plannedSessions': [
          {
            'id': 'p1',
            'topic': 'Cloud Architecture',
            'plannedDurationMinutes': 45,
            'preferredWindow': {
              'startHour': 9,
              'startMinute': 0,
              'endHour': 11,
              'endMinute': 0,
            },
            'createdAt': DateTime.now().toIso8601String(),
            'isCompleted': false,
          }
        ],
        'completedSessions': [],
        'goals': [],
        'settings': {
          'precisionShowCentiseconds': true,
          'themeMode': 'midnightSky',
        },
      });

      final success = await controller.importBackupJson(validBackup, overwrite: true);
      expect(success, isTrue);
      expect(controller.walletTokenBalance, 150);
      expect(controller.plannedSessions.length, 1);
      expect(controller.plannedSessions.first.topic, 'Cloud Architecture');
      expect(controller.settings.precisionEnabled, isTrue);

      // Rejects invalid schema or malformed JSON
      const invalidBackup = '{"schemaVersion": "unsupported_v99"}';
      final failResult = await controller.importBackupJson(invalidBackup, overwrite: false);
      expect(failResult, isFalse);
    });
  });
}
