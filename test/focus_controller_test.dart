import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magn/models/focus_models.dart';
import 'package:magn/state/focus_controller.dart';
import 'package:magn/theme/instrument_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusController Tests', () {
    late FocusController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = FocusController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is stopped, endless mode, and stoneLight theme', () {
      expect(controller.isRunning, isFalse);
      expect(controller.mode, AppMode.endless);
      expect(controller.cyclePhase, CyclePhase.focus);
      expect(controller.cycleIndex, 1);
      expect(controller.settings.themeMode, InstrumentThemeMode.stoneLight);
      expect(controller.focusState, FocusState.idle);
      expect(controller.warmUpProgress, 0.0);
    });

    test('Mode switcher toggles between Endless and Cycle', () {
      expect(controller.mode, AppMode.endless);
      controller.setMode(AppMode.cycle);
      expect(controller.mode, AppMode.cycle);
      expect(controller.cyclePhase, CyclePhase.focus);

      controller.toggleMode();
      expect(controller.mode, AppMode.endless);
    });

    test('Timer start, toggleStartStop, and reset', () {
      expect(controller.isRunning, isFalse);
      controller.toggleStartStop();
      expect(controller.isRunning, isTrue);

      controller.toggleStartStop();
      expect(controller.isRunning, isFalse);

      controller.reset();
      expect(controller.elapsedMilliseconds, 0);
      expect(controller.cycleIndex, 1);
    });

    test('Distraction mark impulse creates mark and task in marks bucket', () {
      final initialMarkCount = controller.marks.length;
      final initialTaskCount = controller.tasks.length;

      controller.addDistractionMark('Review API contracts');

      expect(controller.marks.length, initialMarkCount + 1);
      expect(controller.marks.first.note, 'Review API contracts');

      expect(controller.tasks.length, initialTaskCount + 1);
      expect(controller.tasks.first.title, 'Review API contracts');
      expect(controller.tasks.first.bucket, TaskBucket.marks);
    });

    test('Task triage: create, toggleComplete, defer, and setActiveTask', () {
      controller.createTask('Implement Telemetry Chart', TaskBucket.today);
      final task = controller.tasks.first;
      expect(task.title, 'Implement Telemetry Chart');
      expect(task.bucket, TaskBucket.today);
      expect(task.isCompleted, isFalse);

      // Set as active intention
      controller.setActiveTask(task);
      expect(controller.activeTask?.id, task.id);

      // Toggle complete
      controller.toggleTaskComplete(task.id);
      final updated = controller.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.isCompleted, isTrue);

      // Defer to not today
      controller.deferTask(task.id);
      final deferred = controller.tasks.firstWhere((t) => t.id == task.id);
      expect(deferred.bucket, TaskBucket.deferred);
    });

    test('85th-percentile early-bailout survival math calculates personal ignition', () {
      // With seeded initial sessions, calculate personal ignition time
      final ignitionMinutes = controller.calculatePersonalIgnitionMinutes();
      expect(ignitionMinutes, greaterThanOrEqualTo(3));
      expect(ignitionMinutes, lessThanOrEqualTo(25));
    });

    test('JSON Export and Import schema validation', () async {
      final jsonExport = controller.exportDataJson();
      expect(jsonExport, contains('"schema": "pfi_backup_v1"'));
      expect(jsonExport, contains('"settings"'));
      expect(jsonExport, contains('"tasks"'));
      expect(jsonExport, contains('"sessions"'));

      // Validate import with valid schema
      final success = await controller.importFromJson(jsonExport, overwrite: true);
      expect(success, isTrue);

      // Validate import rejects invalid schema
      final invalidSuccess = await controller.importFromJson('{"schema":"unknown"}', overwrite: false);
      expect(invalidSuccess, isFalse);
    });
  });
}
