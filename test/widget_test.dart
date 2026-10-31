import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magn/main.dart';

void main() {
  testWidgets('StopwatchApp smoke test verifies initial Digit-Free Flow Orb UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Default: START button, ENDLESS mode pill, Analytics & Settings icons
    expect(find.text('START'), findsOneWidget);
    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    // showDigits is default false so digits are hidden
    expect(find.text('00:00'), findsNothing);
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
    expect(find.text('Skip Phase'), findsOneWidget);

    // Switch back to ENDLESS
    await tester.tap(find.text('POMODORO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ENDLESS'), findsOneWidget);
  });

  testWidgets('Analytics button opens Flow Analytics dashboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StopwatchApp());

    // Tap Analytics icon button
    await tester.tap(find.byIcon(Icons.insights_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify 3 Bento cards and 7-day chart
    expect(find.text('Flow Analytics'), findsOneWidget);
    expect(find.text('Personal Ignition'), findsOneWidget);
    expect(find.text('Total Flow Time'), findsOneWidget);
    expect(find.text('Flow Ratio'), findsOneWidget);
    expect(find.text('7-Day Focus & Flow Cadence'), findsOneWidget);
    expect(find.text('Focus Consistency Trend'), findsOneWidget);
  });

  testWidgets('Settings button opens Settings and enables Timer Digits',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StopwatchApp());

    // Tap Settings icon button
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Settings sections
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Data Management'), findsOneWidget);
    expect(find.text('Show Timer Digits'), findsOneWidget);
    expect(find.text('Pure Black OLED Mode'), findsOneWidget);

    // Enable "Show Timer Digits"
    await tester.tap(find.text('Show Timer Digits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Close Settings sheet by tapping top drag handle or popping
    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Now numerical digits are displayed
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('.00'), findsOneWidget);
  });

  testWidgets('Skip Phase advances Pomodoro phase',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Switch to POMODORO
    await tester.tap(find.text('ENDLESS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FOCUS'), findsOneWidget);

    // Tap Skip Phase button
    await tester.tap(find.text('Skip Phase'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SHORT BREAK'), findsOneWidget);
  });
}
