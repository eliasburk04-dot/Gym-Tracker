import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/data/database/app_database.dart';
import '../helpers/test_db.dart';

/// These tests run the exercise inference algorithm against a REAL in-memory DB,
/// not the pure-function mirror in current_exercise_test.dart.
void main() {
  late TestDbContext ctx;
  late String dayId;

  setUp(() async {
    ctx = TestDbContext();
    await ctx.seedUser('u1');
    final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
    dayId = day.id;
  });

  tearDown(() => ctx.dispose());

  /// Helper: run the inference algorithm against real repo data.
  Future<String?> inferCurrentExerciseId(List<String> exerciseIds) async {
    final exercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
    if (exercises.isEmpty) return null;

    for (final exercise in exercises) {
      final todaySets = await ctx.setRepo.getTodaySets(exercise.id);
      if (todaySets.isEmpty) return exercise.id;
    }

    final mostRecentId = await ctx.setRepo.getMostRecentExerciseIdToday(
      'u1', exerciseIds);
    return mostRecentId ?? exercises.first.id;
  }

  group('Current exercise inference (real DB)', () {
    test('no exercises → null', () async {
      final exercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
      expect(exercises, isEmpty);
      // Inference with empty list
      final result = await inferCurrentExerciseId([]);
      expect(result, isNull);
    });

    test('no sets logged → first exercise', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      final ids = (await ctx.exerciseRepo.getExercisesForDay(dayId))
          .map((e) => e.id).toList();
      final result = await inferCurrentExerciseId(ids);
      expect(result, e1.id);
    });

    test('first exercise has sets, second does not → second exercise', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final e2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      await ctx.setRepo.logSet(exerciseId: e1.id, userId: 'u1', reps: 8, weight: 60.0);

      final ids = [e1.id, e2.id];
      final result = await inferCurrentExerciseId(ids);
      expect(result, e2.id);
    });

    test('all exercises have sets → most recently interacted', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final e2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);
      final e3 = await ctx.exerciseRepo.createExercise(dayId, 'Flyes', 2);

      // Use explicit timestamps with second-level separation (Drift stores seconds)
      final now = DateTime.now();
      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's1', exerciseId: e1.id, userId: 'u1',
          reps: 8, weight: 60.0, timestamp: Value(now),
        ),
      );
      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's2', exerciseId: e3.id, userId: 'u1',
          reps: 12, weight: 15.0, timestamp: Value(now.add(const Duration(seconds: 5))),
        ),
      );
      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's3', exerciseId: e2.id, userId: 'u1',
          reps: 10, weight: 40.0, timestamp: Value(now.add(const Duration(seconds: 10))),
        ),
      );

      final ids = [e1.id, e2.id, e3.id];
      final result = await inferCurrentExerciseId(ids);
      expect(result, e2.id); // most recent
    });

    test('reordering exercises affects which is "first unlogged"', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final e2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);
      final e3 = await ctx.exerciseRepo.createExercise(dayId, 'Flyes', 2);

      // Log sets for Bench only
      await ctx.setRepo.logSet(exerciseId: e1.id, userId: 'u1', reps: 8, weight: 60.0);

      // Before reorder: OHP (index 1) should be inferred
      var ids = (await ctx.exerciseRepo.getExercisesForDay(dayId))
          .map((e) => e.id).toList();
      var result = await inferCurrentExerciseId(ids);
      expect(result, e2.id);

      // Reorder: Flyes first, then OHP, then Bench
      await ctx.exerciseRepo.reorderExercises([e3.id, e2.id, e1.id]);

      // After reorder: Flyes (now index 0, no sets) should be inferred
      ids = (await ctx.exerciseRepo.getExercisesForDay(dayId))
          .map((e) => e.id).toList();
      result = await inferCurrentExerciseId(ids);
      expect(result, e3.id);
    });

    test('deleted exercise with orphan sets: inference skips it', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final e2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      await ctx.setRepo.logSet(exerciseId: e1.id, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.logSet(exerciseId: e2.id, userId: 'u1', reps: 10, weight: 40.0);

      // Delete e1 (its sets also get deleted by deleteExercise)
      await ctx.exerciseRepo.deleteExercise(e1.id);

      final exercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
      expect(exercises.length, 1);
      expect(exercises.first.id, e2.id);

      // All remaining exercises have sets → most recent
      final ids = exercises.map((e) => e.id).toList();
      final result = await inferCurrentExerciseId(ids);
      expect(result, e2.id);
    });
  });
}
