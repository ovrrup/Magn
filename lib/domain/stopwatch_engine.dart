import 'dart:async';
import '../data/models/lap_model.dart';

/// Pure domain stopwatch engine utilizing monotonic high-resolution system clock.
class StopwatchEngine {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  final List<LapModel> _laps = [];
  int _lastLapTotalMs = 0;

  void Function(int elapsedMs)? onTick;

  bool get isRunning => _stopwatch.isRunning;
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  int get elapsedSeconds => _stopwatch.elapsedMilliseconds ~/ 1000;
  List<LapModel> get laps => List.unmodifiable(_laps);

  void start({Duration tickInterval = const Duration(milliseconds: 33)}) {
    if (_stopwatch.isRunning) return;
    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) {
      onTick?.call(_stopwatch.elapsedMilliseconds);
    });
  }

  void stop() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    onTick?.call(_stopwatch.elapsedMilliseconds);
  }

  void reset() {
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;
    _laps.clear();
    _lastLapTotalMs = 0;
    onTick?.call(0);
  }

  LapModel? recordLap() {
    if (!_stopwatch.isRunning) return null;

    final currentTotalMs = _stopwatch.elapsedMilliseconds;
    final splitTimeMs = currentTotalMs - _lastLapTotalMs;
    _lastLapTotalMs = currentTotalMs;

    final lap = LapModel(
      lapNumber: _laps.length + 1,
      splitTimeMs: splitTimeMs,
      totalTimeMs: currentTotalMs,
    );

    _laps.add(lap);
    return lap;
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }
}
