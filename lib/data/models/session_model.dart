import 'dart:convert';
import 'lap_model.dart';

/// Immutable model representing a saved stopwatch session with optional lap splits.
class SessionModel {
  final String id;
  final int durationInSeconds;
  final int durationInMilliseconds;
  final DateTime timestamp;
  final List<LapModel> laps;
  final String? note;

  const SessionModel({
    required this.id,
    required this.durationInSeconds,
    required this.durationInMilliseconds,
    required this.timestamp,
    this.laps = const [],
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'durationInSeconds': durationInSeconds,
      'durationInMilliseconds': durationInMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'laps': laps.map((l) => l.toMap()).toList(),
      'note': note,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as String? ?? '',
      durationInSeconds: map['durationInSeconds'] as int? ?? 0,
      durationInMilliseconds: map['durationInMilliseconds'] as int? ??
          ((map['durationInSeconds'] as int? ?? 0) * 1000),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      laps: (map['laps'] as List<dynamic>?)
              ?.map((item) => LapModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          const [],
      note: map['note'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SessionModel.fromJson(String source) =>
      SessionModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  SessionModel copyWith({
    String? id,
    int? durationInSeconds,
    int? durationInMilliseconds,
    DateTime? timestamp,
    List<LapModel> laps,
    String? note,
  }) {
    return SessionModel(
      id: id ?? this.id,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      durationInMilliseconds:
          durationInMilliseconds ?? this.durationInMilliseconds,
      timestamp: timestamp ?? this.timestamp,
      laps: laps ?? this.laps,
      note: note ?? this.note,
    );
  }
}
