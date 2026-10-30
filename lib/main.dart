import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/session_repository.dart';
import 'domain/stopwatch_engine.dart';
import 'presentation/controllers/stopwatch_controller.dart';
import 'presentation/screens/stopwatch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = LocalSessionRepository();
  final engine = StopwatchEngine();
  final controller = StopwatchController(
    engine: engine,
    repository: repository,
  );

  runApp(MagnApp(controller: controller));
}

/// Root widget of the Magn Stopwatch Application.
class MagnApp extends StatelessWidget {
  final StopwatchController controller;

  const MagnApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StopwatchScreen(controller: controller),
    );
  }
}
