import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magn/main.dart';

void main() {
  testWidgets('StopwatchApp smoke test verifies initial UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Verify initial state shows START button, 00:00 timer, .00 centiseconds, and ENDLESS pill
    expect(find.text('START'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('.00'), findsOneWidget);
    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });

  testWidgets('Mode switcher toggles between ENDLESS and POMODORO',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Switch to POMODORO
    await tester.tap(find.text('ENDLESS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('POMODORO'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Skip Phase'), findsOneWidget);

    // Switch back to ENDLESS
    await tester.tap(find.text('POMODORO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('.00'), findsOneWidget);
  });

  testWidgets('History button opens bottom sheet with Flow Analytics',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StopwatchApp());

    // Tap history button to open modal bottom sheet
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify bottom sheet tabs
    expect(find.text('Flow Analytics'), findsOneWidget);
    expect(find.text('Session Log'), findsOneWidget);
    expect(find.text('Time to reach flow'), findsOneWidget);
    expect(find.text('Deep state duration'), findsOneWidget);

    // Switch to Session Log
    await tester.tap(find.text('Session Log'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No sessions recorded'), findsOneWidget);
  });
}
