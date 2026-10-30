import 'package:flutter/foundation.dart';
import '../../core/utils/haptics_util.dart';
import '../../data/models/lap_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/stopwatch_engine.dart';

/// ViewModel / Controller orchestrating stopwatch state, session persistence, and tactile feedback.
class StopwatchController extends ChangeNotifier {
  final StopwatchEngine _engine;
  final SessionRepository _repository;

  bool _showMilliseconds = false;
  List<SessionModel> _sessions = [];
  bool _isLoadingHistory = false;

  StopwatchController({
    StopwatchEngine? engine,
    SessionRepository? repository,
  })  : _engine = engine ?? StopwatchEngine(),
        _repository = repository ?? LocalSessionRepository() {
    _engine.onTick = (_) => notifyListeners();
    loadSessions();
  }

  bool get isRunning => _engine.isRunning;
  int get elapsedMilliseconds => _engine.elapsedMilliseconds;
  int get elapsedSeconds => _engine.elapsedSeconds;
  List<LapModel> get laps => _engine.laps;
  List<SessionModel> get sessions => List.unmodifiable(_sessions);
  bool get showMilliseconds => _showMilliseconds;
  bool get isLoadingHistory => _isLoadingHistory;

  LapModel? get fastestLap {
    if (laps.length < 2) return null;
    LapModel fastest = laps.first;
    for (final lap in laps) {
      if (lap.splitTimeMs < fastest.splitTimeMs) {
        fastest = lap;
      }
    }
    return fastest;
  }

  LapModel? get slowestLap {
    if (laps.length < 2) return null;
    LapModel slowest = laps.first;
    for (final lap in laps) {
      if (lap.splitTimeMs > slowest.splitTimeMs) {
        slowest = lap;
      }
    }
    return slowest;
  }

  void toggleMilliseconds() {
    _showMilliseconds = !_showMilliseconds;
    HapticsUtil.selectionClick();
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _isLoadingHistory = true;
    notifyListeners();
    _sessions = await _repository.getSessions();
    _isLoadingHistory = false;
    notifyListeners();
  }

  void start() {
    HapticsUtil.mediumImpact();
    _engine.reset();
    _engine.start();
    notifyListeners();
  }

  Future<void> stop() async {
    HapticsUtil.heavyImpact();
    final totalSec = _engine.elapsedSeconds;
    final totalMs = _engine.elapsedMilliseconds;
    final recordedLaps = List<LapModel>.from(_engine.laps);

    _engine.stop();

    if (totalSec >= 1) {
      final session = SessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        durationInSeconds: totalSec,
        durationInMilliseconds: totalMs,
        timestamp: DateTime.now(),
        laps: recordedLaps,
      );
      await _repository.saveSession(session);
      await loadSessions();
    }

    _engine.reset();
    notifyListeners();
  }

  void toggle() {
    if (isRunning) {
      stop();
    } else {
      start();
    }
  }

  void recordLap() {
    if (!isRunning) return;
    HapticsUtil.lightImpact();
    _engine.recordLap();
    notifyListeners();
  }

  void reset() {
    HapticsUtil.lightImpact();
    _engine.reset();
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    HapticsUtil.selectionClick();
    await _repository.deleteSession(id);
    await loadSessions();
  }

  Future<void> clearAllHistory() async {
    HapticsUtil.heavyImpact();
    await _repository.clearAll();
    await loadSessions();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
