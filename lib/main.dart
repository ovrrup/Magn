import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StopwatchApp());
}

// Brand Chromatics
const Color _deepRed = Color(0xFFAA0003);
const Color _coralPink = Color(0xFFFF6B6B);
const Color _warmCream = Color(0xFFFFEDD5);

/// Active timing mode of the application.
enum AppMode { endless, pomodoro }

/// Active phase within Pomodoro cycle.
enum PomodoroPhase { focus, shortBreak, longBreak }

/// Theme mode selector options.
enum ThemeModeOption { system, light, dark }

/// Model representing a completed session record with flow state metrics.
class SessionRecord {
  final int durationInSeconds;
  final int warmUpSeconds;
  final int flowSeconds;
  final AppMode mode;
  final DateTime timestamp;
  final int interruptions;

  const SessionRecord({
    required this.durationInSeconds,
    required this.warmUpSeconds,
    required this.flowSeconds,
    required this.mode,
    required this.timestamp,
    this.interruptions = 0,
  });

  Map<String, dynamic> toJson() => {
        'durationInSeconds': durationInSeconds,
        'warmUpSeconds': warmUpSeconds,
        'flowSeconds': flowSeconds,
        'mode': mode.name,
        'timestamp': timestamp.toIso8601String(),
        'interruptions': interruptions,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        durationInSeconds: json['durationInSeconds'] as int? ?? 0,
        warmUpSeconds: json['warmUpSeconds'] as int? ?? 0,
        flowSeconds: json['flowSeconds'] as int? ?? 0,
        mode: (json['mode'] as String?) == 'pomodoro'
            ? AppMode.pomodoro
            : AppMode.endless,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        interruptions: json['interruptions'] as int? ?? 0,
      );
}

/// Root widget of the Magn application.
class StopwatchApp extends StatefulWidget {
  const StopwatchApp({super.key});

  @override
  State<StopwatchApp> createState() => _StopwatchAppState();
}

class _StopwatchAppState extends State<StopwatchApp> {
  ThemeModeOption _themeMode = ThemeModeOption.system;

  void updateThemeMode(ThemeModeOption option) {
    setState(() {
      _themeMode = option;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeMode mode;
    switch (_themeMode) {
      case ThemeModeOption.light:
        mode = ThemeMode.light;
        break;
      case ThemeModeOption.dark:
        mode = ThemeMode.dark;
        break;
      case ThemeModeOption.system:
        mode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Magn',
      themeMode: mode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _warmCream,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A0001),
        fontFamily: 'Roboto',
      ),
      home: StopwatchScreen(
        onThemeChanged: updateThemeMode,
      ),
    );
  }
}

/// The primary Stopwatch Screen featuring Flow Orb, Calibration Engine,
/// and native frosted glass mosaic.
class StopwatchScreen extends StatefulWidget {
  final ValueChanged<ThemeModeOption>? onThemeChanged;

  const StopwatchScreen({
    super.key,
    this.onThemeChanged,
  });

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Ambient Drift & Flow Orb Animation Controllers
  late final AnimationController _driftController;
  late final AnimationController _orbController;

  // Mode and Timer State
  AppMode _mode = AppMode.endless;
  bool _isRunning = false;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  final List<SessionRecord> _sessions = [];

  // Endless Mode
  int _endlessElapsedMs = 0;

  // Pomodoro State Machine (25m Focus, 5m Short Break x 4, 15m Long Break)
  static const int _focusDurationSec = 25 * 60;
  static const int _shortBreakDurationSec = 5 * 60;
  static const int _longBreakDurationSec = 15 * 60;

  int _pomodoroCycle = 1;
  PomodoroPhase _pomodoroPhase = PomodoroPhase.focus;
  int _pomodoroRemainingSeconds = _focusDurationSec;

  // Flow State & Interruption Tracking
  int _currentSessionInterruptions = 0;
  DateTime? _lastBreakEndedAt;
  bool _breakChainActive = false;

  // Settings & Behavior Toggles
  bool _showDigits = false; // Default false for Digit-Free Flow Orb mode
  bool _showCentiseconds = true; // Default true (.00)
  ThemeModeOption _themeOption = ThemeModeOption.system;
  bool _pureBlackOled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driftController.dispose();
    _orbController.dispose();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isRunning) {
      _currentSessionInterruptions++;
    }
  }

  // --- Persistence & Data Management ---

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsRaw = prefs.getString('magn_sessions');
      if (sessionsRaw != null) {
        final decoded = jsonDecode(sessionsRaw) as List<dynamic>;
        setState(() {
          _sessions.clear();
          for (final item in decoded) {
            _sessions.add(SessionRecord.fromJson(item as Map<String, dynamic>));
          }
        });
      }

      setState(() {
        _showDigits = prefs.getBool('magn_show_digits') ?? false;
        _showCentiseconds = prefs.getBool('magn_show_centiseconds') ?? true;
        _pureBlackOled = prefs.getBool('magn_pure_black_oled') ?? false;
        final themeIdx = prefs.getInt('magn_theme_mode') ?? 0;
        _themeOption = ThemeModeOption.values[themeIdx.clamp(0, 2)];
      });
      widget.onThemeChanged?.call(_themeOption);
    } catch (_) {
      // Graceful fallback for unit tests or initial storage setup
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson =
          jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString('magn_sessions', sessionsJson);
      await prefs.setBool('magn_show_digits', _showDigits);
      await prefs.setBool('magn_show_centiseconds', _showCentiseconds);
      await prefs.setBool('magn_pure_black_oled', _pureBlackOled);
      await prefs.setInt('magn_theme_mode', _themeOption.index);
    } catch (_) {
      // Non-fatal if storage is mocked or read-only
    }
  }

  // --- Self-Personalizing Flow Calibration Engine ---

  /// Computes the user's personal Ignition Threshold (T_flow) in seconds.
  /// Identifies sessions under 18m or with interruptions as the Friction Zone,
  /// calculates the 85th percentile of the Friction Zone blended with 32% of median deep session length.
  /// Defaults to 10 minutes (600s), clamped between 5m (300s) and 25m (1500s).
  int get personalizedIgnitionThreshold {
    if (_sessions.isEmpty) {
      return 600;
    }

    // 1. Friction Zone: sessions < 18m (1080s) or with background interruptions
    final frictionDurations = _sessions
        .where((s) => s.durationInSeconds < 1080 || s.interruptions > 0)
        .map((s) => s.durationInSeconds)
        .toList();

    // 2. Deep Focus Sessions: >= 18m and zero interruptions
    final deepDurations = _sessions
        .where((s) => s.durationInSeconds >= 1080 && s.interruptions == 0)
        .map((s) => s.durationInSeconds)
        .toList();

    double p85Friction;
    if (frictionDurations.isNotEmpty) {
      frictionDurations.sort();
      final idx = ((frictionDurations.length - 1) * 0.85).round();
      p85Friction = frictionDurations[idx].toDouble();
    } else {
      p85Friction = 600.0;
    }

    double medianDeep;
    if (deepDurations.isNotEmpty) {
      deepDurations.sort();
      final mid = deepDurations.length ~/ 2;
      medianDeep = deepDurations.length % 2 == 1
          ? deepDurations[mid].toDouble()
          : (deepDurations[mid - 1] + deepDurations[mid]) / 2.0;
    } else {
      medianDeep = 1800.0;
    }

    // Blend: 85th percentile of Friction Zone blended with 32% of median deep length
    final deepComponent = medianDeep * 0.32;
    final blended = (p85Friction * 0.68) + (deepComponent * 0.32);

    // Pomodoro Break-Chain Carryover: if starting next focus within 60s of break ending
    if (_mode == AppMode.pomodoro &&
        _pomodoroPhase == PomodoroPhase.focus &&
        _breakChainActive) {
      return 120;
    }

    final interruptionPenalty = _currentSessionInterruptions * 180;
    final clamped = blended.clamp(300.0, 1500.0).round();
    return clamped + interruptionPenalty;
  }

  /// Accuracy percentage based on total sessions logged (100% at 15+ sessions).
  int get calibrationAccuracyPercent {
    if (_sessions.isEmpty) return 0;
    final ratio = (_sessions.length / 15.0).clamp(0.0, 1.0);
    return (ratio * 100).round();
  }

  int get currentElapsedSeconds {
    if (_mode == AppMode.endless) {
      return _endlessElapsedMs ~/ 1000;
    } else {
      final totalPhaseSec = _getPhaseTotalSeconds(_pomodoroPhase);
      return totalPhaseSec - _pomodoroRemainingSeconds;
    }
  }

  int get currentWarmUpSeconds {
    final elapsed = currentElapsedSeconds;
    final threshold = personalizedIgnitionThreshold;
    if (_mode == AppMode.pomodoro && _pomodoroPhase != PomodoroPhase.focus) {
      return 0;
    }
    return elapsed < threshold ? elapsed : threshold;
  }

  int get currentFlowSeconds {
    final elapsed = currentElapsedSeconds;
    final threshold = personalizedIgnitionThreshold;
    if (_mode == AppMode.pomodoro && _pomodoroPhase != PomodoroPhase.focus) {
      return 0;
    }
    return elapsed > threshold ? elapsed - threshold : 0;
  }

  int _getPhaseTotalSeconds(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.focus:
        return _focusDurationSec;
      case PomodoroPhase.shortBreak:
        return _shortBreakDurationSec;
      case PomodoroPhase.longBreak:
        return _longBreakDurationSec;
    }
  }

  String get _pomodoroPhaseLabel {
    switch (_pomodoroPhase) {
      case PomodoroPhase.focus:
        return 'FOCUS';
      case PomodoroPhase.shortBreak:
        return 'SHORT BREAK';
      case PomodoroPhase.longBreak:
        return 'LONG BREAK';
    }
  }

  // --- Mode Switching & Controls ---

  void _toggleMode() {
    if (_isRunning) return;
    setState(() {
      _mode = _mode == AppMode.endless ? AppMode.pomodoro : AppMode.endless;
      _endlessElapsedMs = 0;
      _stopwatch.reset();
      _pomodoroCycle = 1;
      _pomodoroPhase = PomodoroPhase.focus;
      _pomodoroRemainingSeconds = _focusDurationSec;
      _breakChainActive = false;
      _currentSessionInterruptions = 0;
    });
  }

  void _startTimer() {
    _timer?.cancel();

    if (_mode == AppMode.endless) {
      _stopwatch.reset();
      _stopwatch.start();
      _currentSessionInterruptions = 0;
      setState(() {
        _endlessElapsedMs = 0;
        _isRunning = true;
      });

      _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        setState(() {
          _endlessElapsedMs = _stopwatch.elapsedMilliseconds;
        });
      });
    } else {
      if (_pomodoroPhase == PomodoroPhase.focus) {
        if (_lastBreakEndedAt != null &&
            DateTime.now().difference(_lastBreakEndedAt!).inSeconds <= 60) {
          _breakChainActive = true;
        } else {
          _breakChainActive = false;
        }
        _currentSessionInterruptions = 0;
      }

      setState(() {
        _isRunning = true;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_pomodoroRemainingSeconds > 0) {
          setState(() {
            _pomodoroRemainingSeconds--;
          });
        } else {
          _onPomodoroPhaseCompleted();
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;

    if (_mode == AppMode.endless) {
      _stopwatch.stop();
      final totalSec = _endlessElapsedMs ~/ 1000;
      if (totalSec >= 1) {
        _sessions.add(
          SessionRecord(
            durationInSeconds: totalSec,
            warmUpSeconds: currentWarmUpSeconds,
            flowSeconds: currentFlowSeconds,
            mode: AppMode.endless,
            timestamp: DateTime.now(),
            interruptions: _currentSessionInterruptions,
          ),
        );
        _saveData();
      }
      setState(() {
        _isRunning = false;
        _endlessElapsedMs = 0;
        _currentSessionInterruptions = 0;
      });
    } else {
      final elapsed = currentElapsedSeconds;
      if (_pomodoroPhase == PomodoroPhase.focus && elapsed >= 1) {
        _sessions.add(
          SessionRecord(
            durationInSeconds: elapsed,
            warmUpSeconds: currentWarmUpSeconds,
            flowSeconds: currentFlowSeconds,
            mode: AppMode.pomodoro,
            timestamp: DateTime.now(),
            interruptions: _currentSessionInterruptions,
          ),
        );
        _saveData();
      }
      setState(() {
        _isRunning = false;
        _pomodoroRemainingSeconds = _getPhaseTotalSeconds(_pomodoroPhase);
        _currentSessionInterruptions = 0;
      });
    }
  }

  void _onPomodoroPhaseCompleted() {
    _timer?.cancel();
    _timer = null;

    if (_pomodoroPhase == PomodoroPhase.focus) {
      _sessions.add(
        SessionRecord(
          durationInSeconds: _focusDurationSec,
          warmUpSeconds: currentWarmUpSeconds,
          flowSeconds: currentFlowSeconds,
          mode: AppMode.pomodoro,
          timestamp: DateTime.now(),
          interruptions: _currentSessionInterruptions,
        ),
      );
      _saveData();

      if (_pomodoroCycle < 4) {
        _pomodoroPhase = PomodoroPhase.shortBreak;
        _pomodoroRemainingSeconds = _shortBreakDurationSec;
      } else {
        _pomodoroPhase = PomodoroPhase.longBreak;
        _pomodoroRemainingSeconds = _longBreakDurationSec;
      }
    } else {
      _lastBreakEndedAt = DateTime.now();
      if (_pomodoroCycle < 4) {
        _pomodoroCycle++;
      } else {
        _pomodoroCycle = 1;
      }
      _pomodoroPhase = PomodoroPhase.focus;
      _pomodoroRemainingSeconds = _focusDurationSec;
    }

    setState(() {
      _isRunning = false;
      _currentSessionInterruptions = 0;
    });
  }

  void _skipPomodoroPhase() {
    _timer?.cancel();
    _timer = null;

    if (_pomodoroPhase == PomodoroPhase.focus) {
      final elapsed = currentElapsedSeconds;
      if (elapsed >= 1) {
        _sessions.add(
          SessionRecord(
            durationInSeconds: elapsed,
            warmUpSeconds: currentWarmUpSeconds,
            flowSeconds: currentFlowSeconds,
            mode: AppMode.pomodoro,
            timestamp: DateTime.now(),
            interruptions: _currentSessionInterruptions,
          ),
        );
        _saveData();
      }
      if (_pomodoroCycle < 4) {
        _pomodoroPhase = PomodoroPhase.shortBreak;
        _pomodoroRemainingSeconds = _shortBreakDurationSec;
      } else {
        _pomodoroPhase = PomodoroPhase.longBreak;
        _pomodoroRemainingSeconds = _longBreakDurationSec;
      }
    } else {
      _lastBreakEndedAt = DateTime.now();
      if (_pomodoroCycle < 4) {
        _pomodoroCycle++;
      } else {
        _pomodoroCycle = 1;
      }
      _pomodoroPhase = PomodoroPhase.focus;
      _pomodoroRemainingSeconds = _focusDurationSec;
    }

    setState(() {
      _isRunning = false;
      _currentSessionInterruptions = 0;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  // --- Formatting Helpers ---

  String _formatElapsedTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  String _formatTimestamp(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // --- Modals: Analytics Dashboard & Settings Screen ---

  void _openAnalyticsDashboard() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _pureBlackOled && _isDarkMode
          ? Colors.black
          : _warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _AnalyticsDashboardSheet(
          sessions: _sessions,
          ignitionThreshold: personalizedIgnitionThreshold,
          accuracyPercent: calibrationAccuracyPercent,
          isPureBlack: _pureBlackOled && _isDarkMode,
          formatDuration: _formatDuration,
          formatTimestamp: _formatTimestamp,
          onDeleteSession: (index) {
            setState(() {
              _sessions.removeAt(index);
            });
            _saveData();
          },
        );
      },
    );
  }

  void _openSettingsScreen() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _pureBlackOled && _isDarkMode
          ? Colors.black
          : _warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _SettingsSheet(
          showDigits: _showDigits,
          showCentiseconds: _showCentiseconds,
          themeOption: _themeOption,
          pureBlackOled: _pureBlackOled,
          isPureBlack: _pureBlackOled && _isDarkMode,
          onShowDigitsChanged: (val) {
            setState(() => _showDigits = val);
            _saveData();
          },
          onShowCentisecondsChanged: (val) {
            setState(() => _showCentiseconds = val);
            _saveData();
          },
          onThemeChanged: (option) {
            setState(() => _themeOption = option);
            widget.onThemeChanged?.call(option);
            _saveData();
          },
          onPureBlackChanged: (val) {
            setState(() => _pureBlackOled = val);
            _saveData();
          },
          onExportData: _exportData,
          onImportData: _importData,
          onDeleteAllData: _deleteAllData,
        );
      },
    );
  }

  // --- Data Management Actions ---

  Future<void> _exportData() async {
    final payload = {
      'app': 'Magn',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'showDigits': _showDigits,
        'showCentiseconds': _showCentiseconds,
        'themeOption': _themeOption.name,
        'pureBlackOled': _pureBlackOled,
      },
      'sessions': _sessions.map((s) => s.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _pureBlackOled && _isDarkMode
            ? Colors.black
            : _warmCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _pureBlackOled && _isDarkMode
              ? const BorderSide(color: _coralPink, width: 1)
              : BorderSide.none,
        ),
        title: Text(
          'Export Data',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _pureBlackOled && _isDarkMode ? _warmCream : _deepRed,
          ),
        ),
        content: Text(
          'Export ${ _sessions.length } sessions and settings. Choose your export target:',
          style: TextStyle(
            color: _pureBlackOled && _isDarkMode ? _warmCream : Colors.black87,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, color: _coralPink),
            label: const Text('Copy JSON', style: TextStyle(color: _coralPink)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data copied to clipboard!'),
                  backgroundColor: _deepRed,
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt_rounded, color: _warmCream),
            label: const Text(
              'Save File',
              style: TextStyle(color: _warmCream, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: _deepRed),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              try {
                final dir = Directory('/sdcard/Download');
                final targetDir = await dir.exists()
                    ? dir
                    : Directory.current;
                final file = File('${targetDir.path}/magn_backup.json');
                await file.writeAsString(jsonStr);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Backup saved: ${file.path}'),
                    backgroundColor: _deepRed,
                  ),
                );
              } catch (_) {
                Clipboard.setData(ClipboardData(text: jsonStr));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'File access restricted. Copied to clipboard instead.'),
                    backgroundColor: _coralPink,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _importData() {
    final textController = TextEditingController();
    final fileController =
        TextEditingController(text: '/sdcard/Download/magn_backup.json');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            backgroundColor: _pureBlackOled && _isDarkMode
                ? Colors.black
                : _warmCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: _pureBlackOled && _isDarkMode
                  ? const BorderSide(color: _coralPink, width: 1)
                  : BorderSide.none,
            ),
            title: Text(
              'Import Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _pureBlackOled && _isDarkMode ? _warmCream : _deepRed,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 260,
              child: Column(
                children: [
                  TabBar(
                    labelColor:
                        _pureBlackOled && _isDarkMode ? _coralPink : _deepRed,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: _coralPink,
                    tabs: const [
                      Tab(text: 'Paste JSON'),
                      Tab(text: 'From File'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        TextField(
                          controller: textController,
                          maxLines: 8,
                          style: TextStyle(
                            fontSize: 12,
                            color: _pureBlackOled && _isDarkMode
                                ? _warmCream
                                : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Paste raw JSON here...',
                            hintStyle: TextStyle(
                              color: _pureBlackOled && _isDarkMode
                                  ? Colors.grey
                                  : Colors.black45,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              controller: fileController,
                              style: TextStyle(
                                fontSize: 13,
                                color: _pureBlackOled && _isDarkMode
                                    ? _warmCream
                                    : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Backup File Path',
                                labelStyle: const TextStyle(color: _coralPink),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _deepRed),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  String rawJson = textController.text.trim();
                  if (rawJson.isEmpty) {
                    try {
                      final file = File(fileController.text.trim());
                      if (await file.exists()) {
                        rawJson = await file.readAsString();
                      }
                    } catch (_) {}
                  }

                  if (rawJson.isEmpty) {
                    return;
                  }

                  try {
                    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
                    final sessionList = decoded['sessions'] as List<dynamic>?;
                    if (sessionList != null) {
                      setState(() {
                        _sessions.clear();
                        for (final s in sessionList) {
                          _sessions.add(
                              SessionRecord.fromJson(s as Map<String, dynamic>));
                        }
                      });
                    }

                    final settings =
                        decoded['settings'] as Map<String, dynamic>?;
                    if (settings != null) {
                      setState(() {
                        if (settings['showDigits'] != null) {
                          _showDigits = settings['showDigits'] as bool;
                        }
                        if (settings['showCentiseconds'] != null) {
                          _showCentiseconds =
                              settings['showCentiseconds'] as bool;
                        }
                        if (settings['pureBlackOled'] != null) {
                          _pureBlackOled =
                              settings['pureBlackOled'] as bool;
                        }
                      });
                    }
                    await _saveData();
                    Navigator.pop(dialogCtx);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Imported ${_sessions.length} sessions successfully!'),
                        backgroundColor: _deepRed,
                      ),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Invalid JSON or unreadable backup file!'),
                        backgroundColor: _coralPink,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Import',
                  style:
                      TextStyle(color: _warmCream, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteAllData() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _pureBlackOled && _isDarkMode
            ? Colors.black
            : _warmCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _pureBlackOled && _isDarkMode
              ? const BorderSide(color: _coralPink, width: 1)
              : BorderSide.none,
        ),
        title: const Text(
          'Delete All Data?',
          style: TextStyle(fontWeight: FontWeight.bold, color: _deepRed),
        ),
        content: const Text(
          'This will permanently delete all session logs, flow analytics history, and reset your personalized ignition threshold.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _deepRed),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _sessions.clear();
                _currentSessionInterruptions = 0;
              });
              await _saveData();
              Navigator.pop(dialogCtx);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('All session data wiped & calibration reset.'),
                  backgroundColor: _deepRed,
                ),
              );
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: _warmCream, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isDarkMode {
    if (_themeOption == ThemeModeOption.dark) return true;
    if (_themeOption == ThemeModeOption.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  // --- Background Theming & Frosted Tiles ---

  List<Color> get _activeBackgroundColors {
    if (_pureBlackOled && _isDarkMode) {
      return [Colors.black, Colors.black, Colors.black];
    } else if (_isDarkMode) {
      return const [
        Color(0xFF1A0001),
        Color(0xFF4A0002),
        Color(0xFFAA0003),
      ];
    } else if (_themeOption == ThemeModeOption.light) {
      return const [
        Color(0xFFFFEDD5),
        Color(0xFFFF9E9E),
        Color(0xFFFF6B6B),
      ];
    }
    // Signature Brand Palette
    return const [_deepRed, _coralPink, _warmCream];
  }

  Widget _buildFrostedTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _warmCream.withValues(alpha: 0.32),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _warmCream.withValues(alpha: 0.28),
                _warmCream.withValues(alpha: 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFlowActive = currentFlowSeconds > 0;
    final isOled = _pureBlackOled && _isDarkMode;
    final textColor = isOled ? _warmCream : _warmCream;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Layer 1: Base Background (Pure Black or Animated Gradient with Glow Orbs)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: isOled
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _activeBackgroundColors,
                          stops: const [0.0, 0.55, 1.0],
                        ),
                  color: isOled ? Colors.black : null,
                ),
              ),
            ),

            if (!isOled) ...[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _driftController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        final t = _driftController.value * 2 * math.pi;

                        final x1 = (w * 0.35) + (math.sin(t) * 70) - 160;
                        final y1 = (h * 0.42) + (math.cos(t) * 90) - 160;

                        final x2 = (w * 0.65) +
                            (math.cos(t * 0.8 + 1.0) * 60) -
                            140;
                        final y2 = (h * 0.58) +
                            (math.sin(t * 0.8 + 1.0) * 80) -
                            140;

                        return Stack(
                          children: [
                            Positioned(
                              left: x1,
                              top: y1,
                              child: Container(
                                width: 320,
                                height: 320,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _warmCream.withValues(alpha: 0.35),
                                      _warmCream.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: x2,
                              top: y2,
                              child: Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _deepRed.withValues(alpha: 0.25),
                                      _deepRed.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Layer 2: Centered 6x7 Frosted Glass Mosaic Grid
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.35, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: GridView.count(
                          crossAxisCount: 6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          children:
                              List.generate(42, (_) => _buildFrostedTile()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Layer 3: Main Foreground UI & Centered Stage
            SafeArea(
              child: Stack(
                children: [
                  // Top Navigation Bar
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top-Left Mode Switcher Pill (ENDLESS vs POMODORO)
                          GestureDetector(
                            onTap: _isRunning ? null : _toggleMode,
                            behavior: HitTestBehavior.opaque,
                            child: Opacity(
                              opacity: _isRunning ? 0.5 : 1.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isOled
                                      ? Colors.black
                                      : _warmCream.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isOled
                                        ? _coralPink
                                        : _warmCream.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _mode == AppMode.endless
                                          ? Icons.all_inclusive_rounded
                                          : Icons.timelapse_rounded,
                                      size: 16,
                                      color: textColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _mode == AppMode.endless
                                          ? 'ENDLESS'
                                          : 'POMODORO',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Top-Right Side-by-Side Action Buttons: Analytics & Settings (8px gap)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 26,
                                color: textColor,
                                icon: const Icon(Icons.insights_rounded),
                                onPressed: _openAnalyticsDashboard,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                iconSize: 26,
                                color: textColor,
                                icon: const Icon(Icons.tune_rounded),
                                onPressed: _openSettingsScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Stage: Digits Display or Minimalist Breathing Flow Orb
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pomodoro Uppercase Phase Pill Label (16px above center)
                        if (_mode == AppMode.pomodoro) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isOled
                                  ? Colors.black
                                  : _warmCream.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isOled
                                    ? _coralPink
                                    : _warmCream.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _pomodoroPhaseLabel,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Main Stage: Breathing Flow Orb vs Digits
                        if (!_showDigits) ...[
                          _BreathingFlowOrb(
                            controller: _orbController,
                            isRunning: _isRunning,
                            isFlowActive: isFlowActive,
                            isOled: isOled,
                          ),
                        ] else ...[
                          if (_mode == AppMode.endless) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formatElapsedTime(_endlessElapsedMs ~/ 1000),
                                  style: TextStyle(
                                    fontSize: 76,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (_showCentiseconds)
                                  Text(
                                    '.${((_endlessElapsedMs % 1000) ~/ 10).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              _formatElapsedTime(_pomodoroRemainingSeconds),
                              style: TextStyle(
                                fontSize: 76,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // Pomodoro Cycle Indicator Dots (16px below center)
                        if (_mode == AppMode.pomodoro) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(4, (index) {
                              final isCompletedOrActive =
                                  index < _pomodoroCycle;
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompletedOrActive
                                      ? (isOled ? _coralPink : _warmCream)
                                      : (isOled
                                          ? _coralPink.withValues(alpha: 0.3)
                                          : _warmCream.withValues(alpha: 0.35)),
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Bottom Action Buttons (64px offset from bottom)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 64.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _toggleTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning
                                  ? (isOled ? Colors.black : _warmCream)
                                  : _deepRed,
                              foregroundColor: _isRunning
                                  ? (isOled ? _coralPink : _deepRed)
                                  : _warmCream,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 18,
                              ),
                              shape: StadiumBorder(
                                side: isOled
                                    ? const BorderSide(color: _coralPink, width: 1.5)
                                    : (_isRunning
                                        ? const BorderSide(
                                            color: _deepRed,
                                            width: 2,
                                          )
                                        : BorderSide.none),
                              ),
                            ),
                            child: Text(
                              _isRunning ? 'STOP' : 'START',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: _isRunning
                                    ? (isOled ? _coralPink : _deepRed)
                                    : _warmCream,
                              ),
                            ),
                          ),

                          // Skip Phase Text Button (Pomodoro mode only)
                          if (_mode == AppMode.pomodoro) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _skipPomodoroPhase,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    textColor.withValues(alpha: 0.85),
                              ),
                              child: const Text(
                                'Skip Phase',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist Breathing Flow Orb using 4-second sine-wave scale pulse (0.88 to 1.12).
class _BreathingFlowOrb extends StatelessWidget {
  final AnimationController controller;
  final bool isRunning;
  final bool isFlowActive;
  final bool isOled;

  const _BreathingFlowOrb({
    required this.controller,
    required this.isRunning,
    required this.isFlowActive,
    required this.isOled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 2 * math.pi;
        // 4-second sine-wave pulse scaling from 0.88 to 1.12
        final scale = 1.0 + 0.12 * math.sin(t);
        final glowAlpha = (0.25 + 0.15 * math.sin(t)).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer soft concentric ring
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isOled ? _coralPink : _warmCream).withValues(
                        alpha: isFlowActive ? 0.45 : 0.20,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),

                // Middle concentric glow ring
                Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isFlowActive ? _deepRed : _coralPink).withValues(
                          alpha: glowAlpha * (isFlowActive ? 0.4 : 0.2),
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Core Breathing Sphere
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isOled
                          ? [
                              isFlowActive ? _deepRed : _coralPink,
                              Colors.black,
                            ]
                          : [
                              isFlowActive
                                  ? _deepRed
                                  : _warmCream.withValues(alpha: 0.9),
                              isFlowActive
                                  ? _coralPink
                                  : _coralPink.withValues(alpha: 0.45),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isFlowActive ? _coralPink : _warmCream)
                            .withValues(alpha: isOled ? 0.2 : 0.35),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isFlowActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _deepRed.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _warmCream.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'IN FLOW',
                              style: TextStyle(
                                color: _warmCream,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          )
                        : (isRunning
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _warmCream,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rich Analytics & History Dashboard with Bento Summary, Animated 7-Day Chart,
/// Focus Consistency Trend curve, and dismissible Session History.
class _AnalyticsDashboardSheet extends StatefulWidget {
  final List<SessionRecord> sessions;
  final int ignitionThreshold;
  final int accuracyPercent;
  final bool isPureBlack;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatTimestamp;
  final ValueChanged<int> onDeleteSession;

  const _AnalyticsDashboardSheet({
    required this.sessions,
    required this.ignitionThreshold,
    required this.accuracyPercent,
    required this.isPureBlack,
    required this.formatDuration,
    required this.formatTimestamp,
    required this.onDeleteSession,
  });

  @override
  State<_AnalyticsDashboardSheet> createState() =>
      _AnalyticsDashboardSheetState();
}

class _AnalyticsDashboardSheetState extends State<_AnalyticsDashboardSheet> {
  String _formatMinutesSeconds(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatHoursMinutes(int totalSec) {
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final totalWarmUp =
        widget.sessions.fold<int>(0, (prev, s) => prev + s.warmUpSeconds);
    final totalFlow =
        widget.sessions.fold<int>(0, (prev, s) => prev + s.flowSeconds);
    final totalTracked = totalWarmUp + totalFlow;
    final efficiency = totalTracked > 0
        ? ((totalFlow / totalTracked) * 100).round()
        : 0;

    final primaryText = widget.isPureBlack ? _warmCream : _deepRed;
    final cardBg = widget.isPureBlack
        ? Colors.black
        : _deepRed.withValues(alpha: 0.08);
    final cardBorder = widget.isPureBlack
        ? Border.all(color: _coralPink, width: 1)
        : null;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: primaryText.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flow Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _coralPink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Calibration: ${widget.accuracyPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _coralPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Dashboard Contents
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  // 1. Top Summary Row of 3 Bento Cards
                  Row(
                    children: [
                      // Personal Ignition Time Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: cardBorder,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatMinutesSeconds(widget.ignitionThreshold),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Personal Ignition',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryText.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Total Flow Time Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: cardBorder,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatHoursMinutes(totalFlow),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Flow Time',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryText.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Flow Efficiency % Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: cardBorder,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$efficiency%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Flow Ratio',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryText.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Animated 7-Day Focus & Flow Stacked Bar Chart
                  Text(
                    '7-Day Focus & Flow Cadence',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: cardBorder,
                    ),
                    child: _SevenDayStackedBarChart(
                      sessions: widget.sessions,
                      isPureBlack: widget.isPureBlack,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Focus Consistency Trend Curve
                  Text(
                    'Focus Consistency Trend',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: cardBorder,
                    ),
                    child: CustomPaint(
                      painter: _ConsistencyTrendPainter(
                        sessions: widget.sessions,
                        isPureBlack: widget.isPureBlack,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Session History Log Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session History (${widget.sessions.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      Text(
                        'Swipe to delete',
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryText.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Scrollable Session List with Dismissible Support
                  if (widget.sessions.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          'No sessions recorded yet',
                          style: TextStyle(fontSize: 14, color: _coralPink),
                        ),
                      ),
                    ),
                  ] else ...[
                    ...List.generate(widget.sessions.length, (idx) {
                      final reversedIndex =
                          widget.sessions.length - 1 - idx;
                      final session = widget.sessions[reversedIndex];
                      final flowMin = (session.flowSeconds / 60).round();

                      return Dismissible(
                        key: Key(
                            'session_${session.timestamp.millisecondsSinceEpoch}_$reversedIndex'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          widget.onDeleteSession(reversedIndex);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: cardBorder,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _deepRed.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        session.mode == AppMode.endless
                                            ? 'ENDLESS'
                                            : 'POMO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: primaryText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      widget.formatDuration(
                                          session.durationInSeconds),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _coralPink.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Flow: ${flowMin}m',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _coralPink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  widget.formatTimestamp(session.timestamp),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _coralPink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated 7-Day Focus & Flow Stacked Bar Chart built with TweenAnimationBuilder.
class _SevenDayStackedBarChart extends StatelessWidget {
  final List<SessionRecord> sessions;
  final bool isPureBlack;

  const _SevenDayStackedBarChart({
    required this.sessions,
    required this.isPureBlack,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayTotals = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      int warmUp = 0;
      int flow = 0;

      for (final s in sessions) {
        if (s.timestamp.year == date.year &&
            s.timestamp.month == date.month &&
            s.timestamp.day == date.day) {
          warmUp += s.warmUpSeconds;
          flow += s.flowSeconds;
        }
      }
      return {
        'label': _weekdayLabel(date.weekday),
        'warmUpMin': (warmUp / 60.0),
        'flowMin': (flow / 60.0),
        'totalMin': ((warmUp + flow) / 60.0),
      };
    });

    final maxTotal = dayTotals.fold<double>(
      30.0,
      (prev, d) => (d['totalMin']! as double) > prev
          ? (d['totalMin']! as double)
          : prev,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final day = dayTotals[i];
                final warmUp = day['warmUpMin']! as double;
                final flow = day['flowMin']! as double;
                final total = day['totalMin']! as double;

                final warmUpHeight = (warmUp / maxTotal) * 110.0 * anim;
                final flowHeight = (flow / maxTotal) * 110.0 * anim;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total > 0 ? '${total.round()}m' : '',
                      style: TextStyle(
                        fontSize: 9,
                        color: isPureBlack ? _coralPink : _deepRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 110,
                        alignment: Alignment.bottomCenter,
                        color: isPureBlack
                            ? Colors.grey.shade900
                            : _warmCream.withValues(alpha: 0.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 28,
                              height: flowHeight,
                              color: _deepRed,
                            ),
                            Container(
                              width: 28,
                              height: warmUpHeight,
                              color: _coralPink,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day['label']! as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isPureBlack ? _warmCream : _deepRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendCircle(_coralPink, 'Warm-Up', isPureBlack),
                const SizedBox(width: 16),
                _buildLegendCircle(_deepRed, 'Flow State', isPureBlack),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendCircle(Color color, String label, bool isPureBlack) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isPureBlack ? _warmCream : _deepRed,
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

/// CustomPainter rendering smooth focus consistency trend curve.
class _ConsistencyTrendPainter extends CustomPainter {
  final List<SessionRecord> sessions;
  final bool isPureBlack;

  _ConsistencyTrendPainter({
    required this.sessions,
    required this.isPureBlack,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final recent = sessions.length > 7
        ? sessions.sublist(sessions.length - 7)
        : sessions;

    final linePaint = Paint()
      ..color = _coralPink
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = isPureBlack ? _warmCream : _deepRed
      ..style = PaintingStyle.fill;

    if (recent.isEmpty) {
      final placeholderPaint = Paint()
        ..color = _coralPink.withValues(alpha: 0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5),
        placeholderPaint,
      );
      return;
    }

    final points = <Offset>[];
    final stepX = size.width / (recent.length > 1 ? (recent.length - 1) : 1);

    for (int i = 0; i < recent.length; i++) {
      final s = recent[i];
      final total = s.warmUpSeconds + s.flowSeconds;
      final ratio = total > 0 ? (s.flowSeconds / total).clamp(0.0, 1.0) : 0.0;
      final y = size.height - (ratio * (size.height - 20) + 10);
      final x = recent.length > 1 ? i * stepX : size.width * 0.5;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _coralPink.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConsistencyTrendPainter oldDelegate) {
    return oldDelegate.sessions != sessions ||
        oldDelegate.isPureBlack != isPureBlack;
  }
}

/// Settings Screen / Sheet containing Behavior, Appearance (OLED Pure Black),
/// and Data Management (Export/Import/Delete).
class _SettingsSheet extends StatelessWidget {
  final bool showDigits;
  final bool showCentiseconds;
  final ThemeModeOption themeOption;
  final bool pureBlackOled;
  final bool isPureBlack;
  final ValueChanged<bool> onShowDigitsChanged;
  final ValueChanged<bool> onShowCentisecondsChanged;
  final ValueChanged<ThemeModeOption> onThemeChanged;
  final ValueChanged<bool> onPureBlackChanged;
  final VoidCallback onExportData;
  final VoidCallback onImportData;
  final VoidCallback onDeleteAllData;

  const _SettingsSheet({
    required this.showDigits,
    required this.showCentiseconds,
    required this.themeOption,
    required this.pureBlackOled,
    required this.isPureBlack,
    required this.onShowDigitsChanged,
    required this.onShowCentisecondsChanged,
    required this.onThemeChanged,
    required this.onPureBlackChanged,
    required this.onExportData,
    required this.onImportData,
    required this.onDeleteAllData,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = isPureBlack ? _warmCream : _deepRed;
    final cardBg =
        isPureBlack ? Colors.black : _deepRed.withValues(alpha: 0.08);
    final cardBorder =
        isPureBlack ? Border.all(color: _coralPink, width: 1) : null;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: primaryText.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  // --- 1. Behavior Section ---
                  _buildSectionHeader('Behavior', primaryText),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: cardBorder,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeThumbColor: _deepRed,
                          title: Text(
                            'Show Timer Digits',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            'Display clock numbers instead of the Breathing Flow Orb',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          value: showDigits,
                          onChanged: onShowDigitsChanged,
                        ),
                        Divider(
                          height: 1,
                          color: primaryText.withValues(alpha: 0.1),
                        ),
                        SwitchListTile(
                          activeThumbColor: _deepRed,
                          title: Text(
                            'Show Centiseconds (.00)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            'Display millisecond precision in Endless Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          value: showCentiseconds,
                          onChanged: onShowCentisecondsChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 2. Appearance Section ---
                  _buildSectionHeader('Appearance', primaryText),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: cardBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildThemePill(
                              label: 'System',
                              isSelected: themeOption == ThemeModeOption.system,
                              onTap: () =>
                                  onThemeChanged(ThemeModeOption.system),
                              isPureBlack: isPureBlack,
                            ),
                            const SizedBox(width: 8),
                            _buildThemePill(
                              label: 'Light',
                              isSelected: themeOption == ThemeModeOption.light,
                              onTap: () =>
                                  onThemeChanged(ThemeModeOption.light),
                              isPureBlack: isPureBlack,
                            ),
                            const SizedBox(width: 8),
                            _buildThemePill(
                              label: 'Dark',
                              isSelected: themeOption == ThemeModeOption.dark,
                              onTap: () =>
                                  onThemeChanged(ThemeModeOption.dark),
                              isPureBlack: isPureBlack,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          color: primaryText.withValues(alpha: 0.1),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: _coralPink,
                          title: Text(
                            'Pure Black OLED Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            'True #000000 background with crisp Coral borders',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          value: pureBlackOled,
                          onChanged: onPureBlackChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 3. Data Management Section ---
                  _buildSectionHeader('Data Management', primaryText),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: cardBorder,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.upload_file_rounded,
                            color: _coralPink,
                          ),
                          title: Text(
                            'Export Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            'Copy formatted JSON or save backup file',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          onTap: onExportData,
                        ),
                        Divider(
                          height: 1,
                          color: primaryText.withValues(alpha: 0.1),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.download_rounded,
                            color: _coralPink,
                          ),
                          title: Text(
                            'Import Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            'Paste JSON or load backup from file',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          onTap: onImportData,
                        ),
                        Divider(
                          height: 1,
                          color: primaryText.withValues(alpha: 0.1),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete All Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          subtitle: Text(
                            'Wipe all sessions and reset flow calibration',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.7),
                            ),
                          ),
                          onTap: onDeleteAllData,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: textColor.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildThemePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isPureBlack,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _deepRed : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? _deepRed
                  : (isPureBlack ? _coralPink : _coralPink.withValues(alpha: 0.4)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? _warmCream : (isPureBlack ? _warmCream : _deepRed),
            ),
          ),
        ),
      ),
    );
  }
}
