import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StopwatchApp());
}

// ============================================================================
// SECTION 1: DATA MODELS
// ============================================================================

enum AppMode {
  endless,
  cycle,
}

enum CyclePhase {
  focus,
  shortBreak,
  longBreak,
}

enum ThemeModeOption {
  system,
  light,
  dark,
}

/// A recorded focus or stopwatch session.
class SessionRecord {
  final String id;
  final int durationSeconds;
  final int flowSeconds;
  final DateTime timestamp;
  final AppMode mode;
  final int interruptions;
  final String? linkedTaskId;

  const SessionRecord({
    required this.id,
    required this.durationSeconds,
    required this.flowSeconds,
    required this.timestamp,
    required this.mode,
    this.interruptions = 0,
    this.linkedTaskId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationSeconds': durationSeconds,
        'flowSeconds': flowSeconds,
        'timestamp': timestamp.toIso8601String(),
        'mode': mode.name,
        'interruptions': interruptions,
        if (linkedTaskId != null) 'linkedTaskId': linkedTaskId,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String? ?? UniqueKey().toString(),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        flowSeconds: json['flowSeconds'] as int? ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        mode: json['mode'] == 'cycle' ? AppMode.cycle : AppMode.endless,
        interruptions: json['interruptions'] as int? ?? 0,
        linkedTaskId: json['linkedTaskId'] as String?,
      );
}

/// A focus task item with focus and flow telemetry.
class TaskItem {
  final String id;
  final String title;
  final bool isCompleted;
  final bool isDeferred; // Not Today
  final int focusSeconds;
  final int flowSeconds;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.isDeferred = false,
    this.focusSeconds = 0,
    this.flowSeconds = 0,
    required this.createdAt,
  });

  TaskItem copyWith({
    String? title,
    bool? isCompleted,
    bool? isDeferred,
    int? focusSeconds,
    int? flowSeconds,
  }) =>
      TaskItem(
        id: id,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
        isDeferred: isDeferred ?? this.isDeferred,
        focusSeconds: focusSeconds ?? this.focusSeconds,
        flowSeconds: flowSeconds ?? this.flowSeconds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'isDeferred': isDeferred,
        'focusSeconds': focusSeconds,
        'flowSeconds': flowSeconds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String? ?? UniqueKey().toString(),
        title: json['title'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        isDeferred: json['isDeferred'] as bool? ?? false,
        focusSeconds: json['focusSeconds'] as int? ?? 0,
        flowSeconds: json['flowSeconds'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// User behavior and appearance preferences.
class AppSettings {
  final bool showDigits;
  final bool showCentiseconds;
  final ThemeModeOption themeMode;
  final bool pureBlackOled;

  const AppSettings({
    this.showDigits = false,
    this.showCentiseconds = true,
    this.themeMode = ThemeModeOption.system,
    this.pureBlackOled = false,
  });

  AppSettings copyWith({
    bool? showDigits,
    bool? showCentiseconds,
    ThemeModeOption? themeMode,
    bool? pureBlackOled,
  }) =>
      AppSettings(
        showDigits: showDigits ?? this.showDigits,
        showCentiseconds: showCentiseconds ?? this.showCentiseconds,
        themeMode: themeMode ?? this.themeMode,
        pureBlackOled: pureBlackOled ?? this.pureBlackOled,
      );

  Map<String, dynamic> toJson() => {
        'showDigits': showDigits,
        'showCentiseconds': showCentiseconds,
        'themeMode': themeMode.name,
        'pureBlackOled': pureBlackOled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        showDigits: json['showDigits'] as bool? ?? false,
        showCentiseconds: json['showCentiseconds'] as bool? ?? true,
        themeMode: ThemeModeOption.values.firstWhere(
          (e) => e.name == json['themeMode'],
          orElse: () => ThemeModeOption.system,
        ),
        pureBlackOled: json['pureBlackOled'] as bool? ?? false,
      );
}

// ============================================================================
// SECTION 2: FLAT EYE-COMFORT THEME ENGINE
// ============================================================================

/// Flat, solid, zero-gradient color palette for maximum eye comfort.
class AppPalette {
  final Color background;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
  });

  // Dark Mode
  static const dark = AppPalette(
    background: Color(0xFF121316),
    surface: Color(0xFF1C1E22),
    border: Color(0xFF2A2D34),
    primaryText: Color(0xFFE2E4E9),
    secondaryText: Color(0xFF7C828D),
    accent: Color(0xFF6B9080),
  );

  // Pure Black OLED Mode
  static const oled = AppPalette(
    background: Colors.black,
    surface: Color(0xFF0D0E11),
    border: Color(0xFF1F2227),
    primaryText: Color(0xFFE2E4E9),
    secondaryText: Color(0xFF7C828D),
    accent: Color(0xFF6B9080),
  );

  // Warm Paper Light Mode
  static const warmPaperLight = AppPalette(
    background: Color(0xFFF4F3EF),
    surface: Color(0xFFEAE8E1),
    border: Color(0xFFDCD9D0),
    primaryText: Color(0xFF1E2022),
    secondaryText: Color(0xFF706F6C),
    accent: Color(0xFF4A6B5D),
  );

  static AppPalette resolve({
    required ThemeModeOption option,
    required bool isOled,
    required Brightness systemBrightness,
  }) {
    final isDark = option == ThemeModeOption.dark ||
        (option == ThemeModeOption.system &&
            systemBrightness == Brightness.dark);
    if (isDark) {
      return isOled ? oled : dark;
    }
    return warmPaperLight;
  }
}

// ============================================================================
// SECTION 3: STATE & BUSINESS LOGIC CONTROLLER
// ============================================================================

class FocusController extends ChangeNotifier with WidgetsBindingObserver {
  // Settings & Storage
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  // Session State
  AppMode _mode = AppMode.endless;
  AppMode get mode => _mode;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  // Endless Mode
  int _endlessElapsedMs = 0;
  int get endlessElapsedMs => _endlessElapsedMs;

  // Cycle Mode State Machine
  static const int _focusDurationSec = 25 * 60;
  static const int _shortBreakDurationSec = 5 * 60;
  static const int _longBreakDurationSec = 15 * 60;

  int _cycleIndex = 1; // 1 to 4
  int get cycleIndex => _cycleIndex;

  CyclePhase _cyclePhase = CyclePhase.focus;
  CyclePhase get cyclePhase => _cyclePhase;

  int _cycleRemainingSeconds = _focusDurationSec;
  int get cycleRemainingSeconds => _cycleRemainingSeconds;

  // Lifecycle Interruption Tracking
  int _sessionInterruptions = 0;
  int get sessionInterruptions => _sessionInterruptions;

  // Linked Task Tracking
  String? _linkedTaskId;
  String? get linkedTaskId => _linkedTaskId;

  // Historical Session Records & Tasks
  final List<SessionRecord> _sessions = [];
  List<SessionRecord> get sessions => List.unmodifiable(_sessions);

  final List<TaskItem> _tasks = [];
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  TaskItem? get linkedTask {
    if (_linkedTaskId == null) return null;
    for (final t in _tasks) {
      if (t.id == _linkedTaskId) return t;
    }
    return null;
  }

  int get pendingTaskCount =>
      _tasks.where((t) => !t.isCompleted && !t.isDeferred).length;

  FocusController() {
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isRunning) {
      _sessionInterruptions++;
      notifyListeners();
    }
  }

  // --- Flow Calibration Engine ---

  int get personalizedIgnitionThreshold {
    if (_sessions.isEmpty) return 600; // 10 minutes default

    final frictionDurations = <int>[];
    final deepDurations = <int>[];

    for (final s in _sessions) {
      if (s.durationSeconds < 1080 || s.interruptions > 0) {
        frictionDurations.add(s.durationSeconds);
      } else {
        deepDurations.add(s.durationSeconds);
      }
    }

    if (frictionDurations.isEmpty && deepDurations.isEmpty) return 600;

    double p85;
    if (frictionDurations.isNotEmpty) {
      frictionDurations.sort();
      final index = (frictionDurations.length * 0.85).ceil() - 1;
      p85 = frictionDurations[index.clamp(0, frictionDurations.length - 1)]
          .toDouble();
    } else {
      p85 = 600.0;
    }

    double medianDeep;
    if (deepDurations.isNotEmpty) {
      deepDurations.sort();
      final mid = deepDurations.length ~/ 2;
      medianDeep = (deepDurations.length % 2 == 1)
          ? deepDurations[mid].toDouble()
          : (deepDurations[mid - 1] + deepDurations[mid]) / 2.0;
    } else {
      medianDeep = 1800.0;
    }

    final blended = (0.68 * p85) + (0.32 * medianDeep);
    return blended.round().clamp(300, 1500); // 5m to 25m
  }

  int get currentElapsedSeconds {
    if (_mode == AppMode.endless) {
      return _endlessElapsedMs ~/ 1000;
    } else {
      final totalPhaseSec = _cyclePhase == CyclePhase.focus
          ? _focusDurationSec
          : (_cyclePhase == CyclePhase.shortBreak
              ? _shortBreakDurationSec
              : _longBreakDurationSec);
      return totalPhaseSec - _cycleRemainingSeconds;
    }
  }

  int get currentFlowSeconds {
    if (!_isRunning) return 0;
    if (_mode == AppMode.cycle && _cyclePhase != CyclePhase.focus) {
      return 0;
    }
    final elapsed = currentElapsedSeconds;
    final tFlow = personalizedIgnitionThreshold;
    if (elapsed > tFlow && _sessionInterruptions == 0) {
      return elapsed - tFlow;
    }
    return 0;
  }

  bool get isInFlow => currentFlowSeconds > 0;

  int get totalFlowSeconds =>
      _sessions.fold(0, (sum, s) => sum + s.flowSeconds);

  int get totalDurationSeconds =>
      _sessions.fold(0, (sum, s) => sum + s.durationSeconds);

  int get flowRatio {
    final total = totalDurationSeconds;
    if (total == 0) return 0;
    return ((totalFlowSeconds / total) * 100).round().clamp(0, 100);
  }

  int get calibrationAccuracy {
    if (_sessions.isEmpty) return 15;
    final score = 15 + (_sessions.length * 9);
    return score.clamp(15, 98);
  }

  // --- Task Operations ---

  void addTask(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final task = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: clean,
      createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    _saveData();
    notifyListeners();
  }

  void toggleTaskComplete(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = t.copyWith(isCompleted: !t.isCompleted);
      if (_linkedTaskId == id && !t.isCompleted) {
        _linkedTaskId = null;
      }
      _saveData();
      notifyListeners();
    }
  }

  void toggleTaskDeferred(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = t.copyWith(isDeferred: !t.isDeferred);
      if (_linkedTaskId == id && !t.isDeferred) {
        _linkedTaskId = null;
      }
      _saveData();
      notifyListeners();
    }
  }

  void linkTask(String id) {
    if (_linkedTaskId == id) {
      _linkedTaskId = null;
    } else {
      _linkedTaskId = id;
    }
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    if (_linkedTaskId == id) _linkedTaskId = null;
    _saveData();
    notifyListeners();
  }

  // --- Controls ---

  void setMode(AppMode mode) {
    if (_isRunning) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleTimer() {
    if (_isRunning) {
      _stopCurrentSession();
    } else {
      _startSession();
    }
  }

  void _startSession() {
    _isRunning = true;
    _sessionInterruptions = 0;
    _stopwatch.reset();
    _stopwatch.start();

    if (_mode == AppMode.endless) {
      _endlessElapsedMs = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        _endlessElapsedMs = _stopwatch.elapsedMilliseconds;
        notifyListeners();
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_cycleRemainingSeconds > 0) {
          _cycleRemainingSeconds--;
          notifyListeners();
        } else {
          _onCyclePhaseComplete();
        }
      });
    }
    notifyListeners();
  }

  void _stopCurrentSession() {
    _timer?.cancel();
    _stopwatch.stop();
    _isRunning = false;

    final durationSec = currentElapsedSeconds;
    if (durationSec >= 1) {
      final tFlow = personalizedIgnitionThreshold;
      final flowSec =
          (_mode == AppMode.endless || _cyclePhase == CyclePhase.focus)
              ? ((durationSec > tFlow && _sessionInterruptions == 0)
                  ? (durationSec - tFlow)
                  : 0)
              : 0;

      final session = SessionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        durationSeconds: durationSec,
        flowSeconds: flowSec,
        timestamp: DateTime.now(),
        mode: _mode,
        interruptions: _sessionInterruptions,
        linkedTaskId: _linkedTaskId,
      );
      _sessions.insert(0, session);

      // Accumulate metrics on linked task
      if (_linkedTaskId != null) {
        final tIndex = _tasks.indexWhere((t) => t.id == _linkedTaskId);
        if (tIndex != -1) {
          final t = _tasks[tIndex];
          _tasks[tIndex] = t.copyWith(
            focusSeconds: t.focusSeconds + durationSec,
            flowSeconds: t.flowSeconds + flowSec,
          );
        }
      }

      _saveData();
    }

    _endlessElapsedMs = 0;
    if (_mode == AppMode.cycle) {
      _cycleRemainingSeconds = _cyclePhase == CyclePhase.focus
          ? _focusDurationSec
          : (_cyclePhase == CyclePhase.shortBreak
              ? _shortBreakDurationSec
              : _longBreakDurationSec);
    }

    notifyListeners();
  }

  void skipCyclePhase() {
    if (_mode != AppMode.cycle) return;
    _onCyclePhaseComplete(userInitiated: true);
  }

  void _onCyclePhaseComplete({bool userInitiated = false}) {
    if (_cyclePhase == CyclePhase.focus) {
      if (_cycleIndex < 4) {
        _cyclePhase = CyclePhase.shortBreak;
        _cycleRemainingSeconds = _shortBreakDurationSec;
      } else {
        _cyclePhase = CyclePhase.longBreak;
        _cycleRemainingSeconds = _longBreakDurationSec;
      }
    } else if (_cyclePhase == CyclePhase.shortBreak) {
      _cycleIndex++;
      _cyclePhase = CyclePhase.focus;
      _cycleRemainingSeconds = _focusDurationSec;
    } else if (_cyclePhase == CyclePhase.longBreak) {
      _cycleIndex = 1;
      _cyclePhase = CyclePhase.focus;
      _cycleRemainingSeconds = _focusDurationSec;
    }

    if (!userInitiated) {
      _timer?.cancel();
      _stopwatch.stop();
      _isRunning = false;
    }

    notifyListeners();
  }

  void deleteSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    _saveData();
    notifyListeners();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    _saveData();
    notifyListeners();
  }

  // --- Persistence & Backup ---

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('magn_settings');
      if (settingsJson != null) {
        _settings = AppSettings.fromJson(
            jsonDecode(settingsJson) as Map<String, dynamic>);
      }
      final sessionsJson = prefs.getString('magn_sessions');
      if (sessionsJson != null) {
        final list = jsonDecode(sessionsJson) as List<dynamic>;
        _sessions.clear();
        for (final item in list) {
          _sessions.add(SessionRecord.fromJson(item as Map<String, dynamic>));
        }
      }
      final tasksJson = prefs.getString('magn_tasks');
      if (tasksJson != null) {
        final list = jsonDecode(tasksJson) as List<dynamic>;
        _tasks.clear();
        for (final item in list) {
          _tasks.add(TaskItem.fromJson(item as Map<String, dynamic>));
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('magn_settings', jsonEncode(_settings.toJson()));
      await prefs.setString(
        'magn_sessions',
        jsonEncode(_sessions.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'magn_tasks',
        jsonEncode(_tasks.map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  String exportFullJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settings.toJson(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
      'tasks': _tasks.map((t) => t.toJson()).toList(),
    });
  }

  Map<String, dynamic> validateBackupJson(String content) {
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object');
    }
    if (decoded['schemaVersion'] is! int) {
      throw const FormatException('schemaVersion must be an integer');
    }
    if (decoded.containsKey('settings') && decoded['settings'] is! Map) {
      throw const FormatException('settings must be a JSON object');
    }

    int sessionCount = 0;
    if (decoded.containsKey('sessions')) {
      final list = decoded['sessions'];
      if (list is! List) {
        throw const FormatException('sessions must be a list');
      }
      for (final item in list) {
        if (item is! Map) {
          throw const FormatException('Every session record must be an object');
        }
        final dur = item['durationSeconds'];
        final flow = item['flowSeconds'];
        if (dur is! int || dur < 0) {
          throw const FormatException(
              'durationSeconds must be a non-negative integer');
        }
        if (flow is! int || flow < 0) {
          throw const FormatException(
              'flowSeconds must be a non-negative integer');
        }
        if (item['timestamp'] == null ||
            DateTime.tryParse(item['timestamp'].toString()) == null) {
          throw const FormatException('Invalid timestamp in session record');
        }
        sessionCount++;
      }
    }

    int taskCount = 0;
    if (decoded.containsKey('tasks')) {
      final list = decoded['tasks'];
      if (list is! List) {
        throw const FormatException('tasks must be a list');
      }
      for (final item in list) {
        if (item is! Map) {
          throw const FormatException('Every task item must be an object');
        }
        if (item['title'] == null || item['title'].toString().trim().isEmpty) {
          throw const FormatException('Task item must contain a title');
        }
        taskCount++;
      }
    }

    return {
      'raw': decoded,
      'sessionCount': sessionCount,
      'taskCount': taskCount,
    };
  }

  void restoreBackup(Map<String, dynamic> raw, {required bool merge}) {
    if (raw.containsKey('settings')) {
      _settings =
          AppSettings.fromJson(raw['settings'] as Map<String, dynamic>);
    }

    if (raw.containsKey('sessions')) {
      final list = raw['sessions'] as List<dynamic>;
      final parsed =
          list.map((e) => SessionRecord.fromJson(e as Map<String, dynamic>));
      if (merge) {
        final existingIds = _sessions.map((s) => s.id).toSet();
        for (final s in parsed) {
          if (!existingIds.contains(s.id)) {
            _sessions.add(s);
          }
        }
        _sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _sessions.clear();
        _sessions.addAll(parsed);
      }
    }

    if (raw.containsKey('tasks')) {
      final list = raw['tasks'] as List<dynamic>;
      final parsed =
          list.map((e) => TaskItem.fromJson(e as Map<String, dynamic>));
      if (merge) {
        final existingIds = _tasks.map((t) => t.id).toSet();
        for (final t in parsed) {
          if (!existingIds.contains(t.id)) {
            _tasks.add(t);
          }
        }
      } else {
        _tasks.clear();
        _tasks.addAll(parsed);
      }
    }

    _saveData();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _sessions.clear();
    _tasks.clear();
    _linkedTaskId = null;
    _settings = const AppSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('magn_settings');
    await prefs.remove('magn_sessions');
    await prefs.remove('magn_tasks');
    notifyListeners();
  }
}

// ============================================================================
// SECTION 4: MODULAR UI WIDGETS
// ============================================================================

/// The root application widget.
class StopwatchApp extends StatefulWidget {
  const StopwatchApp({super.key});

  @override
  State<StopwatchApp> createState() => _StopwatchAppState();
}

class _StopwatchAppState extends State<StopwatchApp> {
  late final FocusController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FocusController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final palette = AppPalette.resolve(
          option: _controller.settings.themeMode,
          isOled: _controller.settings.pureBlackOled,
          systemBrightness: platformBrightness,
        );

        final isDark = palette.background.computeLuminance() < 0.2;

        return MaterialApp(
          title: 'Magn',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: palette.background,
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            child: MainWorkspaceScreen(
              controller: _controller,
              palette: palette,
            ),
          ),
        );
      },
    );
  }
}

/// The main workspace screen with upper 62% controls and bottom task peek sheet.
class MainWorkspaceScreen extends StatelessWidget {
  final FocusController controller;
  final AppPalette palette;

  const MainWorkspaceScreen({
    super.key,
    required this.controller,
    required this.palette,
  });

  void _openAnalytics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AnalyticsSheet(
        controller: controller,
        palette: palette,
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(
        controller: controller,
        palette: palette,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final upperHeight = screenHeight * 0.62;
    final isRunning = controller.isRunning;
    final minSheetSize = isRunning ? 0.05 : 0.19;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Upper 62%: Top bar, Center stage, and Play/Stop controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: upperHeight,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(
                    controller: controller,
                    palette: palette,
                    onOpenAnalytics: () => _openAnalytics(context),
                    onOpenSettings: () => _openSettings(context),
                  ),
                  const Spacer(),
                  _CenterStage(
                    controller: controller,
                    palette: palette,
                  ),
                  const Spacer(),
                  _BottomControls(
                    controller: controller,
                    palette: palette,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Floating Hint Row directly above the top edge of the sheet
          Positioned(
            bottom: (screenHeight * minSheetSize) + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: palette.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    controller.pendingTaskCount > 0
                        ? '${controller.pendingTaskCount} pending tasks'
                        : 'No pending tasks',
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pull-Up Task Peek Sheet at the bottom
          _TaskPeekSheet(
            controller: controller,
            palette: palette,
            minSize: minSheetSize,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Top Bar Widget
// ----------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final FocusController controller;
  final AppPalette palette;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenSettings;

  const _TopBar({
    required this.controller,
    required this.palette,
    required this.onOpenAnalytics,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = controller.isRunning;
    final isEndless = controller.mode == AppMode.endless;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top-Left Icon-Only Segmented Pill (Endless vs Cycle Mode)
          Opacity(
            opacity: isRunning ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Endless Mode Segment
                  GestureDetector(
                    onTap: isRunning
                        ? null
                        : () => controller.setMode(AppMode.endless),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isEndless ? palette.border : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.all_inclusive_rounded,
                        size: 20,
                        color: isEndless
                            ? palette.primaryText
                            : palette.secondaryText,
                      ),
                    ),
                  ),
                  // Cycle Mode Segment
                  GestureDetector(
                    onTap: isRunning
                        ? null
                        : () => controller.setMode(AppMode.cycle),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: !isEndless ? palette.border : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.timelapse_rounded,
                        size: 20,
                        color: !isEndless
                            ? palette.primaryText
                            : palette.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-Right IconButtons (8px gap)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border, width: 1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  color: palette.primaryText,
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: onOpenAnalytics,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border, width: 1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  color: palette.primaryText,
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: onOpenSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Center Stage & Tactile Rotating Dial CustomPainter
// ----------------------------------------------------------------------------

class _CenterStage extends StatelessWidget {
  final FocusController controller;
  final AppPalette palette;

  const _CenterStage({
    required this.controller,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.settings.showDigits) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotaryDialView(
            isRunning: controller.isRunning,
            isInFlow: controller.isInFlow,
            currentElapsedSeconds: controller.currentElapsedSeconds,
            personalizedIgnitionThreshold:
                controller.personalizedIgnitionThreshold,
            palette: palette,
          ),
          if (controller.mode == AppMode.cycle) ...[
            const SizedBox(height: 16),
            _CycleDots(
              currentCycle: controller.cycleIndex,
              palette: palette,
            ),
          ],
        ],
      );
    }

    // Numerical Digits Mode
    final elapsedSec = controller.currentElapsedSeconds;
    final formatted = _formatElapsedTime(elapsedSec);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.mode == AppMode.endless)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatted,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 68,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (controller.settings.showCentiseconds)
                Text(
                  '.${((controller.endlessElapsedMs % 1000) ~/ 10).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          )
        else
          Text(
            _formatElapsedTime(controller.cycleRemainingSeconds),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 68,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (controller.mode == AppMode.cycle) ...[
          const SizedBox(height: 16),
          _CycleDots(
            currentCycle: controller.cycleIndex,
            palette: palette,
          ),
        ],
      ],
    );
  }
}

/// Tactile rotating dial driven by a 12-second repeating AnimationController.
class RotaryDialView extends StatefulWidget {
  final bool isRunning;
  final bool isInFlow;
  final int currentElapsedSeconds;
  final int personalizedIgnitionThreshold;
  final AppPalette palette;

  const RotaryDialView({
    super.key,
    required this.isRunning,
    required this.isInFlow,
    required this.currentElapsedSeconds,
    required this.personalizedIgnitionThreshold,
    required this.palette,
  });

  @override
  State<RotaryDialView> createState() => _RotaryDialViewState();
}

class _RotaryDialViewState extends State<RotaryDialView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dialController;

  @override
  void initState() {
    super.initState();
    _dialController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isRunning) {
      _dialController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotaryDialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _dialController.repeat();
      } else {
        _dialController.stop();
      }
    }
  }

  @override
  void dispose() {
    _dialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dialController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(260, 260),
          painter: _RotaryDialPainter(
            rotationAngle: _dialController.value * 2 * math.pi,
            isInFlow: widget.isInFlow,
            currentElapsedSeconds: widget.currentElapsedSeconds,
            personalizedIgnitionThreshold:
                widget.personalizedIgnitionThreshold,
            palette: widget.palette,
          ),
        );
      },
    );
  }
}

class _RotaryDialPainter extends CustomPainter {
  final double rotationAngle;
  final bool isInFlow;
  final int currentElapsedSeconds;
  final int personalizedIgnitionThreshold;
  final AppPalette palette;

  const _RotaryDialPainter({
    required this.rotationAngle,
    required this.isInFlow,
    required this.currentElapsedSeconds,
    required this.personalizedIgnitionThreshold,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // 1. Stationary outer ring of 36 tiny 2px circular tick dots spaced every 10 degrees at radius 122px
    const tickRadius = 122.0;
    final progress = isInFlow
        ? 1.0
        : (personalizedIgnitionThreshold > 0
            ? (currentElapsedSeconds / personalizedIgnitionThreshold)
                .clamp(0.0, 1.0)
            : 0.0);
    final activeTicks = isInFlow ? 36 : (progress * 36).floor();

    for (int i = 0; i < 36; i++) {
      final angle = (i * 10.0) * math.pi / 180.0;
      final tickPos = Offset(
        c.dx + tickRadius * math.cos(angle),
        c.dy + tickRadius * math.sin(angle),
      );
      final isAccent = i < activeTicks;
      canvas.drawCircle(
        tickPos,
        1.0, // 2px diameter
        Paint()
          ..color = isAccent ? palette.accent : palette.border
          ..style = PaintingStyle.fill,
      );
    }

    // 2. Stationary 212px diameter circular platter in solid surface color with 1px border
    const platterRadius = 106.0;
    canvas.drawCircle(
      c,
      platterRadius,
      Paint()
        ..color = palette.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      platterRadius,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 3. Rotating Canvas Layer
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotationAngle);

    // Asymmetric high-contrast inner rotor lobe in primaryText color
    // A circle of radius 60px offset by 8px with a smooth sweeping lobe reaching radius 92px
    const lobeCenter = Offset(8, 0);
    const baseR = 60.0;
    final lobePath = Path();
    lobePath.moveTo(lobeCenter.dx, lobeCenter.dy - baseR);
    lobePath.arcTo(
      Rect.fromCircle(center: lobeCenter, radius: baseR),
      -math.pi / 2,
      math.pi,
      false,
    );
    lobePath.quadraticBezierTo(92, 36, 92, 0);
    lobePath.quadraticBezierTo(92, -36, lobeCenter.dx, lobeCenter.dy - baseR);
    lobePath.close();

    canvas.drawPath(
      lobePath,
      Paint()
        ..color = palette.primaryText
        ..style = PaintingStyle.fill,
    );

    // 3 pill-shaped radial capsule index markers (16px long, 5px wide, borderRadius 2.5px at 0, 135, 240 deg)
    for (final deg in [0.0, 135.0, 240.0]) {
      final rad = deg * math.pi / 180.0;
      canvas.save();
      canvas.rotate(rad);
      canvas.translate(80, 0);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 5),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = palette.surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = palette.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    }

    // 24px center spindle circle (radius 12px) in surface color, shifting to accent in Flow State
    canvas.drawCircle(
      Offset.zero,
      12.0,
      Paint()
        ..color = isInFlow ? palette.accent : palette.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      12.0,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RotaryDialPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.isInFlow != isInFlow ||
        oldDelegate.currentElapsedSeconds != currentElapsedSeconds ||
        oldDelegate.palette != palette;
  }
}

class _CycleDots extends StatelessWidget {
  final int currentCycle;
  final AppPalette palette;

  const _CycleDots({
    required this.currentCycle,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isFilled = index < currentCycle;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? palette.accent : palette.border,
          ),
        );
      }),
    );
  }
}

// ----------------------------------------------------------------------------
// Bottom Controls Widget
// ----------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  final FocusController controller;
  final AppPalette palette;

  const _BottomControls({
    required this.controller,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = controller.isRunning;
    final isCycle = controller.mode == AppMode.cycle;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Primary Pill Button (Height 60, Width 120, Radius 30)
        GestureDetector(
          onTap: controller.toggleTimer,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 60,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: isRunning ? palette.surface : palette.accent,
              border:
                  isRunning ? Border.all(color: palette.accent, width: 1) : null,
            ),
            child: Center(
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 32,
                color: isRunning ? palette.accent : palette.background,
              ),
            ),
          ),
        ),

        // Secondary Cycle Phase Skip Button (48px circular)
        if (isCycle) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: controller.skipCyclePhase,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surface,
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.skip_next_rounded,
                  size: 24,
                  color: palette.primaryText,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Non-Intrusive Pull-Up Task Peek Sheet
// ----------------------------------------------------------------------------

class _TaskPeekSheet extends StatefulWidget {
  final FocusController controller;
  final AppPalette palette;
  final double minSize;

  const _TaskPeekSheet({
    required this.controller,
    required this.palette,
    required this.minSize,
  });

  @override
  State<_TaskPeekSheet> createState() => _TaskPeekSheetState();
}

class _TaskPeekSheetState extends State<_TaskPeekSheet> {
  final TextEditingController _taskInputController = TextEditingController();

  @override
  void dispose() {
    _taskInputController.dispose();
    super.dispose();
  }

  void _submitTask() {
    final text = _taskInputController.text;
    if (text.trim().isNotEmpty) {
      widget.controller.addTask(text);
      _taskInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final palette = widget.palette;
    final linkedTask = controller.linkedTask;

    final activeTasks =
        controller.tasks.where((t) => !t.isCompleted && !t.isDeferred).toList();
    final deferredTasks =
        controller.tasks.where((t) => !t.isCompleted && t.isDeferred).toList();
    final completedTasks =
        controller.tasks.where((t) => t.isCompleted).toList();

    return DraggableScrollableSheet(
      minChildSize: widget.minSize,
      initialChildSize: widget.minSize,
      maxChildSize: 0.78,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: palette.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Top drag handle pill (36px wide, 4px high, borderRadius 2px)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Collapsed Peek Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: linkedTask != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: palette.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        linkedTask.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.primaryText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () =>
                                      controller.linkTask(linkedTask.id),
                                  child: Text(
                                    'Linked • Tap to unlink',
                                    style: TextStyle(
                                      color: palette.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Pull up to choose or skip tasks',
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    _StackedCardCounter(
                      count: controller.pendingTaskCount,
                      palette: palette,
                    ),
                  ],
                ),
              ),

              // Expanded Task Lists
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    // Task Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _taskInputController,
                              style: TextStyle(
                                  color: palette.primaryText, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Add a task for today...',
                                hintStyle:
                                    TextStyle(color: palette.secondaryText),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _submitTask(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_rounded,
                                color: palette.accent, size: 22),
                            onPressed: _submitTask,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Active Today Section
                    _sectionHeader(
                        'Active Today (${activeTasks.length})', palette),
                    if (activeTasks.isEmpty)
                      _emptyMessage('No active tasks. Tap + to add one.', palette)
                    else
                      ...activeTasks.map((t) => _taskRow(t, controller, palette)),

                    const SizedBox(height: 18),

                    // Not Today (Deferred) Section
                    if (deferredTasks.isNotEmpty) ...[
                      _sectionHeader(
                          'Not Today (${deferredTasks.length})', palette),
                      ...deferredTasks
                          .map((t) => _taskRow(t, controller, palette)),
                      const SizedBox(height: 18),
                    ],

                    // Completed Section
                    if (completedTasks.isNotEmpty) ...[
                      _sectionHeader(
                          'Completed (${completedTasks.length})', palette),
                      ...completedTasks
                          .map((t) => _taskRow(t, controller, palette)),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: palette.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _emptyMessage(String text, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: TextStyle(color: palette.secondaryText, fontSize: 13),
      ),
    );
  }

  Widget _taskRow(
      TaskItem task, FocusController controller, AppPalette palette) {
    final isLinked = controller.linkedTaskId == task.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLinked
            ? palette.accent.withValues(alpha: 0.08)
            : palette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLinked ? palette.accent : palette.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Completion Check Circle
          GestureDetector(
            onTap: () => controller.toggleTaskComplete(task.id),
            child: Icon(
              task.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: task.isCompleted ? palette.accent : palette.secondaryText,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // Title & Telemetry (tap to link/unlink)
          Expanded(
            child: GestureDetector(
              onTap: () => controller.linkTask(task.id),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: task.isCompleted
                          ? palette.secondaryText
                          : palette.primaryText,
                      fontSize: 14,
                      fontWeight:
                          isLinked ? FontWeight.w600 : FontWeight.normal,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.focusSeconds > 0)
                    Text(
                      '${task.focusSeconds ~/ 60}m focus'
                      '${task.flowSeconds > 0 ? " • ${task.flowSeconds ~/ 60}m flow" : ""}',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 1-Tap Defer button (Icons.low_priority_rounded)
          if (!task.isCompleted)
            IconButton(
              icon: Icon(
                task.isDeferred
                    ? Icons.today_rounded
                    : Icons.low_priority_rounded,
                size: 18,
                color: palette.secondaryText,
              ),
              onPressed: () => controller.toggleTaskDeferred(task.id),
            ),

          // Delete button
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: palette.secondaryText,
            ),
            onPressed: () => controller.deleteTask(task.id),
          ),
        ],
      ),
    );
  }
}

class _StackedCardCounter extends StatelessWidget {
  final int count;
  final AppPalette palette;

  const _StackedCardCounter({
    required this.count,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background card tilted at -6 degrees
          Transform.rotate(
            angle: -6 * math.pi / 180,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Foreground card tilted at +6 degrees
          Transform.rotate(
            angle: 6 * math.pi / 180,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border, width: 1),
              ),
            ),
          ),
          // Overlapping pill badge on bottom-left
          Positioned(
            left: 0,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Analytics Bottom Sheet & MetricCard
// ----------------------------------------------------------------------------

class _AnalyticsSheet extends StatelessWidget {
  final FocusController controller;
  final AppPalette palette;

  const _AnalyticsSheet({
    required this.controller,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final tFlowMinutes = controller.personalizedIgnitionThreshold ~/ 60;
    final flowTotalStr = _formatDurationShort(controller.totalFlowSeconds);
    final ratioStr = '${controller.flowRatio}%';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Analytics',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 20, color: palette.secondaryText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // MetricCard Row: Ignition, Flow, Ratio
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            palette: palette,
                            label: 'Ignition',
                            value: '${tFlowMinutes}m',
                            subtext: '${controller.calibrationAccuracy}% cal',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            palette: palette,
                            label: 'Flow',
                            value: flowTotalStr,
                            subtext: 'Total',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            palette: palette,
                            label: 'Ratio',
                            value: ratioStr,
                            subtext: 'Efficiency',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 7-Day Stacked Bar Chart
                    _SevenDayStackedBarChart(
                      sessions: controller.sessions,
                      palette: palette,
                    ),
                    const SizedBox(height: 20),

                    // History Section Header
                    Text(
                      'History',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (controller.sessions.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Text(
                          'No sessions recorded yet.',
                          style: TextStyle(
                            color: palette.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...controller.sessions.map((session) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Dismissible(
                            key: ValueKey(session.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            onDismissed: (_) =>
                                controller.deleteSession(session.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: palette.border, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    session.mode == AppMode.endless
                                        ? Icons.all_inclusive_rounded
                                        : Icons.timelapse_rounded,
                                    size: 16,
                                    color: palette.secondaryText,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatElapsedTime(session.durationSeconds),
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (session.flowSeconds > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: palette.accent
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${session.flowSeconds ~/ 60}m flow',
                                        style: TextStyle(
                                          color: palette.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(session.timestamp),
                                    style: TextStyle(
                                      color: palette.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final String value;
  final String subtext;

  const MetricCard({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SevenDayStackedBarChart extends StatelessWidget {
  final List<SessionRecord> sessions;
  final AppPalette palette;

  const _SevenDayStackedBarChart({
    required this.sessions,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      int warmupSec = 0;
      int flowSec = 0;
      for (final s in sessions) {
        final sDate =
            DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
        if (sDate.isAtSameMomentAs(date)) {
          flowSec += s.flowSeconds;
          warmupSec += math.max(0, s.durationSeconds - s.flowSeconds);
        }
      }
      return _DayData(
        label: _weekdayLabel(date.weekday),
        warmupSeconds: warmupSec,
        flowSeconds: flowSec,
      );
    });

    int maxSec = 1800; // Minimum 30 mins scale
    for (final d in days) {
      if (d.totalSeconds > maxSec) {
        maxSec = d.totalSeconds;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Flow',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _legendDot(palette.border, 'Warm-Up'),
                  const SizedBox(width: 12),
                  _legendDot(palette.accent, 'Flow'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final warmupHeight = (day.warmupSeconds / maxSec) * 90;
                final flowHeight = (day.flowSeconds / maxSec) * 90;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Stacked Bar
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (flowHeight > 0)
                                Container(
                                  height: flowHeight.clamp(2.0, 90.0),
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    borderRadius: BorderRadius.vertical(
                                      top: const Radius.circular(3),
                                      bottom: Radius.circular(
                                          warmupHeight > 0 ? 0 : 3),
                                    ),
                                  ),
                                ),
                              if (warmupHeight > 0)
                                Container(
                                  height: warmupHeight.clamp(2.0, 90.0),
                                  decoration: BoxDecoration(
                                    color: palette.border,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(
                                          flowHeight > 0 ? 0 : 3),
                                      bottom: const Radius.circular(3),
                                    ),
                                  ),
                                ),
                              if (flowHeight == 0 && warmupHeight == 0)
                                Container(
                                  height: 2,
                                  color: palette.border.withValues(alpha: 0.3),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day.label,
                          style: TextStyle(
                            color: palette.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'S';
      default:
        return '';
    }
  }
}

class _DayData {
  final String label;
  final int warmupSeconds;
  final int flowSeconds;

  const _DayData({
    required this.label,
    required this.warmupSeconds,
    required this.flowSeconds,
  });

  int get totalSeconds => warmupSeconds + flowSeconds;
}

// ----------------------------------------------------------------------------
// Settings Bottom Sheet & File-Based Backup
// ----------------------------------------------------------------------------

class _SettingsSheet extends StatefulWidget {
  final FocusController controller;
  final AppPalette palette;

  const _SettingsSheet({
    required this.controller,
    required this.palette,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late AppSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = widget.controller.settings;
  }

  void _save(AppSettings updated) {
    setState(() => _localSettings = updated);
    widget.controller.updateSettings(updated);
  }

  Future<void> _exportBackupFile(BuildContext context) async {
    try {
      final now = DateTime.now();
      final yyyy = now.year.toString();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final fileName = 'focus_backup_${yyyy}${mm}${dd}.json';

      final jsonStr = widget.controller.exportFullJson();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);

      await Share.shareXFiles([XFile(file.path)], text: 'Magn Focus Backup');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup ready: $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackupFile(BuildContext context) async {
    final palette = widget.palette;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      String content;
      final fileObj = result.files.single;
      if (fileObj.path != null) {
        content = await File(fileObj.path!).readAsString();
      } else if (fileObj.bytes != null) {
        content = utf8.decode(fileObj.bytes!);
      } else {
        throw const FormatException('Unable to read selected file');
      }

      // Defensive validation
      final data = widget.controller.validateBackupJson(content);

      if (!context.mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Restore Backup',
              style: TextStyle(color: palette.primaryText, fontSize: 16)),
          content: Text(
            'Found ${data['sessionCount']} sessions and ${data['taskCount']} tasks.\n\nChoose how to restore:',
            style: TextStyle(color: palette.secondaryText, fontSize: 13),
          ),
          actions: [
            TextButton(
              child: Text('Cancel',
                  style: TextStyle(color: palette.secondaryText)),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.accent),
                foregroundColor: palette.accent,
              ),
              child: const Text('Merge'),
              onPressed: () {
                widget.controller.restoreBackup(
                    data['raw'] as Map<String, dynamic>,
                    merge: true);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup merged successfully')),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.background,
              ),
              child: const Text('Overwrite All'),
              onPressed: () {
                widget.controller.restoreBackup(
                    data['raw'] as Map<String, dynamic>,
                    merge: false);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Backup restored (all replaced)')),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup file: $e')),
        );
      }
    }
  }

  void _confirmReset(BuildContext context) {
    final palette = widget.palette;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Reset All Data?',
            style: TextStyle(color: palette.primaryText, fontSize: 16)),
        content: Text(
          'This will permanently delete all recorded focus sessions, tasks, and revert settings.',
          style: TextStyle(color: palette.secondaryText, fontSize: 13),
        ),
        actions: [
          TextButton(
            child:
                Text('Cancel', style: TextStyle(color: palette.secondaryText)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Everything'),
            onPressed: () async {
              await widget.controller.resetAllData();
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              setState(() {
                _localSettings = widget.controller.settings;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data has been reset')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 20, color: palette.secondaryText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Settings Sections
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // --- BEHAVIOR ---
                    Text(
                      'Behavior',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(
                              'Show Timer Digits',
                              style: TextStyle(
                                  color: palette.primaryText, fontSize: 14),
                            ),
                            subtitle: Text(
                              'When off, display tactile rotating dial',
                              style: TextStyle(
                                  color: palette.secondaryText, fontSize: 12),
                            ),
                            value: _localSettings.showDigits,
                            activeThumbColor: palette.accent,
                            onChanged: (val) {
                              _save(_localSettings.copyWith(showDigits: val));
                            },
                          ),
                          Divider(color: palette.border, height: 1),
                          SwitchListTile(
                            title: Text(
                              'Show Centiseconds',
                              style: TextStyle(
                                  color: palette.primaryText, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Render .00 digits in Endless mode',
                              style: TextStyle(
                                  color: palette.secondaryText, fontSize: 12),
                            ),
                            value: _localSettings.showCentiseconds,
                            activeThumbColor: palette.accent,
                            onChanged: (val) {
                              _save(_localSettings.copyWith(
                                  showCentiseconds: val));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- APPEARANCE ---
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _themePill(
                                    label: 'System',
                                    option: ThemeModeOption.system),
                                const SizedBox(width: 8),
                                _themePill(
                                    label: 'Light',
                                    option: ThemeModeOption.light),
                                const SizedBox(width: 8),
                                _themePill(
                                    label: 'Dark',
                                    option: ThemeModeOption.dark),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: palette.border, height: 1),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Pure Black OLED Mode',
                                style: TextStyle(
                                    color: palette.primaryText, fontSize: 14),
                              ),
                              value: _localSettings.pureBlackOled,
                              activeThumbColor: palette.accent,
                              onChanged: (val) {
                                _save(_localSettings.copyWith(
                                    pureBlackOled: val));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- DATA MANAGEMENT ---
                    Text(
                      'Data Management',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.file_upload_outlined,
                                color: palette.primaryText, size: 20),
                            title: Text('Export Backup File',
                                style: TextStyle(
                                    color: palette.primaryText, fontSize: 14)),
                            subtitle: Text('Save .json file with sessions and tasks',
                                style: TextStyle(
                                    color: palette.secondaryText, fontSize: 12)),
                            onTap: () => _exportBackupFile(context),
                          ),
                          Divider(color: palette.border, height: 1),
                          ListTile(
                            leading: Icon(Icons.file_download_outlined,
                                color: palette.primaryText, size: 20),
                            title: Text('Import Backup File',
                                style: TextStyle(
                                    color: palette.primaryText, fontSize: 14)),
                            subtitle: Text('Load .json file with merge or overwrite',
                                style: TextStyle(
                                    color: palette.secondaryText, fontSize: 12)),
                            onTap: () => _importBackupFile(context),
                          ),
                          Divider(color: palette.border, height: 1),
                          ListTile(
                            leading: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                            title: const Text('Reset All Data',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 14)),
                            onTap: () => _confirmReset(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themePill({
    required String label,
    required ThemeModeOption option,
  }) {
    final isSelected = _localSettings.themeMode == option;
    final palette = widget.palette;

    return Expanded(
      child: GestureDetector(
        onTap: () => _save(_localSettings.copyWith(themeMode: option)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? palette.accent : palette.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? palette.background : palette.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Utilities
// ----------------------------------------------------------------------------

String _formatElapsedTime(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  if (m >= 60) {
    final h = m ~/ 60;
    final remM = m % 60;
    return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatDurationShort(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  if (m >= 60) {
    final h = m ~/ 60;
    final remM = m % 60;
    return remM > 0 ? '${h}h ${remM}m' : '${h}h';
  }
  return '${m}m';
}

String _formatDate(DateTime dt) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = months[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, $hour:$minute';
}
