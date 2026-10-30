import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magn/presentation/widgets/timer_display.dart';

void main() {
  testWidgets('TimerDisplay renders formatted time correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            elapsedSeconds: 125,
            elapsedMilliseconds: 125000,
            showMilliseconds: false,
          ),
        ),
      ),
    );

    expect(find.text('02:05'), findsOneWidget);
  });

  testWidgets('TimerDisplay renders centiseconds when showMilliseconds is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            elapsedSeconds: 9,
            elapsedMilliseconds: 9450,
            showMilliseconds: true,
          ),
        ),
      ),
    );

    expect(find.text('00:09'), findsOneWidget);
    expect(find.text('.45'), findsOneWidget);
  });
}
