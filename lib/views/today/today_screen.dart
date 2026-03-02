import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/today_workout_provider.dart';
import '../../providers/current_exercise_provider.dart';
import '../../providers/quick_log_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import 'exercise_card.dart';
import 'quick_log_panel.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPendingSets();
    _startLiveActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPendingSets();
    }
  }

  /// Import sets logged from Live Activity into local DB (with dedup)
  Future<void> _syncPendingSets() async {
    final liveService = ref.read(liveActivityServiceProvider);
    final setRepo = ref.read(setRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final pendingSets = await liveService.syncPendingSets();
    for (final setData in pendingSets) {
      final exerciseId = setData['exerciseId'] as String;
      final reps = setData['reps'] as int;
      final weight = (setData['weight'] as num).toDouble();

      // Dedup: check if a set with same exercise, reps, weight and
      // source='liveActivity' was already imported in the last 30 seconds
      final recentSets = await setRepo.getTodaySets(exerciseId);
      final now = DateTime.now();
      final isDuplicate = recentSets.any((s) =>
          s.source == 'liveActivity' &&
          s.reps == reps &&
          s.weight == weight &&
          now.difference(s.timestamp).inSeconds < 30);
      if (isDuplicate) continue;

      await setRepo.logSet(
        exerciseId: exerciseId,
        userId: userId,
        reps: reps,
        weight: weight,
        source: 'liveActivity',
      );
    }
  }

  /// Start Live Activity on entering the Today screen
  Future<void> _startLiveActivity() async {
    try {
      final workout = await ref.read(todayWorkoutProvider.future);
      if (workout == null) return;

      final exercises = await ref.read(todayExercisesProvider.future);
      if (exercises.isEmpty) return;

      final currentExercise =
          await ref.read(inferredCurrentExerciseProvider.future);
      if (currentExercise == null) return;

      final currentIndex =
          exercises.indexWhere((e) => e.id == currentExercise.id);
      final settings = ref.read(settingsProvider);

      final liveService = ref.read(liveActivityServiceProvider);
      await liveService.startActivity(
        workoutDayName: workout.name,
        exerciseName: currentExercise.name,
        exercises: exercises
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'lastReps': e.lastSelectedReps,
                  'lastWeight': e.lastSelectedWeight,
                })
            .toList(),
        currentExerciseIndex: currentIndex >= 0 ? currentIndex : 0,
        reps: currentExercise.lastSelectedReps,
        weight: currentExercise.lastSelectedWeight,
        weightUnit: settings.weightUnit.label,
        weightStep: settings.weightIncrement,
      );
    } catch (_) {
      // Live Activity may not be available (simulator, etc.)
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final todayWorkout = ref.watch(todayWorkoutProvider);
    final todayExercises = ref.watch(todayExercisesProvider);
    final currentExercise = ref.watch(currentExerciseProvider);

    return CupertinoPageScaffold(
      child: Column(
        children: [
          // Use a regular header
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                todayWorkout.when(
                  data: (day) => Text(
                    day?.name ?? 'Rest Day',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                    ),
                  ),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (_, _) => const Text('Error'),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.push('/settings'),
                  child: const Icon(
                    CupertinoIcons.gear,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Exercise list
          Expanded(
            child: todayExercises.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.moon_zzz,
                          size: 48,
                          color: CupertinoColors.systemGrey3,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rest Day',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Take it easy today',
                          style: TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 200),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    final isCurrent = currentExercise.whenOrNull(
                            data: (e) => e?.id == exercise.id) ??
                        false;

                    return ExerciseCard(
                      exercise: exercise,
                      isCurrent: isCurrent,
                      onTap: () {
                        ref
                            .read(currentExerciseProvider.notifier)
                            .setExercise(exercise);
                        ref
                            .read(quickLogProvider.notifier)
                            .loadFromExercise(exercise);
                      },
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Quick log panel at bottom
          const QuickLogPanel(),
        ],
      ),
    );
  }
}
