import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../services/flow_engine.dart';
import '../services/token_calculator.dart';
import '../theme/sky_theme.dart';

/// Central reactive systems controller and state coordinator for Serene Sky Sanctuary.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  static const String _prefKeyPlanned = 'serene_sky_planned_v2';
  static const String _prefKeyCompleted = 'serene_sky_completed_v2';
  static const String _prefKeyGoals = 'serene_sky_goals_v2';
  static const String _prefKeyWallet = 'serene_sky_wallet_v2';
  static const String _prefKeySettings = 'serene_sky_settings_v2';
  static const String backupSchemaVersion = 'serene_sky_backup_v2';

  // --- Core Collections ---
  List<PlannedSession> _plannedSessions = [];
  List<CompletedSession> _completedSessions = [];
  List<Goal> _goals = [];
  int _walletTokenBalance = 0;
  AppSettings _settings = const AppSettings();
  final Set<String> _completedSessionGuards = {};

  bool _isInitialized = false;

  // --- Active Focus Session Engine State ---
  final Stopwatch _focusStopwatch = Stopwatch();
  Timer? _focusTicker;
  DateTime? _activeSessionStartTime;
  PlannedSession? _activePlannedSession;
  String _activeTopic = 'Focus Session';
  double _activeWindowMultiplier = 1.0;
  bool _isFocusSessionActive = false;

  AppController() {
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTicker?.cancel();
    _focusStopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning to foreground during active focus, notify listeners to sync display
    if (_isFocusSessionActive && state == AppLifecycleState.resumed) {
      notifyListeners();
    }
  }

  // --- Getters ---
  bool get isInitialized => _isInitialized;
  List<PlannedSession> get plannedSessions => List.unmodifiable(_plannedSessions);
  List<CompletedSession> get completedSessions => List.unmodifiable(_completedSessions);
  List<Goal> get goals => List.unmodifiable(_goals);
  int get walletTokenBalance => _walletTokenBalance;
  AppSettings get settings => _settings;

  // Active Focus Getters
  bool get isFocusSessionActive => _isFocusSessionActive;
  PlannedSession? get activePlannedSession => _activePlannedSession;
  String get activeTopic => _activeTopic;
  double get activeWindowMultiplier => _activeWindowMultiplier;
  DateTime? get activeSessionStartTime => _activeSessionStartTime;

  /// Elapsed duration tracked via monotonic Stopwatch (resilient to backgrounding/clock shifts).
  Duration get activeElapsedDuration => _focusStopwatch.elapsed;
  int get activeElapsedSeconds => _focusStopwatch.elapsed.inSeconds;
  int get activeElapsedMilliseconds => _focusStopwatch.elapsed.inMilliseconds;

  /// Dynamic live reward calculation for active session.
  TokenRewardBreakdown get liveRewardBreakdown {
    final profile = flowProfile;
    return TokenCalculator.calculate(
      elapsedSeconds: activeElapsedSeconds,
      flowThresholdMinutes: profile.flowEntryThresholdMinutes,
      hasSufficientSessionsForFlow: profile.hasSufficientData,
      windowMultiplier: _activeWindowMultiplier,
      isCancelled: false,
    );
  }

  /// Hidden Background Flow State Engine Profile.
  FlowStateProfile get flowProfile => FlowEngine.evaluateProfile(
        completedSessions: _completedSessions,
        plannedSessions: _plannedSessions,
      );

  double get flowReadinessPercent => flowProfile.flowReadinessPercent;

  /// Retrieves the next uncompleted planned session.
  PlannedSession? get nextPlannedSession {
    final uncompleted = _plannedSessions.where((s) => !s.isCompleted).toList();
    return uncompleted.isNotEmpty ? uncompleted.first : null;
  }

  /// Longest completed session and highest tokens earned.
  CompletedSession? get bestSession {
    final valid = _completedSessions.where((s) => !s.isCancelled && s.elapsedSeconds >= 60).toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a.totalTokensEarned >= b.totalTokensEarned ? a : b);
  }

  /// Top focus topic or goal with the highest cumulative invested focus time.
  MapEntry<String, int>? get topFocusTopic {
    final valid = _completedSessions.where((s) => !s.isCancelled && s.elapsedSeconds >= 60).toList();
    if (valid.isEmpty) return null;

    final topicSecondsMap = <String, int>{};
    for (final s in valid) {
      topicSecondsMap[s.topic] = (topicSecondsMap[s.topic] ?? 0) + s.elapsedSeconds;
    }

    final sorted = topicSecondsMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }

  /// Dynamic Streak Calculation:
  /// Evaluated from actual consecutive local calendar dates with $\ge 1$ completed session.
  /// Never relies on an arbitrary stored counter.
  int get currentStreak {
    final valid = _completedSessions
        .where((s) => !s.isCancelled && s.elapsedSeconds >= 60)
        .toList();

    if (valid.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final distinctDates = valid
        .map((s) => DateTime(s.endTime.year, s.endTime.month, s.endTime.day))
        .toSet();

    if (!distinctDates.contains(today) && !distinctDates.contains(yesterday)) {
      return 0; // Streak broken
    }

    int streak = 0;
    var checkDate = distinctDates.contains(today) ? today : yesterday;

    while (distinctDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Explicit method alias for [currentStreak].
  int calculateDynamicStreak() => currentStreak;

  // --- Initializer & Local Storage ---

  Future<void> _initializeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Settings
      final settingsJson = prefs.getString(_prefKeySettings);
      if (settingsJson != null) {
        _settings = AppSettings.fromJson(jsonDecode(settingsJson) as Map<String, dynamic>);
      }

      // Load Wallet Tokens
      _walletTokenBalance = prefs.getInt(_prefKeyWallet) ?? 0;

      // Load Planned Sessions
      final plannedJson = prefs.getString(_prefKeyPlanned);
      if (plannedJson != null) {
        final list = jsonDecode(plannedJson) as List<dynamic>;
        _plannedSessions = list.map((item) => PlannedSession.fromJson(item as Map<String, dynamic>)).toList();
      }

      // Load Completed Sessions
      final completedJson = prefs.getString(_prefKeyCompleted);
      if (completedJson != null) {
        final list = jsonDecode(completedJson) as List<dynamic>;
        _completedSessions = list.map((item) => CompletedSession.fromJson(item as Map<String, dynamic>)).toList();
        for (final s in _completedSessions) {
          _completedSessionGuards.add(s.id);
        }
      }

      // Load Goals
      final goalsJson = prefs.getString(_prefKeyGoals);
      if (goalsJson != null) {
        final list = jsonDecode(goalsJson) as List<dynamic>;
        _goals = list.map((item) => Goal.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('AppController initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySettings, jsonEncode(_settings.toJson()));
    await prefs.setInt(_prefKeyWallet, _walletTokenBalance);
    await prefs.setString(
      _prefKeyPlanned,
      jsonEncode(_plannedSessions.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(
      _prefKeyCompleted,
      jsonEncode(_completedSessions.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(
      _prefKeyGoals,
      jsonEncode(_goals.map((g) => g.toJson()).toList()),
    );
  }

  // --- Planning Actions ---

  /// Adds a newly planned session. Newly planned sessions stack ABOVE existing ones!
  Future<void> addPlannedSession({
    required String topic,
    required int plannedDurationMinutes,
    TimeWindow? preferredWindow,
    String? linkedGoalId,
  }) async {
    final newSession = PlannedSession(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      topic: topic.trim().isEmpty ? 'Deep Focus' : topic.trim(),
      plannedDurationMinutes: plannedDurationMinutes,
      preferredWindow: preferredWindow,
      linkedGoalId: linkedGoalId,
      createdAt: DateTime.now(),
    );

    // Newly planned session appears ABOVE existing ones
    _plannedSessions.insert(0, newSession);
    await _persistAll();
    notifyListeners();
  }

  Future<void> deletePlannedSession(String id) async {
    _plannedSessions.removeWhere((s) => s.id == id);
    await _persistAll();
    notifyListeners();
  }

  // --- Goal Actions ---

  Future<void> addGoal({
    required String title,
    DateTime? deadlineDate,
  }) async {
    final newGoal = Goal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      deadlineDate: deadlineDate,
      createdAt: DateTime.now(),
    );

    _goals.insert(0, newGoal);
    await _persistAll();
    notifyListeners();
  }

  Future<void> toggleGoalCompletion(String id) async {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx != -1) {
      final goal = _goals[idx];
      _goals[idx] = goal.copyWith(
        isCompleted: !goal.isCompleted,
        completedAt: !goal.isCompleted ? DateTime.now() : null,
      );
      await _persistAll();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _persistAll();
    notifyListeners();
  }

  // --- Active Focus Session Engine ---

  void startFocusSession({PlannedSession? plannedSession, String? customTopic}) {
    if (_isFocusSessionActive) return;

    _activePlannedSession = plannedSession;
    _activeTopic = plannedSession?.topic ?? (customTopic ?? 'Deep Focus');
    _activeSessionStartTime = DateTime.now();

    // Evaluate window multiplier based on start time
    if (plannedSession?.preferredWindow != null) {
      final relation = plannedSession!.preferredWindow!.checkRelation(_activeSessionStartTime!);
      _activeWindowMultiplier = relation.multiplier;
    } else {
      _activeWindowMultiplier = 1.0;
    }

    _isFocusSessionActive = true;
    _focusStopwatch.reset();
    _focusStopwatch.start();

    _focusTicker?.cancel();
    _focusTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      notifyListeners();
    });

    notifyListeners();
  }

  /// Completes the active focus session, awards calculated tokens, and stores records.
  Future<CompletedSession?> finishFocusSession() async {
    if (!_isFocusSessionActive) return null;

    _focusStopwatch.stop();
    _focusTicker?.cancel();

    final endTime = DateTime.now();
    final elapsedSec = _focusStopwatch.elapsed.inSeconds;
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    // Duplicate completion guard
    if (_completedSessionGuards.contains(sessionId)) {
      _isFocusSessionActive = false;
      notifyListeners();
      return null;
    }

    final breakdown = liveRewardBreakdown;

    final completedSession = CompletedSession(
      id: sessionId,
      plannedSessionId: _activePlannedSession?.id,
      topic: _activeTopic,
      startTime: _activeSessionStartTime ?? endTime.subtract(Duration(seconds: elapsedSec)),
      endTime: endTime,
      elapsedSeconds: elapsedSec,
      baseTokens: breakdown.baseTokens,
      flowTokens: breakdown.flowTokens,
      windowMultiplier: _activeWindowMultiplier,
      totalTokensEarned: breakdown.totalTokens,
      isCancelled: false,
      linkedGoalId: _activePlannedSession?.linkedGoalId,
    );

    _completedSessionGuards.add(sessionId);
    _completedSessions.insert(0, completedSession);
    _walletTokenBalance += breakdown.totalTokens;

    // Mark planned session as completed
    if (_activePlannedSession != null) {
      final idx = _plannedSessions.indexWhere((p) => p.id == _activePlannedSession!.id);
      if (idx != -1) {
        _plannedSessions[idx] = _plannedSessions[idx].copyWith(
          isCompleted: true,
          completedAt: endTime,
          completedSessionId: sessionId,
        );
      }
    }

    _isFocusSessionActive = false;
    _activePlannedSession = null;
    _activeSessionStartTime = null;

    await _persistAll();
    notifyListeners();
    return completedSession;
  }

  /// Cancels active focus session without awarding any tokens.
  void cancelFocusSession() {
    _focusStopwatch.stop();
    _focusTicker?.cancel();
    _isFocusSessionActive = false;
    _activePlannedSession = null;
    _activeSessionStartTime = null;
    notifyListeners();
  }

  // --- Settings Actions ---

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _persistAll();
    notifyListeners();
  }

  Future<void> togglePrecision() async {
    _settings = _settings.copyWith(
      precisionShowCentiseconds: !_settings.precisionShowCentiseconds,
    );
    await _persistAll();
    notifyListeners();
  }

  // --- JSON File Backup & Atomic Restoration ---

  String exportBackupJson() {
    final exportMap = {
      'schema': backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'walletTokenBalance': _walletTokenBalance,
      'settings': _settings.toJson(),
      'plannedSessions': _plannedSessions.map((p) => p.toJson()).toList(),
      'completedSessions': _completedSessions.map((c) => c.toJson()).toList(),
      'goals': _goals.map((g) => g.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  Future<void> exportToFileAndShare(BuildContext context) async {
    try {
      final jsonString = exportBackupJson();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'serene_sky_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'Serene Sky Sanctuary Data Backup',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup export error: $e')),
        );
      }
    }
  }

  Future<bool> importBackupJson(String rawJson, {required bool overwrite}) async {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final schema = map['schema'] as String?;
      if (schema != backupSchemaVersion && schema != 'serene_sky_backup_v1') {
        throw const FormatException('Invalid or unsupported backup schema version.');
      }

      if (!map.containsKey('completedSessions') || !map.containsKey('plannedSessions')) {
        throw const FormatException('Corrupted backup: Missing required session records.');
      }

      final importedSettings = map.containsKey('settings')
          ? AppSettings.fromJson(map['settings'] as Map<String, dynamic>)
          : _settings;

      final importedWallet = (map['walletTokenBalance'] as num?)?.toInt() ?? 0;

      final importedPlanned = (map['plannedSessions'] as List<dynamic>? ?? [])
          .map((item) => PlannedSession.fromJson(item as Map<String, dynamic>))
          .toList();

      final importedCompleted = (map['completedSessions'] as List<dynamic>? ?? [])
          .map((item) => CompletedSession.fromJson(item as Map<String, dynamic>))
          .toList();

      final importedGoals = (map['goals'] as List<dynamic>? ?? [])
          .map((item) => Goal.fromJson(item as Map<String, dynamic>))
          .toList();

      // Atomic Update
      if (overwrite) {
        _settings = importedSettings;
        _walletTokenBalance = importedWallet;
        _plannedSessions = importedPlanned;
        _completedSessions = importedCompleted;
        _goals = importedGoals;
      } else {
        // Merge without duplicate IDs
        final existingPlannedIds = _plannedSessions.map((p) => p.id).toSet();
        for (final p in importedPlanned) {
          if (!existingPlannedIds.contains(p.id)) _plannedSessions.add(p);
        }

        final existingCompletedIds = _completedSessions.map((c) => c.id).toSet();
        for (final c in importedCompleted) {
          if (!existingCompletedIds.contains(c.id)) {
            _completedSessions.add(c);
            _walletTokenBalance += c.totalTokensEarned;
          }
        }

        final existingGoalIds = _goals.map((g) => g.id).toSet();
        for (final g in importedGoals) {
          if (!existingGoalIds.contains(g.id)) _goals.add(g);
        }
      }

      // Rebuild duplicate completion guard
      _completedSessionGuards.clear();
      for (final s in _completedSessions) {
        _completedSessionGuards.add(s.id);
      }

      await _persistAll();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Backup import validation error: $e');
      return false;
    }
  }

  Future<bool?> pickAndRestoreFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) {
        return null;
      }

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();

      if (!context.mounted) return null;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final palette = SkyThemeScope.paletteOf(ctx);
          return AlertDialog(
            backgroundColor: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.35)),
            ),
            title: Text(
              'Restore Archive',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.primaryText,
              ),
            ),
            content: Text(
              'Do you want to merge imported records with existing data, or overwrite entirely?',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 14,
                color: palette.secondaryText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('merge'),
                child: Text('Merge Data', style: TextStyle(color: palette.mintAura)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('overwrite'),
                child: Text('Overwrite', style: TextStyle(color: palette.deadlineAlertCoral)),
              ),
            ],
          );
        },
      );

      if (mode == null) return null;
      final success = await importBackupJson(contents, overwrite: mode == 'overwrite');
      return success;
    } catch (e) {
      debugPrint('Error restoring file: $e');
      return false;
    }
  }
}

/// InheritedWidget providing reactive access to [AppController].
class AppControllerScope extends InheritedNotifier<AppController> {
  const AppControllerScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppControllerScope>();
    assert(scope != null, 'No AppControllerScope found in context');
    return scope!.notifier!;
  }
}
