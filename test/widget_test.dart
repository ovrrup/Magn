import 'package:flutter_test/flutter_test.dart';
import 'package:magn/main.dart';

void main() {
  testWidgets('StopwatchApp smoke test verifies initial UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Verify initial state shows START button and 00:00 timer display
    expect(find.text('START'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
  });
}
