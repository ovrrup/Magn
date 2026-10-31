import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  pomodoro,
}

enum PomodoroPhase {
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

  const SessionRecord({
    required this.id,
    required this.durationSeconds,
    required this.flowSeconds,
    required this.timestamp,
    required this.mode,
    this.interruptions = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'durationSeconds': durationSeconds,
        'flowSeconds': flowSeconds,
        'timestamp': timestamp.toIso8601String(),
        'mode': mode.name,
        'interruptions': interruptions,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String? ?? UniqueKey().toString(),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        flowSeconds: json['flowSeconds'] as int? ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        mode: json['mode'] == 'pomodoro' ? AppMode.pomodoro : AppMode.endless,
        interruptions: json['interruptions'] as int? ?? 0,
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
        (option == ThemeModeOption.system && systemBrightness == Brightness.dark);
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

  // Pomodoro State Machine
  static const int _focusDurationSec = 25 * 60;
  static const int _shortBreakDurationSec = 5 * 60;
  static const int _longBreakDurationSec = 15 * 60;

  int _pomodoroCycle = 1; // 1 to 4
  int get pomodoroCycle => _pomodoroCycle;

  PomodoroPhase _pomodoroPhase = PomodoroPhase.focus;
  PomodoroPhase get pomodoroPhase => _pomodoroPhase;

  int _pomodoroRemainingSeconds = _focusDurationSec;
  int get pomodoroRemainingSeconds => _pomodoroRemainingSeconds;

  // Lifecycle Interruption Tracking
  int _sessionInterruptions = 0;
  int get sessionInterruptions => _sessionInterruptions;

  // Historical Session Records
  final List<SessionRecord> _sessions = [];
  List<SessionRecord> get sessions => List.unmodifiable(_sessions);

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

  /// Computes personalized Ignition Threshold T_flow in seconds.
  /// 85th percentile of Friction Zone durations blended with 32% of median deep session length.
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
    return blended.round().clamp(300, 1500); // Clamped between 5m and 25m
  }

  int get currentElapsedSeconds {
    if (_mode == AppMode.endless) {
      return _endlessElapsedMs ~/ 1000;
    } else {
      final totalPhaseSec = _pomodoroPhase == PomodoroPhase.focus
          ? _focusDurationSec
          : (_pomodoroPhase == PomodoroPhase.shortBreak
              ? _shortBreakDurationSec
              : _longBreakDurationSec);
      return totalPhaseSec - _pomodoroRemainingSeconds;
    }
  }

  int get currentFlowSeconds {
    if (!_isRunning) return 0;
    if (_mode == AppMode.pomodoro && _pomodoroPhase != PomodoroPhase.focus) {
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
        if (_pomodoroRemainingSeconds > 0) {
          _pomodoroRemainingSeconds--;
          notifyListeners();
        } else {
          _onPomodoroPhaseComplete();
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
      final flowSec = (_mode == AppMode.endless ||
              _pomodoroPhase == PomodoroPhase.focus)
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
      );
      _sessions.insert(0, session);
      _saveData();
    }

    _endlessElapsedMs = 0;
    if (_mode == AppMode.pomodoro) {
      _pomodoroRemainingSeconds = _pomodoroPhase == PomodoroPhase.focus
          ? _focusDurationSec
          : (_pomodoroPhase == PomodoroPhase.shortBreak
              ? _shortBreakDurationSec
              : _longBreakDurationSec);
    }

    notifyListeners();
  }

  void skipPomodoroPhase() {
    if (_mode != AppMode.pomodoro) return;
    _onPomodoroPhaseComplete(userInitiated: true);
  }

  void _onPomodoroPhaseComplete({bool userInitiated = false}) {
    if (_pomodoroPhase == PomodoroPhase.focus) {
      if (_pomodoroCycle < 4) {
        _pomodoroPhase = PomodoroPhase.shortBreak;
        _pomodoroRemainingSeconds = _shortBreakDurationSec;
      } else {
        _pomodoroPhase = PomodoroPhase.longBreak;
        _pomodoroRemainingSeconds = _longBreakDurationSec;
      }
    } else if (_pomodoroPhase == PomodoroPhase.shortBreak) {
      _pomodoroCycle++;
      _pomodoroPhase = PomodoroPhase.focus;
      _pomodoroRemainingSeconds = _focusDurationSec;
    } else if (_pomodoroPhase == PomodoroPhase.longBreak) {
      _pomodoroCycle = 1;
      _pomodoroPhase = PomodoroPhase.focus;
      _pomodoroRemainingSeconds = _focusDurationSec;
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

  // --- Persistence ---

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
      notifyListeners();
    } catch (_) {
      // Graceful fallback to default values
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('magn_settings', jsonEncode(_settings.toJson()));
      await prefs.setString(
        'magn_sessions',
        jsonEncode(_sessions.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  String exportJson() {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settings.toJson(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
    });
  }

  bool importJson(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      if (map.containsKey('settings')) {
        _settings =
            AppSettings.fromJson(map['settings'] as Map<String, dynamic>);
      }
      if (map.containsKey('sessions')) {
        final list = map['sessions'] as List<dynamic>;
        _sessions.clear();
        for (final item in list) {
          _sessions.add(SessionRecord.fromJson(item as Map<String, dynamic>));
        }
      }
      _saveData();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetAllData() async {
    _sessions.clear();
    _settings = const AppSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('magn_settings');
    await prefs.remove('magn_sessions');
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

/// The flat, wordless main workspace screen.
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
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Bar
            Align(
              alignment: Alignment.topCenter,
              child: _TopBar(
                controller: controller,
                palette: palette,
                onOpenAnalytics: () => _openAnalytics(context),
                onOpenSettings: () => _openSettings(context),
              ),
            ),

            // Center Stage
            Center(
              child: _CenterStage(
                controller: controller,
                palette: palette,
              ),
            ),

            // Bottom Controls (56px from bottom)
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomControls(
                controller: controller,
                palette: palette,
              ),
            ),
          ],
        ),
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
          // Top-Left Icon-Only Segmented Pill
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
                  // Pomodoro Mode Segment
                  GestureDetector(
                    onTap: isRunning
                        ? null
                        : () => controller.setMode(AppMode.pomodoro),
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
// Center Stage Widget
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
      // Flat 2px Stroke Circle
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: controller.isInFlow
                    ? palette.accent
                    : palette.secondaryText,
                width: 2,
              ),
            ),
          ),
          if (controller.mode == AppMode.pomodoro) ...[
            const SizedBox(height: 24),
            _PomodoroDots(
              currentCycle: controller.pomodoroCycle,
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
            _formatElapsedTime(controller.pomodoroRemainingSeconds),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 68,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (controller.mode == AppMode.pomodoro) ...[
          const SizedBox(height: 24),
          _PomodoroDots(
            currentCycle: controller.pomodoroCycle,
            palette: palette,
          ),
        ],
      ],
    );
  }
}

class _PomodoroDots extends StatelessWidget {
  final int currentCycle;
  final AppPalette palette;

  const _PomodoroDots({
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
    final isPomodoro = controller.mode == AppMode.pomodoro;

    return Padding(
      padding: const EdgeInsets.only(bottom: 56.0),
      child: Row(
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
                border: isRunning
                    ? Border.all(color: palette.accent, width: 1)
                    : null,
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

          // Secondary Pomodoro Phase Skip Button (48px circular)
          if (isPomodoro) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: controller.skipPomodoroPhase,
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
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Bento Analytics & History Bottom Sheet
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
                    // Bento Row: Ignition, Flow, Ratio
                    Row(
                      children: [
                        Expanded(
                          child: _BentoCard(
                            palette: palette,
                            label: 'Ignition',
                            value: '${tFlowMinutes}m',
                            subtext: '${controller.calibrationAccuracy}% cal',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BentoCard(
                            palette: palette,
                            label: 'Flow',
                            value: flowTotalStr,
                            subtext: 'Total',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BentoCard(
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

class _BentoCard extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final String value;
  final String subtext;

  const _BentoCard({
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
// Settings Bottom Sheet
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
                              'When off, display minimal breathing circle',
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
                            title: Text('Export JSON',
                                style: TextStyle(
                                    color: palette.primaryText, fontSize: 14)),
                            onTap: () {
                              final jsonStr = widget.controller.exportJson();
                              Clipboard.setData(ClipboardData(text: jsonStr));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Backup copied to clipboard')),
                              );
                            },
                          ),
                          Divider(color: palette.border, height: 1),
                          ListTile(
                            leading: Icon(Icons.file_download_outlined,
                                color: palette.primaryText, size: 20),
                            title: Text('Import JSON',
                                style: TextStyle(
                                    color: palette.primaryText, fontSize: 14)),
                            onTap: () => _showImportDialog(context),
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

  void _showImportDialog(BuildContext context) {
    final textController = TextEditingController();
    final palette = widget.palette;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Import JSON',
            style: TextStyle(color: palette.primaryText, fontSize: 16)),
        content: TextField(
          controller: textController,
          maxLines: 5,
          style: TextStyle(color: palette.primaryText, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Paste valid JSON export here',
            hintStyle: TextStyle(color: palette.secondaryText),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: palette.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            child:
                Text('Cancel', style: TextStyle(color: palette.secondaryText)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.background,
            ),
            child: const Text('Import'),
            onPressed: () {
              final ok = widget.controller.importJson(textController.text);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Data imported successfully'
                      : 'Failed to parse JSON backup'),
                ),
              );
            },
          ),
        ],
      ),
    );
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
          'This will permanently delete all recorded focus sessions and revert settings.',
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
