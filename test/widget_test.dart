import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magn/main.dart';

void main() {
  testWidgets('StopwatchApp smoke test verifies initial flat matte wordless UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Main workspace: Play button icon, mode segmented icons, action icons
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.all_inclusive_rounded), findsOneWidget);
    expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Nearly wordless workspace: no START, ENDLESS, or 00:00 text
    expect(find.text('START'), findsNothing);
    expect(find.text('ENDLESS'), findsNothing);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('Mode switcher toggles between Endless and Pomodoro',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Initially in Endless mode: no skip phase button
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

    // Switch to Pomodoro mode
    await tester.tap(find.byIcon(Icons.timelapse_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // In Pomodoro mode: secondary skip button is present
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

    // Switch back to Endless mode
    await tester.tap(find.byIcon(Icons.all_inclusive_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Secondary skip button disappears in Endless mode
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
  });

  testWidgets('Analytics button opens Bento Analytics dashboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StopwatchApp());

    // Tap Analytics icon button
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Bento cards and 7-Day chart
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Ignition'), findsOneWidget);
    expect(find.text('Flow'), findsNWidgets(2)); // Bento card & chart legend
    expect(find.text('Ratio'), findsOneWidget);
    expect(find.text('7-Day Flow'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
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

    // Close Settings sheet by popping
    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Now numerical digits are displayed
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('.00'), findsOneWidget);
  });

  testWidgets('Skip button skips Pomodoro phase',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StopwatchApp());

    // Switch to Pomodoro mode
    await tester.tap(find.byIcon(Icons.timelapse_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

    // Tap Skip button
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // App remains responsive and in Pomodoro mode
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
  });
}
