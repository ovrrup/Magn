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
      expect(reward.baseTokens, 20);
      expect(reward.flowTokens, 15);
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
          topic: 'Deep Work',
          startTime: now.subtract(Duration(days: i, minutes: 25)),
          endTime: now.subtract(Duration(days: i)),
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 25,
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
          topic: 'Dev',
          startTime: now.subtract(const Duration(days: 4, minutes: 20)),
          endTime: now.subtract(const Duration(days: 4)),
          elapsedSeconds: 20 * 60,
          baseTokens: 20,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 25,
        ),
        CompletedSession(
          id: '2',
          topic: 'Dev',
          startTime: now.subtract(const Duration(days: 3, minutes: 25)),
          endTime: now.subtract(const Duration(days: 3)),
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 31,
        ),
        CompletedSession(
          id: '3',
          topic: 'Dev',
          startTime: now.subtract(const Duration(days: 2, minutes: 35)),
          endTime: now.subtract(const Duration(days: 2)),
          elapsedSeconds: 35 * 60,
          baseTokens: 35,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 43,
        ),
        CompletedSession(
          id: '4',
          topic: 'Dev',
          startTime: now.subtract(const Duration(days: 1, minutes: 40)),
          endTime: now.subtract(const Duration(days: 1)),
          elapsedSeconds: 40 * 60,
          baseTokens: 40,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 50,
        ),
        CompletedSession(
          id: '5',
          topic: 'Dev',
          startTime: now.subtract(const Duration(minutes: 45)),
          endTime: now,
          elapsedSeconds: 45 * 60,
          baseTokens: 45,
          flowTokens: 0,
          windowMultiplier: 1.25,
          totalTokensEarned: 56,
        ),
      ];

      final profile = FlowEngine.evaluateProfile(
        completedSessions: sessions,
        plannedSessions: [],
      );
      expect(profile.hasSufficientData, isTrue);
      expect(profile.flowEntryThresholdMinutes, inInclusiveRange(15, 35));
      expect(profile.flowReadinessPercent, inInclusiveRange(10, 99));
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
      controller.completedSessions.addAll([
        CompletedSession(
          id: 's-today',
          topic: 'Focus',
          startTime: today.subtract(const Duration(minutes: 25)),
          endTime: today,
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.0,
          totalTokensEarned: 25,
        ),
        CompletedSession(
          id: 's-yesterday',
          topic: 'Focus',
          startTime: yesterday.subtract(const Duration(minutes: 25)),
          endTime: yesterday,
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.0,
          totalTokensEarned: 25,
        ),
        CompletedSession(
          id: 's-2days',
          topic: 'Focus',
          startTime: twoDaysAgo.subtract(const Duration(minutes: 25)),
          endTime: twoDaysAgo,
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.0,
          totalTokensEarned: 25,
        ),
      ]);

      expect(controller.calculateDynamicStreak(), 3);
    });

    test('Streak breaks if a calendar day was skipped', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      // Three days ago (skipped yesterday and 2 days ago)
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      controller.completedSessions.addAll([
        CompletedSession(
          id: 's-today',
          topic: 'Focus',
          startTime: today.subtract(const Duration(minutes: 25)),
          endTime: today,
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.0,
          totalTokensEarned: 25,
        ),
        CompletedSession(
          id: 's-old',
          topic: 'Focus',
          startTime: threeDaysAgo.subtract(const Duration(minutes: 25)),
          endTime: threeDaysAgo,
          elapsedSeconds: 25 * 60,
          baseTokens: 25,
          flowTokens: 0,
          windowMultiplier: 1.0,
          totalTokensEarned: 25,
        ),
      ]);

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
            'plannedMinutes': 45,
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
          'precisionEnabled': true,
          'themePalette': 'midnightSky',
        },
      });

      final success = await controller.importBackupJson(validBackup, overwrite: true);
      expect(success, isTrue);
      expect(controller.walletTokenBalance, 150);
      expect(controller.plannedSessions.length, 1);
      expect(controller.plannedSessions.first.topic, 'Cloud Architecture');
      expect(controller.settings.precisionEnabled, isTrue);

      // Rejects invalid schema or malformed JSON
      final invalidBackup = '{"schemaVersion": "unsupported_v99"}';
      final failResult = await controller.importBackupJson(invalidBackup);
      expect(failResult, isFalse);
    });
  });
}
