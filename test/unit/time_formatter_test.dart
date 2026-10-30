import 'package:flutter_test/flutter_test.dart';
import 'package:magn/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter Tests', () {
    test('formatElapsedSeconds formats MM:SS correctly under 60 minutes', () {
      expect(TimeFormatter.formatElapsedSeconds(0), '00:00');
      expect(TimeFormatter.formatElapsedSeconds(9), '00:09');
      expect(TimeFormatter.formatElapsedSeconds(65), '01:05');
      expect(TimeFormatter.formatElapsedSeconds(3599), '59:59');
    });

    test('formatElapsedSeconds switches to HH:MM:SS at 60+ minutes', () {
      expect(TimeFormatter.formatElapsedSeconds(3600), '01:00:00');
      expect(TimeFormatter.formatElapsedSeconds(3665), '01:01:05');
      expect(TimeFormatter.formatElapsedSeconds(7325), '02:02:05');
    });

    test('formatDuration formats duration strings', () {
      expect(TimeFormatter.formatDuration(15), '0m 15s');
      expect(TimeFormatter.formatDuration(1455), '24m 15s');
      expect(TimeFormatter.formatDuration(3675), '1h 1m 15s');
    });

    test('formatTimestamp formats 24h timestamp', () {
      final dt = DateTime(2026, 10, 31, 14, 5);
      expect(TimeFormatter.formatTimestamp(dt), '14:05');

      final dt2 = DateTime(2026, 10, 31, 8, 30);
      expect(TimeFormatter.formatTimestamp(dt2), '08:30');
    });

    test('formatLapTime formats milliseconds into split times', () {
      expect(TimeFormatter.formatLapTime(12340), '00:12.34');
      expect(TimeFormatter.formatLapTime(65430), '01:05.43');
    });
  });
}
