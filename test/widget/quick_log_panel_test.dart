import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/views/today/quick_log_panel.dart';

import 'package:taplift/providers/current_exercise_provider.dart';
import 'package:taplift/providers/quick_log_provider.dart';
import 'package:taplift/providers/settings_provider.dart';
import 'package:taplift/data/database/app_database.dart';
import 'package:taplift/models/enums.dart';
import 'package:taplift/views/widgets/stepper_control.dart';

// ── Mock Notifiers ──

class MockCurrentExerciseNotifier extends CurrentExerciseNotifier {
  MockCurrentExerciseNotifier(super.ref, this._initial);
  final AsyncValue<Exercise?> _initial;

  @override
  Future<void> init() async {
    state = _initial;
  }
}

class MockQuickLogNotifier extends QuickLogNotifier {
  MockQuickLogNotifier(super.ref);

  @override
  void initFromExercise() {
    state = const QuickLogState(reps: 10, weight: 100.0);
  }

  // Override to prevent real DB/Platform channel calls during UI tests
  @override
  Future<void> logSet() async {
    state = state.copyWith(isLogging: true);
    await Future.delayed(const Duration(milliseconds: 100));
    state = state.copyWith(isLogging: false);
  }
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> load() async {
    state = const SettingsState(weightUnit: WeightUnit.kg, weightIncrement: 2.5);
  }
}

void main() {
  final testExercise = Exercise(
    id: 'e1',
    workoutDayId: 'd1',
    name: 'Squat',
    sortIndex: 0,
    lastSelectedReps: 10,
    lastSelectedWeight: 100.0,
    targetSets: 3,
    targetWeight: 0.0,
    repTargetMin: 8,
    repTargetMax: 12,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createPanel() {
    return ProviderScope(
      overrides: [
        currentExerciseProvider.overrideWith(
          (ref) => MockCurrentExerciseNotifier(ref, AsyncValue.data(testExercise)),
        ),
        quickLogProvider.overrideWith((ref) => MockQuickLogNotifier(ref)),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: const CupertinoApp(
        home: CupertinoPageScaffold(
          child: DefaultTextStyle(
            style: TextStyle(color: CupertinoColors.black),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: QuickLogPanel(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('QuickLogPanel renders current exercise name and steppers', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.byType(StepperControl), findsNWidgets(2));
    expect(find.text('DONE SET'), findsOneWidget);
  });

  testWidgets('QuickLogPanel shows correct initial reps and weight values', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget); // reps
    expect(find.text('100'), findsOneWidget); // weight (100.0 formatted as "100")
  });

  testWidgets('QuickLogPanel steppers respond to taps', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    // The StepperControl uses CupertinoIcons.minus and CupertinoIcons.plus
    // Find all GestureDetectors inside StepperControls (the +/- buttons)
    // Each StepperControl has 2 _StepperButtons → 4 total tappable areas
    final stepperControls = find.byType(StepperControl);
    expect(stepperControls, findsNWidgets(2));

    // Find + buttons by icon
    final plusIcons = find.byIcon(CupertinoIcons.plus);
    final minusIcons = find.byIcon(CupertinoIcons.minus);
    expect(plusIcons, findsNWidgets(2));
    expect(minusIcons, findsNWidgets(2));

    // Tap reps + (first plus icon)
    await tester.tap(plusIcons.first);
    await tester.pumpAndSettle();
    expect(find.text('11'), findsOneWidget);

    // Tap weight + (second plus icon)
    await tester.tap(plusIcons.last);
    await tester.pumpAndSettle();
    expect(find.text('102.5'), findsOneWidget);
  });

  testWidgets('QuickLogPanel reps decrement works', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    final minusIcons = find.byIcon(CupertinoIcons.minus);

    // Tap reps - (first minus icon)
    await tester.tap(minusIcons.first);
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('QuickLogPanel renders nothing when no exercise', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentExerciseProvider.overrideWith(
            (ref) => MockCurrentExerciseNotifier(ref, const AsyncValue.data(null)),
          ),
          quickLogProvider.overrideWith((ref) => MockQuickLogNotifier(ref)),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            child: QuickLogPanel(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('DONE SET'), findsNothing);
    expect(find.byType(StepperControl), findsNothing);
  });

  testWidgets('DONE SET button has minimum tap target size', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    final doneButton = find.text('DONE SET');
    expect(doneButton, findsOneWidget);

    // The button should be at least 44pt tall (Apple HIG minimum)
    final size = tester.getSize(find.ancestor(
      of: doneButton,
      matching: find.byType(GestureDetector),
    ).first);
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('StepperControl has minimum 48pt tap targets', (tester) async {
    await tester.pumpWidget(createPanel());
    await tester.pumpAndSettle();

    // Each _StepperButton should have minTouchTarget (48pt default)
    final plusIcons = find.byIcon(CupertinoIcons.plus);
    for (int i = 0; i < 2; i++) {
      final parent = find.ancestor(
        of: plusIcons.at(i),
        matching: find.byType(SizedBox),
      ).first;
      final size = tester.getSize(parent);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    }
  });
}
