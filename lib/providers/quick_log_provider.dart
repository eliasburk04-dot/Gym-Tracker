import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'current_exercise_provider.dart';
import 'settings_provider.dart';

/// Snap a weight to the nearest multiple of [step] to prevent FP drift.
double _snapWeight(double raw, double step) {
  if (step <= 0) return raw;
  return (raw / step).round() * step;
}

/// Quick Log state: reps/weight for the current exercise stepper
class QuickLogState {
  final int reps;
  final double weight;
  final bool isLogging;

  const QuickLogState({
    this.reps = 8,
    this.weight = 20.0,
    this.isLogging = false,
  });

  QuickLogState copyWith({int? reps, double? weight, bool? isLogging}) {
    return QuickLogState(
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      isLogging: isLogging ?? this.isLogging,
    );
  }
}

class QuickLogNotifier extends StateNotifier<QuickLogState> {
  final Ref _ref;

  QuickLogNotifier(this._ref) : super(const QuickLogState()) {
    initFromExercise();
  }

  void initFromExercise() {
    final exerciseAsync = _ref.read(currentExerciseProvider);
    exerciseAsync.whenData((exercise) {
      if (exercise != null) {
        loadFromExercise(exercise);
      }
    });
  }

  void loadFromExercise(Exercise exercise) {
    // Prefer targetWeight when set, fall back to lastSelectedWeight
    final weight = exercise.targetWeight > 0
        ? exercise.targetWeight
        : exercise.lastSelectedWeight;
    // Prefer repTargetMin when set, fall back to lastSelectedReps
    final reps = exercise.repTargetMin > 0
        ? exercise.repTargetMin
        : exercise.lastSelectedReps;
    state = QuickLogState(
      reps: reps,
      weight: weight,
    );
  }

  void incrementReps() {
    if (state.reps < 99) {
      state = state.copyWith(reps: state.reps + 1);
    }
  }

  void decrementReps() {
    if (state.reps > 1) {
      state = state.copyWith(reps: state.reps - 1);
    }
  }

  void incrementWeight() {
    final step = _ref.read(weightIncrementProvider);
    state = state.copyWith(weight: _snapWeight(state.weight + step, step));
  }

  void decrementWeight() {
    final step = _ref.read(weightIncrementProvider);
    final newWeight = _snapWeight(state.weight - step, step);
    if (newWeight >= 0) {
      state = state.copyWith(weight: newWeight);
    }
  }

  /// Debounce guard — prevents double-tap logging duplicate sets.
  DateTime? _lastLogTime;

  Future<void> logSet() async {
    // Debounce: ignore taps within 500ms of last successful log
    final now = DateTime.now();
    if (_lastLogTime != null &&
        now.difference(_lastLogTime!).inMilliseconds < 500) {
      return;
    }

    final userId = _ref.read(currentUserIdProvider);
    final exercise = _ref.read(currentExerciseProvider).value;
    if (userId == null || exercise == null) return;

    // Prevent concurrent logs
    if (state.isLogging) return;

    state = state.copyWith(isLogging: true);

    try {
      final setRepo = _ref.read(setRepositoryProvider);
      await setRepo.logSet(
        exerciseId: exercise.id,
        userId: userId,
        reps: state.reps,
        weight: state.weight,
        source: 'app',
      );

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Update Live Activity
      final liveService = _ref.read(liveActivityServiceProvider);
      final todaySetCount = await setRepo.getTodaySetCount(exercise.id);
      final exercises = await _ref.read(todayExercisesProvider.future);
      final settings = _ref.read(settingsProvider);
      final currentIndex =
          exercises.indexWhere((e) => e.id == exercise.id);

      // Build rep target string for Live Activity
      String repTarget = '';
      if (exercise.repTargetMin > 0 && exercise.repTargetMax > 0) {
        if (exercise.repTargetMin == exercise.repTargetMax) {
          repTarget = '${exercise.repTargetMin}';
        } else {
          repTarget = '${exercise.repTargetMin}–${exercise.repTargetMax}';
        }
      } else if (exercise.repTargetMin == 0 && exercise.repTargetMax == 0) {
        repTarget = 'AMRAP';
      }

      // Last set summary
      final weightFmt = state.weight % 1 == 0
          ? state.weight.toInt().toString()
          : state.weight.toStringAsFixed(1);
      final lastSetSummary = '${state.reps}×$weightFmt ${settings.weightUnit.label}';

      await liveService.updateActivity(
        exerciseName: exercise.name,
        currentExerciseIndex: currentIndex >= 0 ? currentIndex : 0,
        reps: state.reps,
        weight: state.weight,
        setNumber: todaySetCount,
        totalSetsLogged: todaySetCount,
        repTarget: repTarget,
        lastSetSummary: lastSetSummary,
      );

      // Also update SharedState so the Live Activity widget reads fresh data
      await liveService.writeSharedState(
        currentExerciseId: exercise.id,
        currentExerciseName: exercise.name,
        reps: state.reps,
        weight: state.weight,
        weightUnit: settings.weightUnit.label,
        weightStep: settings.weightIncrement,
        exercises: exercises
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'lastReps': e.lastSelectedReps,
                  'lastWeight': e.lastSelectedWeight,
                  'targetSets': e.targetSets,
                })
            .toList(),
        currentExerciseIndex: currentIndex >= 0 ? currentIndex : 0,
      );

      // Try to sync in background
      final syncService = _ref.read(syncServiceProvider);
      syncService.syncSets(userId);

      _lastLogTime = DateTime.now();
    } finally {
      state = state.copyWith(isLogging: false);
    }
  }
}

final quickLogProvider =
    StateNotifierProvider<QuickLogNotifier, QuickLogState>((ref) {
  return QuickLogNotifier(ref);
});
