import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/views/today/today_screen.dart';

import 'package:taplift/providers/today_workout_provider.dart';
import 'package:taplift/providers/current_exercise_provider.dart';
import 'package:taplift/providers/quick_log_provider.dart';
import 'package:taplift/providers/settings_provider.dart';
import 'package:taplift/data/database/app_database.dart';
import 'package:taplift/models/enums.dart';

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

  @override
  Future<void> logSet() async {
    state = state.copyWith(isLogging: true);
    await Future.delayed(const Duration(milliseconds: 50));
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
  testWidgets('TodayScreen renders Rest Day when no workout exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayWorkoutProvider.overrideWith((ref) => null),
          todayExercisesProvider.overrideWith((ref) => []),
          currentExerciseProvider.overrideWith(
            (ref) => MockCurrentExerciseNotifier(ref, const AsyncValue.data(null)),
          ),
          inferredCurrentExerciseProvider.overrideWith((ref) => null),
        ],
        child: const CupertinoApp(
          home: TodayScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rest Day'), findsWidgets);
    expect(find.text('Take it easy today'), findsOneWidget);
  });

  testWidgets('TodayScreen renders workout title and exercises', (tester) async {
    final mockWorkout = WorkoutDay(
      id: 'w1',
      userId: 'u1',
      name: 'Push Day',
      sortIndex: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockExercises = [
      Exercise(
        id: 'e1',
        workoutDayId: 'w1',
        name: 'Bench Press',
        sortIndex: 0,
        lastSelectedReps: 8,
        lastSelectedWeight: 80.0,
        targetSets: 3,
        targetWeight: 0.0,
        repTargetMin: 8,
        repTargetMax: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayWorkoutProvider.overrideWith((ref) => mockWorkout),
          todayExercisesProvider.overrideWith((ref) => mockExercises),
          currentExerciseProvider.overrideWith(
            (ref) => MockCurrentExerciseNotifier(
              ref,
              AsyncValue.data(mockExercises.first),
            ),
          ),
          inferredCurrentExerciseProvider.overrideWith((ref) => mockExercises.first),
          quickLogProvider.overrideWith((ref) => MockQuickLogNotifier(ref)),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const CupertinoApp(
          home: TodayScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Bench Press'), findsWidgets);
  });
}
