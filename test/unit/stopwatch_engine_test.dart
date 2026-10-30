import 'package:flutter_test/flutter_test.dart';
import 'package:magn/domain/stopwatch_engine.dart';

void main() {
  group('StopwatchEngine Tests', () {
    late StopwatchEngine engine;

    setUp(() {
      engine = StopwatchEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('initial state is stopped with 0 elapsed', () {
      expect(engine.isRunning, isFalse);
      expect(engine.elapsedMilliseconds, equals(0));
      expect(engine.elapsedSeconds, equals(0));
      expect(engine.laps, isEmpty);
    });

    test('reset clears laps and elapsed duration', () {
      engine.start();
      engine.recordLap();
      engine.stop();
      engine.reset();

      expect(engine.isRunning, isFalse);
      expect(engine.elapsedMilliseconds, equals(0));
      expect(engine.laps, isEmpty);
    });

    test('recording lap returns null when stopped', () {
      expect(engine.recordLap(), isNull);
    });
  });
}
