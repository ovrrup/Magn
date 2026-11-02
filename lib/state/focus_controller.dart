import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_models.dart';
import '../theme/instrument_theme.dart';

enum DateRangeFilter {
  day,
  week,
  all,
}

/// The core systems controller and state engine for the Precision Field Instrument.
class FocusController extends ChangeNotifier {
  static const String _tasksKey = 'pfi_tasks_v1';
  static const String _sessionsKey = 'pfi_sessions_v1';
  static const String _marksKey = 'pfi_marks_v1';
  static const String _settingsKey = 'pfi_settings_v1';

  // --- Engine State ---
  bool _isRunning = false;
  DateTime? _sessionStartTime;
  DateTime? _phaseStartTime;
  int _accumulatedMilliseconds = 0;
  Timer? _tickerTimer;

  // --- Mode & Cycle ---
  AppMode _mode = AppMode.endless;
  CyclePhase _cyclePhase = CyclePhase.focus;
  int _cycleIndex = 1; // 1 to 4

  // --- Linked Task ---
  String? _activeTaskId;

  // --- Collections ---
  List<FocusTask> _tasks = [];
  List<FocusSession> _sessions = [];
  List<DistractionMark> _marks = [];
  FocusSettings _settings = const FocusSettings();

  bool _isInitialized = false;

  FocusController() {
    _initializeData();
  }

  // --- Getters ---
  bool get isRunning => _isRunning;
  AppMode get mode => _mode;
  CyclePhase get cyclePhase => _cyclePhase;
  int get cycleIndex => _cycleIndex;
  FocusSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  List<FocusTask> get tasks => List.unmodifiable(_tasks);
  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  List<DistractionMark> get marks => List.unmodifiable(_marks);

  FocusTask? get activeTask {
    if (_activeTaskId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == _activeTaskId);
    } catch (_) {
      return null;
    }
  }

  /// Total elapsed milliseconds for the active session.
  int get elapsedMilliseconds => _accumulatedMilliseconds;

  /// Total elapsed seconds for the active session.
  int get elapsedSeconds => _accumulatedMilliseconds ~/ 1000;

  /// Centiseconds component (0-99).
  int get elapsedCentiseconds => (_accumulatedMilliseconds % 1000) ~/ 10;

  /// Minutes component for digital readout.
  int get elapsedMinutes => elapsedSeconds ~/ 60;

  /// Remaining seconds in display.
  int get displaySeconds => elapsedSeconds % 60;

  /// Seconds spent in Flow State in this active session.
  int get currentFlowSeconds {
    final ignitionSec = _settings.ignitionThresholdMinutes * 60;
    if (_mode == AppMode.endless) {
      if (elapsedSeconds < ignitionSec) return 0;
      return elapsedSeconds - ignitionSec;
    } else {
      // Cycle mode
      if (_cyclePhase != CyclePhase.focus) return 0;
      if (elapsedSeconds < ignitionSec) return 0;
      return elapsedSeconds - ignitionSec;
    }
  }

  /// Progress fraction (0.0 to 1.0) towards Flow Ignition threshold.
  double get warmUpProgress {
    final ignitionSec = _settings.ignitionThresholdMinutes * 60;
    if (ignitionSec <= 0) return 1.0;
    return (elapsedSeconds / ignitionSec).clamp(0.0, 1.0);
  }

  /// Current real-time physiological focus state.
  FocusState get focusState {
    if (!_isRunning) return FocusState.idle;
    if (_mode == AppMode.cycle && _cyclePhase != CyclePhase.focus) {
      return FocusState.idle;
    }
    final ignitionSec = _settings.ignitionThresholdMinutes * 60;
    if (elapsedSeconds < ignitionSec) {
      return FocusState.warmUp;
    }
    return FocusState.flowState;
  }

  /// Cycle target duration in seconds for the current phase.
  int get currentCycleTargetSeconds {
    switch (_cyclePhase) {
      case CyclePhase.focus:
        return _settings.cycleFocusMinutes * 60;
      case CyclePhase.shortBreak:
        return _settings.cycleShortBreakMinutes * 60;
      case CyclePhase.longBreak:
        return _settings.cycleLongBreakMinutes * 60;
    }
  }

  // --- Initialization & Mock Seeds ---

  Future<void> _initializeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Settings
      final settingsRaw = prefs.getString(_settingsKey);
      if (settingsRaw != null) {
        _settings = FocusSettings.fromJson(
            jsonDecode(settingsRaw) as Map<String, dynamic>);
      }

      // Load Tasks
      final tasksRaw = prefs.getString(_tasksKey);
      if (tasksRaw != null) {
        final list = jsonDecode(tasksRaw) as List<dynamic>;
        _tasks = list
            .map((item) => FocusTask.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _seedInitialTasks();
      }

      // Load Sessions
      final sessionsRaw = prefs.getString(_sessionsKey);
      if (sessionsRaw != null) {
        final list = jsonDecode(sessionsRaw) as List<dynamic>;
        _sessions = list
            .map((item) => FocusSession.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _seedInitialSessions();
      }

      // Load Marks
      final marksRaw = prefs.getString(_marksKey);
      if (marksRaw != null) {
        final list = jsonDecode(marksRaw) as List<dynamic>;
        _marks = list
            .map((item) =>
                DistractionMark.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('FocusController: error loading preferences: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _seedInitialTasks() {
    final now = DateTime.now();
    _tasks = [
      FocusTask(
        id: 't-01',
        title: 'Design System Architecture & Tokens',
        bucket: TaskBucket.today,
        accumulatedFlowSeconds: 3600,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      FocusTask(
        id: 't-02',
        title: 'Mechanical Platter CustomPainter Geometry',
        bucket: TaskBucket.today,
        accumulatedFlowSeconds: 2400,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      FocusTask(
        id: 't-03',
        title: 'Tactile Haptic Tuning on Spindle Toggle',
        bucket: TaskBucket.deferred,
        accumulatedFlowSeconds: 900,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      FocusTask(
        id: 't-04',
        title: 'Verify File Export/Import Schema Validation',
        bucket: TaskBucket.marks,
        accumulatedFlowSeconds: 0,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
    _activeTaskId = 't-01';
  }

  void _seedInitialSessions() {
    final now = DateTime.now();
    _sessions = [
      FocusSession(
        id: 's-01',
        startTime: now.subtract(const Duration(days: 4, hours: 3)),
        endTime: now.subtract(const Duration(days: 4, hours: 2)),
        totalDurationSeconds: 3600,
        flowDurationSeconds: 3000,
        mode: AppMode.endless,
        markCount: 1,
        linkedTaskId: 't-01',
        linkedTaskTitle: 'Design System Architecture & Tokens',
      ),
      FocusSession(
        id: 's-02',
        startTime: now.subtract(const Duration(days: 3, hours: 5)),
        endTime: now.subtract(const Duration(days: 3, hours: 3, minutes: 40)),
        totalDurationSeconds: 4800,
        flowDurationSeconds: 4200,
        mode: AppMode.endless,
        markCount: 2,
        linkedTaskId: 't-02',
        linkedTaskTitle: 'Mechanical Platter CustomPainter Geometry',
      ),
      FocusSession(
        id: 's-03',
        startTime: now.subtract(const Duration(days: 2, hours: 4)),
        endTime: now.subtract(const Duration(days: 2, hours: 3, minutes: 10)),
        totalDurationSeconds: 3000,
        flowDurationSeconds: 2400,
        mode: AppMode.cycle,
        markCount: 0,
        linkedTaskId: 't-01',
        linkedTaskTitle: 'Design System Architecture & Tokens',
      ),
      FocusSession(
        id: 's-04',
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        totalDurationSeconds: 3600,
        flowDurationSeconds: 3000,
        mode: AppMode.endless,
        markCount: 1,
        linkedTaskId: 't-02',
        linkedTaskTitle: 'Mechanical Platter CustomPainter Geometry',
      ),
      FocusSession(
        id: 's-05',
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.subtract(const Duration(hours: 4)),
        totalDurationSeconds: 3600,
        flowDurationSeconds: 3000,
        mode: AppMode.endless,
        markCount: 1,
        linkedTaskId: 't-01',
        linkedTaskTitle: 'Design System Architecture & Tokens',
      ),
    ];
  }

  // --- Persistence Helpers ---

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_tasksKey, data);
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, data);
  }

  Future<void> _saveMarks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_marks.map((m) => m.toJson()).toList());
    await prefs.setString(_marksKey, data);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  // --- Core Hardware Timer Engine ---

  void toggleStartStop() {
    if (_isRunning) {
      stop();
    } else {
      start();
    }
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _sessionStartTime ??= DateTime.now();
    _phaseStartTime ??= DateTime.now();

    final baselineNow = DateTime.now();
    final initialOffset = _accumulatedMilliseconds;

    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final now = DateTime.now();
      _accumulatedMilliseconds =
          initialOffset + now.difference(baselineNow).inMilliseconds;

      // Handle Cycle phase completion
      if (_mode == AppMode.cycle) {
        final targetMs = currentCycleTargetSeconds * 1000;
        if (_accumulatedMilliseconds >= targetMs) {
          _advanceCyclePhase();
          return;
        }
      }

      notifyListeners();
    });

    notifyListeners();
  }

  void stop() {
    if (!_isRunning) return;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _isRunning = false;

    // Archive completed session if elapsed seconds >= 30
    if (elapsedSeconds >= 30) {
      final now = DateTime.now();
      final session = FocusSession(
        id: 's-${DateTime.now().millisecondsSinceEpoch}',
        startTime: _sessionStartTime ?? now.subtract(Duration(seconds: elapsedSeconds)),
        endTime: now,
        totalDurationSeconds: elapsedSeconds,
        flowDurationSeconds: currentFlowSeconds,
        mode: _mode,
        markCount: _marks.where((m) => m.timestamp.isAfter(_sessionStartTime ?? now)).length,
        linkedTaskId: _activeTaskId,
        linkedTaskTitle: activeTask?.title,
      );
      _sessions.insert(0, session);
      _saveSessions();

      // Accumulate flow seconds on linked task
      if (_activeTaskId != null && currentFlowSeconds > 0) {
        final index = _tasks.indexWhere((t) => t.id == _activeTaskId);
        if (index != -1) {
          final t = _tasks[index];
          _tasks[index] = t.copyWith(
            accumulatedFlowSeconds: t.accumulatedFlowSeconds + currentFlowSeconds,
          );
          _saveTasks();
        }
      }
    }

    _accumulatedMilliseconds = 0;
    _sessionStartTime = null;
    _phaseStartTime = null;
    notifyListeners();
  }

  void reset() {
    stop();
    _accumulatedMilliseconds = 0;
    _cycleIndex = 1;
    _cyclePhase = CyclePhase.focus;
    notifyListeners();
  }

  void skipPhase() {
    if (_mode != AppMode.cycle) return;
    _advanceCyclePhase();
  }

  void _advanceCyclePhase() {
    _accumulatedMilliseconds = 0;
    _sessionStartTime = DateTime.now();
    _phaseStartTime = DateTime.now();

    if (_cyclePhase == CyclePhase.focus) {
      if (_cycleIndex < _settings.cycleTargetLoops) {
        _cyclePhase = CyclePhase.shortBreak;
      } else {
        _cyclePhase = CyclePhase.longBreak;
      }
    } else {
      if (_cyclePhase == CyclePhase.longBreak) {
        _cycleIndex = 1;
      } else {
        _cycleIndex++;
      }
      _cyclePhase = CyclePhase.focus;
    }

    notifyListeners();
  }

  void setMode(AppMode newMode) {
    if (_mode == newMode) return;
    stop();
    _mode = newMode;
    _cycleIndex = 1;
    _cyclePhase = CyclePhase.focus;
    notifyListeners();
  }

  void toggleMode() {
    setMode(_mode == AppMode.endless ? AppMode.cycle : AppMode.endless);
  }

  void toggleShowDigits() {
    _settings = _settings.copyWith(showDigits: !_settings.showDigits);
    _saveSettings();
    notifyListeners();
  }

  // --- Distraction Mark Capture (+ MARK) ---

  void addDistractionMark(String note) {
    final mark = DistractionMark(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      note: note.trim().isEmpty ? 'Impulse recorded' : note.trim(),
      sessionElapsedSeconds: elapsedSeconds,
    );
    _marks.insert(0, mark);
    _saveMarks();

    // Automatically create a task in CAPTURED MARKS bucket if meaningful text entered
    if (note.trim().isNotEmpty) {
      createTask(note.trim(), TaskBucket.marks);
    }

    notifyListeners();
  }

  // --- Task Triage Operations ---

  void createTask(String title, [TaskBucket bucket = TaskBucket.today]) {
    if (title.trim().isEmpty) return;
    final task = FocusTask(
      id: 't-${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      bucket: bucket,
      createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    if (_activeTaskId == null && bucket == TaskBucket.today) {
      _activeTaskId = task.id;
    }
    _saveTasks();
    notifyListeners();
  }

  void toggleTaskComplete(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final t = _tasks[index];
    final updated = t.copyWith(
      isCompleted: !t.isCompleted,
      completedAt: !t.isCompleted ? DateTime.now() : null,
    );
    _tasks[index] = updated;
    _saveTasks();
    notifyListeners();
  }

  void deferTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final t = _tasks[index];
    final newBucket = (t.bucket == TaskBucket.today)
        ? TaskBucket.deferred
        : TaskBucket.today;
    _tasks[index] = t.copyWith(bucket: newBucket);
    _saveTasks();
    notifyListeners();
  }

  void moveTask(String taskId, TaskBucket newBucket) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(bucket: newBucket);
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    if (_activeTaskId == taskId) {
      _activeTaskId = null;
    }
    _saveTasks();
    notifyListeners();
  }

  void setActiveTask(FocusTask? task) {
    _activeTaskId = task?.id;
    notifyListeners();
  }

  // --- Settings & Appearance ---

  void updateSettings(FocusSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  void setThemeMode(InstrumentThemeMode mode) {
    _settings = _settings.copyWith(themeMode: mode);
    _saveSettings();
    notifyListeners();
  }

  // --- Self-Personalizing 85th-Percentile Survival Math ---

  /// Calculates personal ignition time T_flow via 85th-percentile early-bailout survival math.
  /// When individuals begin focus sessions, friction and task anxiety cause early abandonment.
  /// The 85th percentile of the session survival curve identifies the inflection threshold
  /// where 85% of bailouts have concluded and the brain enters sustained deep flow.
  int calculatePersonalIgnitionMinutes() {
    if (_sessions.length < 3) {
      return _settings.ignitionThresholdMinutes;
    }
    final durationsMinutes = _sessions
        .map((s) => (s.totalDurationSeconds / 60).round())
        .where((d) => d >= 2)
        .toList()
      ..sort();

    if (durationsMinutes.isEmpty) return _settings.ignitionThresholdMinutes;

    final index = ((durationsMinutes.length - 1) * 0.85).round();
    final percentileVal = durationsMinutes[index];
    // Clamp to realistic physiological bounds (3 to 25 minutes)
    return percentileVal.clamp(3, 25);
  }

  // --- Analytics & Insight Calculations ---

  List<FocusSession> sessionsForFilter(DateRangeFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case DateRangeFilter.day:
        final startOfDay = DateTime(now.year, now.month, now.day);
        return _sessions.where((s) => s.startTime.isAfter(startOfDay)).toList();
      case DateRangeFilter.week:
        final startOfWeek = now.subtract(const Duration(days: 7));
        return _sessions.where((s) => s.startTime.isAfter(startOfWeek)).toList();
      case DateRangeFilter.all:
        return _sessions;
    }
  }

  int totalFlowDurationSeconds(DateRangeFilter filter) {
    final filtered = sessionsForFilter(filter);
    return filtered.fold<int>(0, (sum, s) => sum + s.flowDurationSeconds);
  }

  int totalDurationSeconds(DateRangeFilter filter) {
    final filtered = sessionsForFilter(filter);
    return filtered.fold<int>(0, (sum, s) => sum + s.totalDurationSeconds);
  }

  int flowEfficiencyPercent(DateRangeFilter filter) {
    final total = totalDurationSeconds(filter);
    if (total <= 0) return 0;
    final flow = totalFlowDurationSeconds(filter);
    return ((flow / total) * 100).round().clamp(0, 100);
  }

  /// 7-day flow duration in minutes for each day of the past 7 days (index 0 is 6 days ago, 6 is today).
  List<double> get sevenDayDailyFlowMinutes {
    final result = List<double>.filled(7, 0.0);
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final dayTarget = now.subtract(Duration(days: 6 - i));
      final dayStart = DateTime(dayTarget.year, dayTarget.month, dayTarget.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final daySessions = _sessions.where((s) =>
          s.startTime.isAfter(dayStart) && s.startTime.isBefore(dayEnd));
      final flowSec =
          daySessions.fold<int>(0, (sum, s) => sum + s.flowDurationSeconds);
      result[i] = (flowSec / 60.0);
    }
    return result;
  }

  double get sevenDayAverageMinutes {
    final daily = sevenDayDailyFlowMinutes;
    final sum = daily.fold<double>(0.0, (acc, val) => acc + val);
    return sum / daily.length;
  }

  /// 28-day consistency matrix: 28 items (4 rows x 7 columns).
  /// true if flow minutes > 0 on that day.
  List<bool> get twentyEightDayConsistency {
    final result = List<bool>.filled(28, false);
    final now = DateTime.now();
    for (int i = 0; i < 28; i++) {
      final dayTarget = now.subtract(Duration(days: 27 - i));
      final dayStart = DateTime(dayTarget.year, dayTarget.month, dayTarget.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final hasFlow = _sessions.any((s) =>
          s.startTime.isAfter(dayStart) &&
          s.startTime.isBefore(dayEnd) &&
          s.flowDurationSeconds > 0);
      result[i] = hasFlow;
    }
    return result;
  }

  int get longestFlowStreakDays {
    if (_sessions.isEmpty) return 0;
    final now = DateTime.now();
    int currentStreak = 0;
    int maxStreak = 0;

    for (int i = 0; i < 60; i++) {
      final dayTarget = now.subtract(Duration(days: i));
      final dayStart = DateTime(dayTarget.year, dayTarget.month, dayTarget.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final hasFlow = _sessions.any((s) =>
          s.startTime.isAfter(dayStart) &&
          s.startTime.isBefore(dayEnd) &&
          s.flowDurationSeconds > 0);
      if (hasFlow) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        if (i > 0) currentStreak = 0;
      }
    }
    return maxStreak;
  }

  int get deepestSessionMinutes {
    if (_sessions.isEmpty) return 0;
    final maxSec = _sessions.fold<int>(
        0, (m, s) => s.flowDurationSeconds > m ? s.flowDurationSeconds : m);
    return (maxSec / 60).round();
  }

  /// Generates the stepped cognitive depth segments for hypnogram visualization.
  List<CognitiveDepthSegment> generateCognitiveDepthSegments(
      DateRangeFilter filter) {
    final filtered = sessionsForFilter(filter);
    if (filtered.isEmpty) {
      // Return a balanced baseline hypnogram curve so the custom painter is rich immediately
      final now = DateTime.now();
      return [
        CognitiveDepthSegment(
          startTime: now.subtract(const Duration(hours: 3)),
          endTime: now.subtract(const Duration(hours: 2, minutes: 40)),
          level: CognitiveDepthLevel.idle,
          durationSeconds: 1200,
        ),
        CognitiveDepthSegment(
          startTime: now.subtract(const Duration(hours: 2, minutes: 40)),
          endTime: now.subtract(const Duration(hours: 2, minutes: 30)),
          level: CognitiveDepthLevel.warmUp,
          durationSeconds: 600,
        ),
        CognitiveDepthSegment(
          startTime: now.subtract(const Duration(hours: 2, minutes: 30)),
          endTime: now.subtract(const Duration(hours: 2)),
          level: CognitiveDepthLevel.focused,
          durationSeconds: 1800,
        ),
        CognitiveDepthSegment(
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.subtract(const Duration(hours: 1)),
          level: CognitiveDepthLevel.deepFlow,
          durationSeconds: 3600,
        ),
      ];
    }

    final segments = <CognitiveDepthSegment>[];
    for (final s in filtered.take(5)) {
      final warmUpSec = _settings.ignitionThresholdMinutes * 60;
      if (s.totalDurationSeconds < warmUpSec) {
        segments.add(CognitiveDepthSegment(
          startTime: s.startTime,
          endTime: s.endTime,
          level: CognitiveDepthLevel.warmUp,
          durationSeconds: s.totalDurationSeconds,
        ));
      } else {
        // Warm-up segment
        segments.add(CognitiveDepthSegment(
          startTime: s.startTime,
          endTime: s.startTime.add(Duration(seconds: warmUpSec)),
          level: CognitiveDepthLevel.warmUp,
          durationSeconds: warmUpSec,
        ));
        // Deep Flow segment
        segments.add(CognitiveDepthSegment(
          startTime: s.startTime.add(Duration(seconds: warmUpSec)),
          endTime: s.endTime,
          level: CognitiveDepthLevel.deepFlow,
          durationSeconds: s.totalDurationSeconds - warmUpSec,
        ));
      }
    }
    return segments;
  }

  // --- File-Based Backup & JSON Import/Export ---

  String exportDataJson() {
    final exportMap = {
      'schema': 'pfi_backup_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settings.toJson(),
      'tasks': _tasks.map((t) => t.toJson()).toList(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
      'marks': _marks.map((m) => m.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  Future<void> exportToFileAndShare(BuildContext context) async {
    try {
      final jsonString = exportDataJson();
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'pfi_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'Precision Field Instrument Data Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<bool> importFromJson(String rawJson, {required bool overwrite}) async {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      if (map['schema'] != 'pfi_backup_v1') {
        throw const FormatException('Invalid backup schema version');
      }

      if (map.containsKey('settings')) {
        _settings = FocusSettings.fromJson(
            map['settings'] as Map<String, dynamic>);
        await _saveSettings();
      }

      final importedTasks = (map['tasks'] as List<dynamic>? ?? [])
          .map((item) => FocusTask.fromJson(item as Map<String, dynamic>))
          .toList();

      final importedSessions = (map['sessions'] as List<dynamic>? ?? [])
          .map((item) => FocusSession.fromJson(item as Map<String, dynamic>))
          .toList();

      final importedMarks = (map['marks'] as List<dynamic>? ?? [])
          .map((item) =>
              DistractionMark.fromJson(item as Map<String, dynamic>))
          .toList();

      if (overwrite) {
        _tasks = importedTasks;
        _sessions = importedSessions;
        _marks = importedMarks;
      } else {
        // Merge without duplicate IDs
        final existingTaskIds = _tasks.map((t) => t.id).toSet();
        for (final t in importedTasks) {
          if (!existingTaskIds.contains(t.id)) _tasks.add(t);
        }

        final existingSessionIds = _sessions.map((s) => s.id).toSet();
        for (final s in importedSessions) {
          if (!existingSessionIds.contains(s.id)) _sessions.add(s);
        }

        final existingMarkIds = _marks.map((m) => m.id).toSet();
        for (final m in importedMarks) {
          if (!existingMarkIds.contains(m.id)) _marks.add(m);
        }
      }

      await _saveTasks();
      await _saveSessions();
      await _saveMarks();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FocusController: import error: $e');
      return false;
    }
  }

  Future<bool?> pickAndImportFile(BuildContext context) async {
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

      // Show dialog to confirm Merge vs Overwrite
      if (!context.mounted) return null;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final p = InstrumentTheme.paletteOf(_settings.themeMode);
          return AlertDialog(
            backgroundColor: p.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.hairlineBorder),
            ),
            title: Text(
              'IMPORT BACKUP',
              style: InstrumentTheme.headline(p),
            ),
            content: Text(
              'Do you want to merge imported data with existing records, or overwrite entirely?',
              style: InstrumentTheme.body(p),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('merge'),
                child: Text('MERGE', style: TextStyle(color: p.inkPrimary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('overwrite'),
                child: Text('OVERWRITE', style: TextStyle(color: p.signalOrange)),
              ),
            ],
          );
        },
      );

      if (mode == null) return null;
      final success = await importFromJson(contents, overwrite: mode == 'overwrite');
      return success;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return false;
    }
  }
}
