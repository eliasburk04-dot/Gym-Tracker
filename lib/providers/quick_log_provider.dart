import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'current_exercise_provider.dart';
import 'settings_provider.dart';

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
    _initFromExercise();
  }

  void _initFromExercise() {
    final exerciseAsync = _ref.read(currentExerciseProvider);
    exerciseAsync.whenData((exercise) {
      if (exercise != null) {
        state = QuickLogState(
          reps: exercise.lastSelectedReps,
          weight: exercise.lastSelectedWeight,
        );
      }
    });
  }

  void loadFromExercise(Exercise exercise) {
    state = QuickLogState(
      reps: exercise.lastSelectedReps,
      weight: exercise.lastSelectedWeight,
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
    state = state.copyWith(weight: state.weight + step);
  }

  void decrementWeight() {
    final step = _ref.read(weightIncrementProvider);
    final newWeight = state.weight - step;
    if (newWeight >= 0) {
      state = state.copyWith(weight: newWeight);
    }
  }

  Future<void> logSet() async {
    final userId = _ref.read(currentUserIdProvider);
    final exercise = _ref.read(currentExerciseProvider).value;
    if (userId == null || exercise == null) return;

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
      await liveService.updateActivity(
        exerciseName: exercise.name,
        currentExerciseIndex: 0,
        reps: state.reps,
        weight: state.weight,
        setNumber: todaySetCount,
        totalSetsLogged: todaySetCount,
      );

      // Try to sync in background
      final syncService = _ref.read(syncServiceProvider);
      syncService.syncSets(userId);
    } finally {
      state = state.copyWith(isLogging: false);
    }
  }
}

final quickLogProvider =
    StateNotifierProvider<QuickLogNotifier, QuickLogState>((ref) {
  return QuickLogNotifier(ref);
});
