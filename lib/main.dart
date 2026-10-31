import 'dart:async';
import 'dart:ui' show FragmentProgram;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const StopwatchApp());
}

/// A minimal single-file stopwatch application featuring a procedural GLSL frosted glass shader.
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

/// Model representing a completed stopwatch session.
class SessionRecord {
  final int durationInSeconds;
  final DateTime timestamp;

  const SessionRecord({
    required this.durationInSeconds,
    required this.timestamp,
  });
}

/// The primary Stopwatch Screen with procedural GLSL frosted tiles background.
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with SingleTickerProviderStateMixin {
  // Exact hex colors specified in requirements
  static const Color _deepRed = Color(0xFFAA0003);
  static const Color _coralPink = Color(0xFFFF6B6B);
  static const Color _warmCream = Color(0xFFFFEDD5);

  late final AnimationController _animationController;
  FragmentProgram? _fragmentProgram;

  int _elapsedSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  final List<SessionRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
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
      // Graceful fallback for environments or headless unit tests
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (_elapsedSeconds >= 1) {
      _sessions.add(
        SessionRecord(
          durationInSeconds: _elapsedSeconds,
          timestamp: DateTime.now(),
        ),
      );
    }
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

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

  void _openHistoryBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _deepRed,
                      ),
                    ),
                  ),
                ),
                if (_sessions.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No sessions recorded',
                        style: TextStyle(
                          fontSize: 16,
                          color: _coralPink,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _sessions.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: _coralPink,
                        height: 1,
                        thickness: 0.5,
                      ),
                      itemBuilder: (context, index) {
                        final session = _sessions[_sessions.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(session.durationInSeconds),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _deepRed,
                                ),
                              ),
                              Text(
                                _formatTimestamp(session.timestamp),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _coralPink,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Full-screen CustomPaint rendering the GLSL Frosted Tiles Shader
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
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        iconSize: 28,
                        color: _warmCream,
                        icon: const Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: _warmCream,
                        ),
                        onPressed: _openHistoryBottomSheet,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      _formatElapsedTime(_elapsedSeconds),
                      style: const TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w700,
                        color: _warmCream,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 64.0),
                      child: ElevatedButton(
                        onPressed: _toggleTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? _warmCream : _deepRed,
                          foregroundColor: _isRunning ? _deepRed : _warmCream,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 18,
                          ),
                          shape: StadiumBorder(
                            side: _isRunning
                                ? const BorderSide(color: _deepRed, width: 2)
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

/// CustomPainter that renders the procedural frosted tiles shader or fallback gradient.
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
            Color(0xFFAA0003),
            Color(0xFFFF6B6B),
            Color(0xFFFFEDD5),
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
