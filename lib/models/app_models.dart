/// Represents a preferred daily time window for focus sessions.
class TimeWindow {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const TimeWindow({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Formatted display string like "09:00 - 11:30".
  String toDisplayString() {
    final startH = startHour.toString().padLeft(2, '0');
    final startM = startMinute.toString().padLeft(2, '0');
    final endH = endHour.toString().padLeft(2, '0');
    final endM = endMinute.toString().padLeft(2, '0');
    return '$startH:$startM – $endH:$endM';
  }

  int get _startTotalMinutes => startHour * 60 + startMinute;
  int get _endTotalMinutes => endHour * 60 + endMinute;

  /// Checks whether [dateTime] falls inside this daily time window.
  bool isInside(DateTime dateTime) {
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    if (_startTotalMinutes <= _endTotalMinutes) {
      return currentMinutes >= _startTotalMinutes && currentMinutes <= _endTotalMinutes;
    } else {
      // Overnight window (e.g. 23:00 to 02:00)
      return currentMinutes >= _startTotalMinutes || currentMinutes <= _endTotalMinutes;
    }
  }

  /// Checks whether [dateTime] occurs before the window opens today.
  bool isBefore(DateTime dateTime) {
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    if (_startTotalMinutes <= _endTotalMinutes) {
      return currentMinutes < _startTotalMinutes;
    } else {
      return currentMinutes < _startTotalMinutes && currentMinutes > _endTotalMinutes;
    }
  }

  /// Checks whether [dateTime] occurs after the window closes today.
  bool isAfter(DateTime dateTime) {
    return !isInside(dateTime) && !isBefore(dateTime);
  }

  /// Returns the window relation multiplier category:
  /// - inside: 1.25x
  /// - before: 1.0x
  /// - after: 0.75x
  WindowRelation checkRelation(DateTime dateTime) {
    if (isInside(dateTime)) return WindowRelation.inside;
    if (isBefore(dateTime)) return WindowRelation.before;
    return WindowRelation.after;
  }

  Map<String, dynamic> toJson() => {
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
      };

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    return TimeWindow(
      startHour: json['startHour'] as int? ?? 9,
      startMinute: json['startMinute'] as int? ?? 0,
      endHour: json['endHour'] as int? ?? 11,
      endMinute: json['endMinute'] as int? ?? 0,
    );
  }
}

/// Evaluation of the session start relative to the preferred time window.
enum WindowRelation {
  inside,
  before,
  after,
}

extension WindowRelationExtension on WindowRelation {
  double get multiplier {
    switch (this) {
      case WindowRelation.inside:
        return 1.25;
      case WindowRelation.before:
        return 1.0;
      case WindowRelation.after:
        return 0.75;
    }
  }

  String get label {
    switch (this) {
      case WindowRelation.inside:
        return '1.25x Window Bonus';
      case WindowRelation.before:
        return '1.0x Standard';
      case WindowRelation.after:
        return '0.75x Post-Window';
    }
  }
}

/// A planned focus session configured by the user.
class PlannedSession {
  final String id;
  final String topicTitle;
  final String? linkedGoalId;
  final int plannedMinutes;
  final int? preferredStartMinutesFromMidnight;
  final int? preferredEndMinutesFromMidnight;
  final String? deadlineIso;
  final String createdAtIso;
  final bool isCompleted;
  final String? completedAtIso;
  final String? completedSessionId;

  const PlannedSession({
    required this.id,
    required this.topicTitle,
    this.linkedGoalId,
    required this.plannedMinutes,
    this.preferredStartMinutesFromMidnight,
    this.preferredEndMinutesFromMidnight,
    this.deadlineIso,
    required this.createdAtIso,
    this.isCompleted = false,
    this.completedAtIso,
    this.completedSessionId,
  });

  String get topic => topicTitle;
  int get plannedDurationMinutes => plannedMinutes;
  int get estimatedBaseTokens => plannedMinutes;
  DateTime get createdAt => DateTime.tryParse(createdAtIso) ?? DateTime.now();
  DateTime? get deadlineDate => deadlineIso != null ? DateTime.tryParse(deadlineIso!) : null;
  DateTime? get completedAt => completedAtIso != null ? DateTime.tryParse(completedAtIso!) : null;

  TimeWindow? get preferredWindow {
    if (preferredStartMinutesFromMidnight == null || preferredEndMinutesFromMidnight == null) {
      return null;
    }
    return TimeWindow(
      startHour: preferredStartMinutesFromMidnight! ~/ 60,
      startMinute: preferredStartMinutesFromMidnight! % 60,
      endHour: preferredEndMinutesFromMidnight! ~/ 60,
      endMinute: preferredEndMinutesFromMidnight! % 60,
    );
  }

  /// Checks if this planned session is approaching its deadline or preferred window
  /// (today, overdue, or within the next 24 hours).
  bool isApproachingDeadline(DateTime now) {
    if (isCompleted) return false;
    if (deadlineDate != null) {
      final deadline = deadlineDate!;
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      if (deadlineDay.isBefore(today)) return true;
      if (deadlineDay.isAtSameMomentAs(today)) return true;
      final diff = deadline.difference(now);
      if (diff.inHours <= 24 && !diff.isNegative) return true;
    }
    if (preferredWindow != null) {
      final windowTodayStart = DateTime(
        now.year,
        now.month,
        now.day,
        preferredWindow!.startHour,
        preferredWindow!.startMinute,
      );
      final diff = windowTodayStart.difference(now);
      return diff.inHours <= 24;
    }
    return false;
  }

  PlannedSession copyWith({
    String? id,
    String? topicTitle,
    String? linkedGoalId,
    int? plannedMinutes,
    int? preferredStartMinutesFromMidnight,
    int? preferredEndMinutesFromMidnight,
    String? deadlineIso,
    String? createdAtIso,
    bool? isCompleted,
    String? completedAtIso,
    String? completedSessionId,
    // backwards compatibility arguments
    String? topic,
    int? plannedDurationMinutes,
    TimeWindow? preferredWindow,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    int? startMin = preferredStartMinutesFromMidnight;
    int? endMin = preferredEndMinutesFromMidnight;
    if (preferredWindow != null) {
      startMin = preferredWindow.startHour * 60 + preferredWindow.startMinute;
      endMin = preferredWindow.endHour * 60 + preferredWindow.endMinute;
    }

    return PlannedSession(
      id: id ?? this.id,
      topicTitle: topicTitle ?? (topic ?? this.topicTitle),
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      plannedMinutes: plannedMinutes ?? (plannedDurationMinutes ?? this.plannedMinutes),
      preferredStartMinutesFromMidnight: startMin ?? this.preferredStartMinutesFromMidnight,
      preferredEndMinutesFromMidnight: endMin ?? this.preferredEndMinutesFromMidnight,
      deadlineIso: deadlineIso ?? this.deadlineIso,
      createdAtIso: createdAtIso ?? (createdAt?.toIso8601String() ?? this.createdAtIso),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAtIso: completedAtIso ?? (completedAt?.toIso8601String() ?? this.completedAtIso),
      completedSessionId: completedSessionId ?? this.completedSessionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicTitle': topicTitle,
        'linkedGoalId': linkedGoalId,
        'plannedMinutes': plannedMinutes,
        'preferredStartMinutesFromMidnight': preferredStartMinutesFromMidnight,
        'preferredEndMinutesFromMidnight': preferredEndMinutesFromMidnight,
        'deadlineIso': deadlineIso,
        'createdAtIso': createdAtIso,
        'isCompleted': isCompleted,
        'completedAtIso': completedAtIso,
        'completedSessionId': completedSessionId,
        'topic': topicTitle,
        'plannedDurationMinutes': plannedMinutes,
        'preferredWindow': preferredWindow?.toJson(),
        'createdAt': createdAtIso,
        'completedAt': completedAtIso,
      };

  factory PlannedSession.fromJson(Map<String, dynamic> json) {
    int? startMin = json['preferredStartMinutesFromMidnight'] as int?;
    int? endMin = json['preferredEndMinutesFromMidnight'] as int?;
    if (startMin == null && json['preferredWindow'] != null) {
      final tw = TimeWindow.fromJson(json['preferredWindow'] as Map<String, dynamic>);
      startMin = tw.startHour * 60 + tw.startMinute;
      endMin = tw.endHour * 60 + tw.endMinute;
    }

    return PlannedSession(
      id: json['id'] as String,
      topicTitle: json['topicTitle'] as String? ?? (json['topic'] as String? ?? 'Focus Session'),
      linkedGoalId: json['linkedGoalId'] as String?,
      plannedMinutes: json['plannedMinutes'] as int? ?? (json['plannedDurationMinutes'] as int? ?? 25),
      preferredStartMinutesFromMidnight: startMin,
      preferredEndMinutesFromMidnight: endMin,
      deadlineIso: json['deadlineIso'] as String?,
      createdAtIso: json['createdAtIso'] as String? ??
          (json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAtIso: json['completedAtIso'] as String? ?? json['completedAt'] as String?,
      completedSessionId: json['completedSessionId'] as String?,
    );
  }
}

/// A target objective or project goal created by the user.
class GoalItem {
  final String id;
  final String title;
  final String createdAtIso;
  final String? deadlineIso;
  final int totalMinutesInvested;
  final bool isCompleted;

  const GoalItem({
    required this.id,
    required this.title,
    required this.createdAtIso,
    this.deadlineIso,
    this.totalMinutesInvested = 0,
    this.isCompleted = false,
  });

  DateTime get createdAt => DateTime.tryParse(createdAtIso) ?? DateTime.now();
  DateTime? get deadlineDate => deadlineIso != null ? DateTime.tryParse(deadlineIso!) : null;

  /// Checks if this goal is approaching its deadline (today, overdue, or within 24h).
  bool isApproachingDeadline(DateTime now) {
    if (isCompleted || deadlineIso == null) return false;
    final deadline = deadlineDate;
    if (deadline == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);

    if (deadlineDay.isBefore(today)) return true; // Overdue
    if (deadlineDay.isAtSameMomentAs(today)) return true; // Today
    final diff = deadline.difference(now);
    return diff.inHours <= 24 && !diff.isNegative;
  }

  GoalItem copyWith({
    String? id,
    String? title,
    String? createdAtIso,
    String? deadlineIso,
    int? totalMinutesInvested,
    bool? isCompleted,
    DateTime? deadlineDate,
    DateTime? createdAt,
  }) {
    return GoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtIso: createdAtIso ?? (createdAt?.toIso8601String() ?? this.createdAtIso),
      deadlineIso: deadlineIso ?? (deadlineDate?.toIso8601String() ?? this.deadlineIso),
      totalMinutesInvested: totalMinutesInvested ?? this.totalMinutesInvested,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAtIso': createdAtIso,
        'deadlineIso': deadlineIso,
        'totalMinutesInvested': totalMinutesInvested,
        'isCompleted': isCompleted,
        'createdAt': createdAtIso,
        'deadlineDate': deadlineIso,
      };

  factory GoalItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAtIso'] as String? ??
        (json['createdAt'] as String? ?? DateTime.now().toIso8601String());
    final deadline = json['deadlineIso'] as String? ?? json['deadlineDate'] as String?;
    return GoalItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Goal',
      createdAtIso: created,
      deadlineIso: deadline,
      totalMinutesInvested: json['totalMinutesInvested'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

typedef Goal = GoalItem;

/// A completed focus session record logged in the system.
class CompletedSession {
  final String id;
  final String topicTitle;
  final String? linkedGoalId;
  final int durationSeconds;
  final int tokensEarned;
  final double multiplierApplied;
  final String completedAtIso;
  final String? plannedSessionId;
  final bool isCancelled;

  CompletedSession({
    required this.id,
    String? topicTitle,
    this.linkedGoalId,
    int? durationSeconds,
    int? tokensEarned,
    double? multiplierApplied,
    String? completedAtIso,
    this.plannedSessionId,
    this.isCancelled = false,
    // Backwards compatibility parameter aliases:
    String? topic,
    int? elapsedSeconds,
    int? totalTokensEarned,
    double? windowMultiplier,
    DateTime? endTime,
    DateTime? startTime,
    int? baseTokens,
    int? flowTokens,
  })  : topicTitle = topicTitle ?? topic ?? 'Completed Session',
        durationSeconds = durationSeconds ?? elapsedSeconds ?? 0,
        tokensEarned = tokensEarned ?? totalTokensEarned ?? 0,
        multiplierApplied = multiplierApplied ?? windowMultiplier ?? 1.0,
        completedAtIso = completedAtIso ??
            (endTime?.toIso8601String() ?? DateTime.now().toIso8601String());

  String get topic => topicTitle;
  int get elapsedSeconds => durationSeconds;
  int get elapsedMinutes => durationSeconds ~/ 60;
  int get totalTokensEarned => tokensEarned;
  double get windowMultiplier => multiplierApplied;
  DateTime get endTime => DateTime.tryParse(completedAtIso) ?? DateTime.now();
  DateTime get startTime => endTime.subtract(Duration(seconds: durationSeconds));
  int get baseTokens => durationSeconds >= 60 ? (durationSeconds ~/ 60) : 0;
  int get flowTokens => (tokensEarned - (baseTokens * multiplierApplied).floor()).clamp(0, 999999);

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicTitle': topicTitle,
        'linkedGoalId': linkedGoalId,
        'durationSeconds': durationSeconds,
        'tokensEarned': tokensEarned,
        'multiplierApplied': multiplierApplied,
        'completedAtIso': completedAtIso,
        'plannedSessionId': plannedSessionId,
        'isCancelled': isCancelled,
        'topic': topicTitle,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'elapsedSeconds': durationSeconds,
        'baseTokens': baseTokens,
        'flowTokens': flowTokens,
        'windowMultiplier': multiplierApplied,
        'totalTokensEarned': tokensEarned,
      };

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      id: json['id'] as String,
      topicTitle: json['topicTitle'] as String? ?? (json['topic'] as String? ?? 'Completed Session'),
      linkedGoalId: json['linkedGoalId'] as String?,
      durationSeconds: json['durationSeconds'] as int? ?? (json['elapsedSeconds'] as int? ?? 0),
      tokensEarned: json['tokensEarned'] as int? ?? (json['totalTokensEarned'] as int? ?? 0),
      multiplierApplied: (json['multiplierApplied'] as num?)?.toDouble() ??
          ((json['windowMultiplier'] as num?)?.toDouble() ?? 1.0),
      completedAtIso: json['completedAtIso'] as String? ??
          (json['endTime'] as String? ?? DateTime.now().toIso8601String()),
      plannedSessionId: json['plannedSessionId'] as String?,
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }
}

/// Application settings and user preferences.
class AppSettings {
  final String themeMode; // 'sereneSky', 'midnightSky', 'oledBlack'
  final bool precisionShowCentiseconds;

  const AppSettings({
    this.themeMode = 'sereneSky',
    this.precisionShowCentiseconds = false,
  });

  bool get precisionEnabled => precisionShowCentiseconds;

  AppSettings copyWith({
    String? themeMode,
    bool? precisionShowCentiseconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      precisionShowCentiseconds:
          precisionShowCentiseconds ?? this.precisionShowCentiseconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'precisionShowCentiseconds': precisionShowCentiseconds,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: json['themeMode'] as String? ?? 'sereneSky',
      precisionShowCentiseconds:
          json['precisionShowCentiseconds'] as bool? ?? false,
    );
  }
}

/// Output profile generated by the Hidden Flow State Engine.
class FlowStateProfile {
  final double flowEntryThresholdMinutes;
  final double flowReadinessPercent;
  final bool hasSufficientData;
  final String readinessLabel;

  const FlowStateProfile({
    required this.flowEntryThresholdMinutes,
    required this.flowReadinessPercent,
    required this.hasSufficientData,
    required this.readinessLabel,
  });
}
