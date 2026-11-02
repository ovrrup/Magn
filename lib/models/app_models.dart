import 'package:flutter/material.dart';

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
  final String topic;
  final int plannedDurationMinutes;
  final TimeWindow? preferredWindow;
  final String? linkedGoalId;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedSessionId;

  const PlannedSession({
    required this.id,
    required this.topic,
    required this.plannedDurationMinutes,
    this.preferredWindow,
    this.linkedGoalId,
    required this.createdAt,
    this.isCompleted = false,
    this.completedAt,
    this.completedSessionId,
  });

  /// Evaluates estimated token reward based on standard 1.0x multiplier.
  int get estimatedBaseTokens => plannedDurationMinutes;

  /// Checks if this planned session is approaching its deadline or preferred window
  /// (today, overdue, or within the next 24 hours).
  bool isApproachingDeadline(DateTime now) {
    if (isCompleted) return false;
    if (preferredWindow == null) return false;

    // Check if preferred window start is within 24 hours or overdue today
    final windowTodayStart = DateTime(
      now.year,
      now.month,
      now.day,
      preferredWindow!.startHour,
      preferredWindow!.startMinute,
    );

    final diff = windowTodayStart.difference(now);
    // Overdue or within next 24 hours
    return diff.inHours <= 24;
  }

  PlannedSession copyWith({
    String? id,
    String? topic,
    int? plannedDurationMinutes,
    TimeWindow? preferredWindow,
    String? linkedGoalId,
    DateTime? createdAt,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedSessionId,
  }) {
    return PlannedSession(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      plannedDurationMinutes: plannedDurationMinutes ?? this.plannedDurationMinutes,
      preferredWindow: preferredWindow ?? this.preferredWindow,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedSessionId: completedSessionId ?? this.completedSessionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'plannedDurationMinutes': plannedDurationMinutes,
        'preferredWindow': preferredWindow?.toJson(),
        'linkedGoalId': linkedGoalId,
        'createdAt': createdAt.toIso8601String(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'completedSessionId': completedSessionId,
      };

  factory PlannedSession.fromJson(Map<String, dynamic> json) {
    return PlannedSession(
      id: json['id'] as String,
      topic: json['topic'] as String? ?? 'Focus Session',
      plannedDurationMinutes: json['plannedDurationMinutes'] as int? ?? 25,
      preferredWindow: json['preferredWindow'] != null
          ? TimeWindow.fromJson(json['preferredWindow'] as Map<String, dynamic>)
          : null,
      linkedGoalId: json['linkedGoalId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      completedSessionId: json['completedSessionId'] as String?,
    );
  }
}

/// A target objective or project goal created by the user.
class Goal {
  final String id;
  final String title;
  final DateTime? deadlineDate;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;

  const Goal({
    required this.id,
    required this.title,
    this.deadlineDate,
    required this.createdAt,
    this.isCompleted = false,
    this.completedAt,
  });

  /// Checks if this goal is approaching its deadline (today, overdue, or within 24h).
  bool isApproachingDeadline(DateTime now) {
    if (isCompleted || deadlineDate == null) return false;
    final deadline = deadlineDate!;
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);

    if (deadlineDay.isBefore(today)) return true; // Overdue
    if (deadlineDay.isAtSameMomentAs(today)) return true; // Today
    final diff = deadline.difference(now);
    return diff.inHours <= 24 && !diff.isNegative;
  }

  Goal copyWith({
    String? id,
    String? title,
    DateTime? deadlineDate,
    DateTime? createdAt,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'deadlineDate': deadlineDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Goal',
      deadlineDate: json['deadlineDate'] != null
          ? DateTime.tryParse(json['deadlineDate'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}

/// A completed focus session record logged in the system.
class CompletedSession {
  final String id;
  final String? plannedSessionId;
  final String topic;
  final DateTime startTime;
  final DateTime endTime;
  final int elapsedSeconds;
  final int baseTokens;
  final int flowTokens;
  final double windowMultiplier;
  final int totalTokensEarned;
  final bool isCancelled;
  final String? linkedGoalId;

  const CompletedSession({
    required this.id,
    this.plannedSessionId,
    required this.topic,
    required this.startTime,
    required this.endTime,
    required this.elapsedSeconds,
    required this.baseTokens,
    required this.flowTokens,
    required this.windowMultiplier,
    required this.totalTokensEarned,
    this.isCancelled = false,
    this.linkedGoalId,
  });

  int get elapsedMinutes => elapsedSeconds ~/ 60;

  Map<String, dynamic> toJson() => {
        'id': id,
        'plannedSessionId': plannedSessionId,
        'topic': topic,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'baseTokens': baseTokens,
        'flowTokens': flowTokens,
        'windowMultiplier': windowMultiplier,
        'totalTokensEarned': totalTokensEarned,
        'isCancelled': isCancelled,
        'linkedGoalId': linkedGoalId,
      };

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      id: json['id'] as String,
      plannedSessionId: json['plannedSessionId'] as String?,
      topic: json['topic'] as String? ?? 'Completed Session',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      baseTokens: json['baseTokens'] as int? ?? 0,
      flowTokens: json['flowTokens'] as int? ?? 0,
      windowMultiplier: (json['windowMultiplier'] as num?)?.toDouble() ?? 1.0,
      totalTokensEarned: json['totalTokensEarned'] as int? ?? 0,
      isCancelled: json['isCancelled'] as bool? ?? false,
      linkedGoalId: json['linkedGoalId'] as String?,
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
