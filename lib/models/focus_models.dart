import '../theme/instrument_theme.dart';

/// Operating modes for the precision timer.
enum AppMode {
  endless,
  cycle,
}

/// Phases within a structured Cycle (Pomodoro-style interval).
enum CyclePhase {
  focus,
  shortBreak,
  longBreak,
}

/// Real-time physiological cognitive state.
enum FocusState {
  idle,
  warmUp,
  flowState,
}

/// Zero-guilt task triage classification buckets.
enum TaskBucket {
  today,
  deferred,
  marks,
}

/// Discrete levels for the Stepped Cognitive Depth Timeline Chart (Hypnogram-style).
enum CognitiveDepthLevel {
  idle,
  warmUp,
  focused,
  deepFlow,
}

/// A triage task item tracked by the instrument.
class FocusTask {
  final String id;
  final String title;
  final TaskBucket bucket;
  final bool isCompleted;
  final int accumulatedFlowSeconds;
  final DateTime createdAt;
  final DateTime? completedAt;

  const FocusTask({
    required this.id,
    required this.title,
    required this.bucket,
    this.isCompleted = false,
    this.accumulatedFlowSeconds = 0,
    required this.createdAt,
    this.completedAt,
  });

  FocusTask copyWith({
    String? id,
    String? title,
    TaskBucket? bucket,
    bool? isCompleted,
    int? accumulatedFlowSeconds,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return FocusTask(
      id: id ?? this.id,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      isCompleted: isCompleted ?? this.isCompleted,
      accumulatedFlowSeconds:
          accumulatedFlowSeconds ?? this.accumulatedFlowSeconds,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'bucket': bucket.name,
        'isCompleted': isCompleted,
        'accumulatedFlowSeconds': accumulatedFlowSeconds,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory FocusTask.fromJson(Map<String, dynamic> json) {
    return FocusTask(
      id: json['id'] as String,
      title: json['title'] as String,
      bucket: TaskBucket.values.firstWhere(
        (b) => b.name == json['bucket'],
        orElse: () => TaskBucket.today,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      accumulatedFlowSeconds: json['accumulatedFlowSeconds'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

/// An archival record of a completed focus or break session.
class FocusSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int totalDurationSeconds;
  final int flowDurationSeconds;
  final AppMode mode;
  final int markCount;
  final String? linkedTaskId;
  final String? linkedTaskTitle;

  const FocusSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalDurationSeconds,
    required this.flowDurationSeconds,
    required this.mode,
    this.markCount = 0,
    this.linkedTaskId,
    this.linkedTaskTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalDurationSeconds': totalDurationSeconds,
        'flowDurationSeconds': flowDurationSeconds,
        'mode': mode.name,
        'markCount': markCount,
        'linkedTaskId': linkedTaskId,
        'linkedTaskTitle': linkedTaskTitle,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      totalDurationSeconds: json['totalDurationSeconds'] as int,
      flowDurationSeconds: json['flowDurationSeconds'] as int,
      mode: AppMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => AppMode.endless,
      ),
      markCount: json['markCount'] as int? ?? 0,
      linkedTaskId: json['linkedTaskId'] as String?,
      linkedTaskTitle: json['linkedTaskTitle'] as String?,
    );
  }
}

/// An impulse distraction logged during a live session via '+ MARK'.
class DistractionMark {
  final String id;
  final DateTime timestamp;
  final String note;
  final int sessionElapsedSeconds;

  const DistractionMark({
    required this.id,
    required this.timestamp,
    required this.note,
    required this.sessionElapsedSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'sessionElapsedSeconds': sessionElapsedSeconds,
      };

  factory DistractionMark.fromJson(Map<String, dynamic> json) {
    return DistractionMark(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String? ?? '',
      sessionElapsedSeconds: json['sessionElapsedSeconds'] as int? ?? 0,
    );
  }
}

/// User configurable settings and mechanical display parameters.
class FocusSettings {
  final bool showDigits;
  final bool showCentiseconds;
  final int ignitionThresholdMinutes;
  final int cycleFocusMinutes;
  final int cycleShortBreakMinutes;
  final int cycleLongBreakMinutes;
  final int cycleTargetLoops;
  final InstrumentThemeMode themeMode;

  const FocusSettings({
    this.showDigits = false,
    this.showCentiseconds = false,
    this.ignitionThresholdMinutes = 10,
    this.cycleFocusMinutes = 25,
    this.cycleShortBreakMinutes = 5,
    this.cycleLongBreakMinutes = 15,
    this.cycleTargetLoops = 4,
    this.themeMode = InstrumentThemeMode.stoneLight,
  });

  FocusSettings copyWith({
    bool? showDigits,
    bool? showCentiseconds,
    int? ignitionThresholdMinutes,
    int? cycleFocusMinutes,
    int? cycleShortBreakMinutes,
    int? cycleLongBreakMinutes,
    int? cycleTargetLoops,
    InstrumentThemeMode? themeMode,
  }) {
    return FocusSettings(
      showDigits: showDigits ?? this.showDigits,
      showCentiseconds: showCentiseconds ?? this.showCentiseconds,
      ignitionThresholdMinutes:
          ignitionThresholdMinutes ?? this.ignitionThresholdMinutes,
      cycleFocusMinutes: cycleFocusMinutes ?? this.cycleFocusMinutes,
      cycleShortBreakMinutes:
          cycleShortBreakMinutes ?? this.cycleShortBreakMinutes,
      cycleLongBreakMinutes:
          cycleLongBreakMinutes ?? this.cycleLongBreakMinutes,
      cycleTargetLoops: cycleTargetLoops ?? this.cycleTargetLoops,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'showDigits': showDigits,
        'showCentiseconds': showCentiseconds,
        'ignitionThresholdMinutes': ignitionThresholdMinutes,
        'cycleFocusMinutes': cycleFocusMinutes,
        'cycleShortBreakMinutes': cycleShortBreakMinutes,
        'cycleLongBreakMinutes': cycleLongBreakMinutes,
        'cycleTargetLoops': cycleTargetLoops,
        'themeMode': themeMode.name,
      };

  factory FocusSettings.fromJson(Map<String, dynamic> json) {
    return FocusSettings(
      showDigits: json['showDigits'] as bool? ?? false,
      showCentiseconds: json['showCentiseconds'] as bool? ?? false,
      ignitionThresholdMinutes: json['ignitionThresholdMinutes'] as int? ?? 10,
      cycleFocusMinutes: json['cycleFocusMinutes'] as int? ?? 25,
      cycleShortBreakMinutes: json['cycleShortBreakMinutes'] as int? ?? 5,
      cycleLongBreakMinutes: json['cycleLongBreakMinutes'] as int? ?? 15,
      cycleTargetLoops: json['cycleTargetLoops'] as int? ?? 4,
      themeMode: InstrumentThemeMode.values.firstWhere(
        (t) => t.name == json['themeMode'],
        orElse: () => InstrumentThemeMode.stoneLight,
      ),
    );
  }
}

/// A segment in the cognitive depth timeline.
class CognitiveDepthSegment {
  final DateTime startTime;
  final DateTime endTime;
  final CognitiveDepthLevel level;
  final int durationSeconds;

  const CognitiveDepthSegment({
    required this.startTime,
    required this.endTime,
    required this.level,
    required this.durationSeconds,
  });
}
