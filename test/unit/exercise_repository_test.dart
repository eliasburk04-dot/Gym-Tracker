import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_db.dart';

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

  group('ExerciseRepository', () {
    test('createExercise returns the created exercise', () async {
      final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench Press', 0);
      expect(ex.name, 'Bench Press');
      expect(ex.workoutDayId, dayId);
      expect(ex.sortIndex, 0);
      expect(ex.lastSelectedReps, 8); // default
      expect(ex.lastSelectedWeight, 20.0); // default
    });

    test('getExercisesForDay returns sorted by sortIndex', () async {
      await ctx.exerciseRepo.createExercise(dayId, 'Flyes', 2);
      await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      final exercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
      expect(exercises.map((e) => e.name).toList(), ['Bench', 'OHP', 'Flyes']);
    });

    test('getExerciseById returns exercise or null', () async {
      final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final found = await ctx.exerciseRepo.getExerciseById(ex.id);
      expect(found, isNotNull);
      expect(found!.name, 'Bench');

      final missing = await ctx.exerciseRepo.getExerciseById('nonexistent');
      expect(missing, isNull);
    });

    test('updateExercise changes name', () async {
      final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.exerciseRepo.updateExercise(ex.id, name: 'Flat Bench Press');

      final updated = await ctx.exerciseRepo.getExerciseById(ex.id);
      expect(updated!.name, 'Flat Bench Press');
    });

    test('updateLastSelected persists reps and weight', () async {
      final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.exerciseRepo.updateLastSelected(ex.id, 12, 85.0);

      final updated = await ctx.exerciseRepo.getExerciseById(ex.id);
      expect(updated!.lastSelectedReps, 12);
      expect(updated.lastSelectedWeight, 85.0);
    });

    test('deleteExercise removes exercise and its sets', () async {
      final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.setRepo.logSet(
        exerciseId: ex.id,
        userId: 'u1',
        reps: 8,
        weight: 60.0,
      );

      await ctx.exerciseRepo.deleteExercise(ex.id);

      final found = await ctx.exerciseRepo.getExerciseById(ex.id);
      expect(found, isNull);

      final sets = await ctx.setRepo.getTodaySets(ex.id);
      expect(sets, isEmpty);
    });

    test('reorderExercises updates sortIndex values', () async {
      final e1 = await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      final e2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);
      final e3 = await ctx.exerciseRepo.createExercise(dayId, 'Flyes', 2);

      // Reverse order
      await ctx.exerciseRepo.reorderExercises([e3.id, e2.id, e1.id]);

      final exercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
      expect(exercises.map((e) => e.name).toList(), ['Flyes', 'OHP', 'Bench']);
    });

    test('exercises from different workout days are isolated', () async {
      final day2 = await ctx.workoutRepo.createWorkoutDay('u1', 'Pull', 1);

      await ctx.exerciseRepo.createExercise(dayId, 'Bench', 0);
      await ctx.exerciseRepo.createExercise(day2.id, 'Rows', 0);

      final pushExercises = await ctx.exerciseRepo.getExercisesForDay(dayId);
      final pullExercises = await ctx.exerciseRepo.getExercisesForDay(day2.id);

      expect(pushExercises.length, 1);
      expect(pullExercises.length, 1);
      expect(pushExercises.first.name, 'Bench');
      expect(pullExercises.first.name, 'Rows');
    });
  });
}
