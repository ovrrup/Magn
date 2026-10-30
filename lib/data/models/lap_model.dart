/// Immutable data model representing a single lap split.
class LapModel {
  final int lapNumber;
  final int splitTimeMs;
  final int totalTimeMs;

  const LapModel({
    required this.lapNumber,
    required this.splitTimeMs,
    required this.totalTimeMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'lapNumber': lapNumber,
      'splitTimeMs': splitTimeMs,
      'totalTimeMs': totalTimeMs,
    };
  }

  factory LapModel.fromMap(Map<String, dynamic> map) {
    return LapModel(
      lapNumber: map['lapNumber'] as int? ?? 1,
      splitTimeMs: map['splitTimeMs'] as int? ?? 0,
      totalTimeMs: map['totalTimeMs'] as int? ?? 0,
    );
  }

  LapModel copyWith({
    int? lapNumber,
    int? splitTimeMs,
    int? totalTimeMs,
  }) {
    return LapModel(
      lapNumber: lapNumber ?? this.lapNumber,
      splitTimeMs: splitTimeMs ?? this.splitTimeMs,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LapModel &&
          runtimeType == other.runtimeType &&
          lapNumber == other.lapNumber &&
          splitTimeMs == other.splitTimeMs &&
          totalTimeMs == other.totalTimeMs;

  @override
  int get hashCode =>
      lapNumber.hashCode ^ splitTimeMs.hashCode ^ totalTimeMs.hashCode;
}
