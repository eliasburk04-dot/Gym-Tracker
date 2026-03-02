import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'today_workout_provider.dart';

/// Exercises for today's workout
final todayExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final workoutDay = await ref.watch(todayWorkoutProvider.future);
  if (workoutDay == null) return [];
  return ref.watch(exerciseRepositoryProvider).getExercisesForDay(workoutDay.id);
});

/// Infers the current exercise:
/// 1) First exercise today with zero sets logged today
/// 2) Else most recently interacted exercise today
/// 3) Else first exercise in the list
final inferredCurrentExerciseProvider =
    FutureProvider<Exercise?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final exercises = await ref.watch(todayExercisesProvider.future);
  if (exercises.isEmpty) return null;

  final setRepo = ref.watch(setRepositoryProvider);

  // Check each exercise for today's sets
  for (final exercise in exercises) {
    final todaySets = await setRepo.getTodaySets(exercise.id);
    if (todaySets.isEmpty) {
      return exercise; // First exercise with no sets today
    }
  }

  // All exercises have sets — return most recently interacted
  final exerciseIds = exercises.map((e) => e.id).toList();
  final mostRecentId =
      await setRepo.getMostRecentExerciseIdToday(userId, exerciseIds);
  if (mostRecentId != null) {
    return exercises.firstWhere((e) => e.id == mostRecentId);
  }

  return exercises.first;
});

/// State class for the current exercise (allows manual override)
class CurrentExerciseNotifier extends StateNotifier<AsyncValue<Exercise?>> {
  final Ref _ref;
  bool _manuallySet = false;

  CurrentExerciseNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final inferred =
          await _ref.read(inferredCurrentExerciseProvider.future);
      if (!_manuallySet) {
        state = AsyncValue.data(inferred);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setExercise(Exercise exercise) {
    _manuallySet = true;
    state = AsyncValue.data(exercise);
  }

  void reset() {
    _manuallySet = false;
    _init();
  }
}

final currentExerciseProvider =
    StateNotifierProvider<CurrentExerciseNotifier, AsyncValue<Exercise?>>(
        (ref) {
  return CurrentExerciseNotifier(ref);
});

/// Today's set count per exercise
final todaySetCountProvider =
    FutureProvider.family<int, String>((ref, exerciseId) async {
  // Depend on allTodaySets so count updates reactively
  ref.watch(allTodaySetsProvider);
  final setRepo = ref.watch(setRepositoryProvider);
  return setRepo.getTodaySetCount(exerciseId);
});

/// All sets logged today (reactive stream)
final allTodaySetsProvider = StreamProvider<List<WorkoutSet>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(setRepositoryProvider).watchAllTodaySets(userId);
});

/// Last performance for a specific exercise
final lastPerformanceProvider =
    FutureProvider.family<WorkoutSet?, String>((ref, exerciseId) async {
  final setRepo = ref.watch(setRepositoryProvider);
  return setRepo.getLastPerformance(exerciseId);
});
