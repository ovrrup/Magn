/// Pure functional utilities for formatting time representations across Magn.
class TimeFormatter {
  TimeFormatter._();

  /// Formats elapsed seconds into `MM:SS` or `HH:MM:SS` (switches at 60+ minutes).
  static String formatElapsedSeconds(int totalSeconds) {
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

  /// Formats total milliseconds into primary timer parts (main time and centiseconds).
  static ({String mainTime, String centiseconds}) formatElapsedParts(
    int totalMilliseconds, {
    bool includeHours = false,
  }) {
    final totalSeconds = totalMilliseconds ~/ 1000;
    final centiseconds = ((totalMilliseconds % 1000) ~/ 10)
        .toString()
        .padLeft(2, '0');

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0 || includeHours) {
      final hh = hours.toString().padLeft(2, '0');
      return (mainTime: '$hh:$mm:$ss', centiseconds: centiseconds);
    }
    return (mainTime: '$mm:$ss', centiseconds: centiseconds);
  }

  /// Formats duration into human-readable shorthand: `24m 15s`, `1h 05m 20s`, etc.
  static String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Formats milliseconds into lap time representation: `01:23.45`
  static String formatLapTime(int totalMilliseconds) {
    final minutes = (totalMilliseconds ~/ 60000);
    final seconds = (totalMilliseconds % 60000) ~/ 1000;
    final centis = (totalMilliseconds % 1000) ~/ 10;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final cs = centis.toString().padLeft(2, '0');

    return '$mm:$ss.$cs';
  }

  /// Formats a DateTime into 24-hour `HH:mm` timestamp.
  static String formatTimestamp(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
