import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../utils/clock.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Resolves today's WorkoutDay from the weekday mapping.
/// Returns null if today is a rest day or no mapping exists.
final todayWorkoutProvider = FutureProvider<WorkoutDay?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final repo = ref.watch(workoutRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final weekday = clock.now().weekday; // 1=Mon..7=Sun (ISO 8601)
  return repo.getWorkoutDayForWeekday(userId, weekday);
});

/// All workout days for the current user
final allWorkoutDaysProvider = StreamProvider<List<WorkoutDay>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(workoutRepositoryProvider).watchAllWorkoutDays(userId);
});

/// Weekday plans for the current user
final weekdayPlansProvider = StreamProvider<List<WeekdayPlan>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(workoutRepositoryProvider).watchWeekdayPlans(userId);
});
