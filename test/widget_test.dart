import 'package:flutter_test/flutter_test.dart';
import 'package:magn/data/repositories/session_repository.dart';
import 'package:magn/domain/stopwatch_engine.dart';
import 'package:magn/main.dart';
import 'package:magn/presentation/controllers/stopwatch_controller.dart';

void main() {
  testWidgets('MagnApp smoke test verifies initial UI',
      (WidgetTester tester) async {
    final controller = StopwatchController(
      engine: StopwatchEngine(),
      repository: LocalSessionRepository(),
    );

    await tester.pumpWidget(MagnApp(controller: controller));

    // Verify initial state shows START button and 00:00 timer display
    expect(find.text('START'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
  });
}
