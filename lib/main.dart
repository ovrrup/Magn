import 'dart:async';
import 'dart:ui' show FontFeature, FragmentProgram;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const StopwatchApp());
}

// Exact brand chromatics
const Color _deepRed = Color(0xFFAA0003);
const Color _coralPink = Color(0xFFFF6B6B);
const Color _warmCream = Color(0xFFFFEDD5);

/// Active timing mode of the application.
enum AppMode { endless, pomodoro }

/// Active phase within Pomodoro cycle.
enum PomodoroPhase { focus, shortBreak, longBreak }

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
}

/// Root widget of the Magn stopwatch application.
class StopwatchApp extends StatelessWidget {
  const StopwatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StopwatchScreen(),
    );
  }
}

/// The primary Stopwatch Screen with Shader, Mode Switcher, and Flow Engine.
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Background Fragment Shader
  late final AnimationController _animationController;
  FragmentProgram? _fragmentProgram;

  // Mode and State
  AppMode _mode = AppMode.endless;
  bool _isRunning = false;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  final List<SessionRecord> _sessions = [];

  // Endless Mode State
  int _endlessElapsedMs = 0;

  // Pomodoro State Machine (25m Focus, 5m Short Break x 4, 15m Long Break)
  static const int _focusDurationSec = 25 * 60; // 1500s
  static const int _shortBreakDurationSec = 5 * 60; // 300s
  static const int _longBreakDurationSec = 15 * 60; // 900s

  int _pomodoroCycle = 1; // 1 to 4
  PomodoroPhase _pomodoroPhase = PomodoroPhase.focus;
  int _pomodoroRemainingSeconds = _focusDurationSec;

  // Flow State & Interruption Tracking
  int _currentSessionInterruptions = 0;
  DateTime? _lastBreakEndedAt;
  bool _breakChainActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await FragmentProgram.fromAsset('shaders/frosted_tiles.frag');
      if (mounted) {
        setState(() {
          _fragmentProgram = program;
        });
      }
    } catch (_) {
      // Graceful fallback for headless tests or environments
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
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

  // --- Dynamic Ignition Threshold & Flow Calculations ---

  /// Computes the user's dynamic Ignition Threshold in seconds.
  /// 35% of median duration of focus sessions over 5 minutes (default 720s if < 3 sessions,
  /// clamped between 480s and 1320s, plus 180s penalty per background interruption).
  /// If Pomodoro Break-Chain Carryover applies, drops to 120s base.
  int get dynamicIgnitionThreshold {
    final focusSessions = _sessions
        .where((s) => s.durationInSeconds >= 300)
        .map((s) => s.durationInSeconds)
        .toList();

    double baseThreshold;
    if (focusSessions.length < 3) {
      baseThreshold = 720.0;
    } else {
      focusSessions.sort();
      final count = focusSessions.length;
      double median;
      if (count % 2 == 1) {
        median = focusSessions[count ~/ 2].toDouble();
      } else {
        median =
            (focusSessions[(count ~/ 2) - 1] + focusSessions[count ~/ 2]) / 2.0;
      }
      baseThreshold = (median * 0.35).clamp(480.0, 1320.0);
    }

    // Break-Chain Carryover for Pomodoro Focus
    if (_mode == AppMode.pomodoro &&
        _pomodoroPhase == PomodoroPhase.focus &&
        _breakChainActive) {
      baseThreshold = 120.0;
    }

    return baseThreshold.round() + (_currentSessionInterruptions * 180);
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
    final threshold = dynamicIgnitionThreshold;
    if (_mode == AppMode.pomodoro && _pomodoroPhase != PomodoroPhase.focus) {
      return 0;
    }
    return elapsed < threshold ? elapsed : threshold;
  }

  int get currentFlowSeconds {
    final elapsed = currentElapsedSeconds;
    final threshold = dynamicIgnitionThreshold;
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
      // Pomodoro Mode
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
      }
      setState(() {
        _isRunning = false;
        _endlessElapsedMs = 0;
        _currentSessionInterruptions = 0;
      });
    } else {
      // Pomodoro Mode Stop
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
      // Completed full focus phase
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

      // Transition to break
      if (_pomodoroCycle < 4) {
        _pomodoroPhase = PomodoroPhase.shortBreak;
        _pomodoroRemainingSeconds = _shortBreakDurationSec;
      } else {
        _pomodoroPhase = PomodoroPhase.longBreak;
        _pomodoroRemainingSeconds = _longBreakDurationSec;
      }
    } else {
      // Completed break
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

  // --- Modal Bottom Sheet (Flow Analytics & Session Log) ---

  void _openHistoryBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _warmCream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return _AnalyticsBottomSheet(
          sessions: _sessions,
          dynamicIgnitionThreshold: dynamicIgnitionThreshold,
          formatDuration: _formatDuration,
          formatTimestamp: _formatTimestamp,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFlowActive = currentFlowSeconds > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Background Procedural GLSL Shader
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: FrostedTilesPainter(
                      program: _fragmentProgram,
                      time: _animationController.value * 20.0,
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  // Top Navigation Row: Mode Switcher Pill on left, History Icon on right
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
                          // Translucent Stadium Mode Switcher Pill
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
                                  color: _warmCream.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _warmCream.withValues(alpha: 0.35),
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
                                      color: _warmCream,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _mode == AppMode.endless
                                          ? 'ENDLESS'
                                          : 'POMODORO',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: _warmCream,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Top-right History Icon Button
                          IconButton(
                            iconSize: 28,
                            color: _warmCream,
                            icon: const Icon(
                              Icons.history_rounded,
                              size: 28,
                              color: _warmCream,
                            ),
                            onPressed: _openHistoryBottomSheet,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Timer & Status Indicators
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "IN FLOW" Pill Badge
                        if (isFlowActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _deepRed.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _warmCream.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: _warmCream,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'IN FLOW',
                                  style: TextStyle(
                                    color: _warmCream,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Pomodoro Uppercase Phase Pill Label (16px above timer)
                        if (_mode == AppMode.pomodoro) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _warmCream.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _warmCream.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _pomodoroPhaseLabel,
                              style: const TextStyle(
                                color: _warmCream,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Main Digits & Centiseconds
                        if (_mode == AppMode.endless) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formatElapsedTime(_endlessElapsedMs ~/ 1000),
                                style: const TextStyle(
                                  fontSize: 76,
                                  fontWeight: FontWeight.w700,
                                  color: _warmCream,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                '.${((_endlessElapsedMs % 1000) ~/ 10).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: _warmCream,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            _formatElapsedTime(_pomodoroRemainingSeconds),
                            style: const TextStyle(
                              fontSize: 76,
                              fontWeight: FontWeight.w700,
                              color: _warmCream,
                              fontFeatures: [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],

                        // Pomodoro Cycle Indicator Dots (16px below timer)
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
                                      ? _warmCream
                                      : _warmCream.withValues(alpha: 0.35),
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
                              backgroundColor:
                                  _isRunning ? _warmCream : _deepRed,
                              foregroundColor:
                                  _isRunning ? _deepRed : _warmCream,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 18,
                              ),
                              shape: StadiumBorder(
                                side: _isRunning
                                    ? const BorderSide(
                                        color: _deepRed,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: Text(
                              _isRunning ? 'STOP' : 'START',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: _isRunning ? _deepRed : _warmCream,
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
                                    _warmCream.withValues(alpha: 0.85),
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

/// Upgraded Modal Bottom Sheet with Top Segmented Toggle (Flow Analytics & Session Log).
class _AnalyticsBottomSheet extends StatefulWidget {
  final List<SessionRecord> sessions;
  final int dynamicIgnitionThreshold;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatTimestamp;

  const _AnalyticsBottomSheet({
    required this.sessions,
    required this.dynamicIgnitionThreshold,
    required this.formatDuration,
    required this.formatTimestamp,
  });

  @override
  State<_AnalyticsBottomSheet> createState() => _AnalyticsBottomSheetState();
}

class _AnalyticsBottomSheetState extends State<_AnalyticsBottomSheet> {
  int _selectedTab = 0; // 0: Flow Analytics, 1: Session Log

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

    // Average Ignition Time
    final flowSessions =
        widget.sessions.where((s) => s.flowSeconds > 0).toList();
    final avgIgnitionSec = flowSessions.isNotEmpty
        ? (flowSessions.fold<int>(0, (prev, s) => prev + s.warmUpSeconds) /
                flowSessions.length)
            .round()
        : widget.dynamicIgnitionThreshold;

    // Total Flow Time Today
    final now = DateTime.now();
    final todayFlowSec = widget.sessions
        .where((s) =>
            s.timestamp.year == now.year &&
            s.timestamp.month == now.month &&
            s.timestamp.day == now.day)
        .fold<int>(0, (prev, s) => prev + s.flowSeconds);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _deepRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Top Segmented Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _deepRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? _deepRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Flow Analytics',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 0
                                  ? _warmCream
                                  : _deepRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? _deepRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Session Log',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 1
                                  ? _warmCream
                                  : _deepRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Segmented View Contents
            Expanded(
              child: _selectedTab == 0
                  ? _buildFlowAnalytics(
                      avgIgnitionSec: avgIgnitionSec,
                      todayFlowSec: todayFlowSec,
                      totalWarmUp: totalWarmUp,
                      totalFlow: totalFlow,
                      efficiency: efficiency,
                    )
                  : _buildSessionLog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowAnalytics({
    required int avgIgnitionSec,
    required int todayFlowSec,
    required int totalWarmUp,
    required int totalFlow,
    required int efficiency,
  }) {
    final warmUpWeight = totalWarmUp > 0 ? totalWarmUp : (totalFlow == 0 ? 1 : 0);
    final flowWeight = totalFlow > 0 ? totalFlow : (totalWarmUp == 0 ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two side-by-side rounded Bento cards
          Row(
            children: [
              // Average Ignition Time Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _deepRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMinutesSeconds(avgIgnitionSec),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _deepRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time to reach flow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _deepRed.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Total Flow Time Today Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _deepRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatHoursMinutes(todayFlowSec),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _deepRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deep state duration',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _deepRed.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Horizontal Stacked Progress Bar (Height 14px, Radius 7px)
          const Text(
            'Warm-Up vs Flow Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _deepRed,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: warmUpWeight,
                    child: Container(color: _coralPink),
                  ),
                  Expanded(
                    flex: flowWeight,
                    child: Container(color: _deepRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Flow Efficiency Percentage Label
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _coralPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Warm-Up',
                    style: TextStyle(
                      fontSize: 12,
                      color: _deepRed.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _deepRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Flow State',
                    style: TextStyle(
                      fontSize: 12,
                      color: _deepRed.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Text(
                'Flow Efficiency: $efficiency%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _deepRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSessionLog() {
    if (widget.sessions.isEmpty) {
      return const Center(
        child: Text(
          'No sessions recorded',
          style: TextStyle(
            fontSize: 16,
            color: _coralPink,
          ),
        ),
      );
    }

    final reversedSessions = widget.sessions.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: reversedSessions.length,
      separatorBuilder: (_, __) => const Divider(
        color: _coralPink,
        height: 1,
        thickness: 0.5,
      ),
      itemBuilder: (context, index) {
        final session = reversedSessions[index];
        final flowMinutes = (session.flowSeconds / 60).round();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Mode Tag Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _deepRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      session.mode == AppMode.endless ? 'ENDLESS' : 'POMO',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _deepRed,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Total Duration
                  Text(
                    widget.formatDuration(session.durationInSeconds),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _deepRed,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Flow Duration Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _coralPink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Flow: ${flowMinutes}m',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _coralPink,
                      ),
                    ),
                  ),
                ],
              ),

              // HH:mm Timestamp
              Text(
                widget.formatTimestamp(session.timestamp),
                style: const TextStyle(
                  fontSize: 14,
                  color: _coralPink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// CustomPainter rendering the procedural frosted tiles shader or fallback gradient.
class FrostedTilesPainter extends CustomPainter {
  final FragmentProgram? program;
  final double time;

  FrostedTilesPainter({
    required this.program,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (program != null) {
      final shader = program!.fragmentShader();
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, time);

      final paint = Paint()..shader = shader;
      canvas.drawRect(Offset.zero & size, paint);
    } else {
      // Fallback base gradient matching exact app palette
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _deepRed,
            _coralPink,
            _warmCream,
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FrostedTilesPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.program != program;
  }
}
