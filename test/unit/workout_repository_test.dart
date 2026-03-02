import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_db.dart';

void main() {
  late TestDbContext ctx;

  setUp(() async {
    ctx = TestDbContext();
    await ctx.seedUser('u1');
  });

  tearDown(() => ctx.dispose());

  group('WorkoutRepository', () {
    test('createWorkoutDay creates and returns a day', () async {
      final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      expect(day.name, 'Push');
      expect(day.userId, 'u1');
      expect(day.sortIndex, 0);
    });

    test('getAllWorkoutDays returns sorted by sortIndex', () async {
      await ctx.workoutRepo.createWorkoutDay('u1', 'Legs', 2);
      await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      await ctx.workoutRepo.createWorkoutDay('u1', 'Pull', 1);

      final days = await ctx.workoutRepo.getAllWorkoutDays('u1');
      expect(days.map((d) => d.name).toList(), ['Push', 'Pull', 'Legs']);
    });

    test('getWorkoutDayForWeekday returns mapped day', () async {
      final push = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      await ctx.workoutRepo.setWeekdayPlan('u1', 1, push.id); // Mon → Push

      final resolved = await ctx.workoutRepo.getWorkoutDayForWeekday('u1', 1);
      expect(resolved, isNotNull);
      expect(resolved!.name, 'Push');
    });

    test('getWorkoutDayForWeekday returns null for rest day', () async {
      await ctx.workoutRepo.setWeekdayPlan('u1', 7, null); // Sun → Rest

      final resolved = await ctx.workoutRepo.getWorkoutDayForWeekday('u1', 7);
      expect(resolved, isNull);
    });

    test('getWorkoutDayForWeekday returns null when no plan exists', () async {
      final resolved = await ctx.workoutRepo.getWorkoutDayForWeekday('u1', 3);
      expect(resolved, isNull);
    });

    test('updateWorkoutDay changes name', () async {
      final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      await ctx.workoutRepo.updateWorkoutDay(day.id, 'Upper Body');

      final days = await ctx.workoutRepo.getAllWorkoutDays('u1');
      expect(days.first.name, 'Upper Body');
    });

    test('deleteWorkoutDay cascades to exercises and plans', () async {
      final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      await ctx.workoutRepo.createExercise(day.id, 'Bench', 0);
      await ctx.workoutRepo.setWeekdayPlan('u1', 1, day.id);

      await ctx.workoutRepo.deleteWorkoutDay(day.id);

      final days = await ctx.workoutRepo.getAllWorkoutDays('u1');
      expect(days, isEmpty);
      final exercises = await ctx.exerciseRepo.getExercisesForDay(day.id);
      expect(exercises, isEmpty);
    });

    test('setWeekdayPlan upserts (replaces existing)', () async {
      final push = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      final pull = await ctx.workoutRepo.createWorkoutDay('u1', 'Pull', 1);

      await ctx.workoutRepo.setWeekdayPlan('u1', 1, push.id);
      // Overwrite Monday with Pull
      await ctx.workoutRepo.setWeekdayPlan('u1', 1, pull.id);

      final resolved = await ctx.workoutRepo.getWorkoutDayForWeekday('u1', 1);
      expect(resolved!.name, 'Pull');

      // Only 1 plan should exist for weekday 1
      final plans = await ctx.workoutRepo.getWeekdayPlans('u1');
      final mondayPlans = plans.where((p) => p.weekday == 1);
      expect(mondayPlans.length, 1);
    });

    test('seedDefaultWorkouts creates PPL with 7 weekday plans', () async {
      await ctx.workoutRepo.seedDefaultWorkouts('u1');

      final days = await ctx.workoutRepo.getAllWorkoutDays('u1');
      expect(days.length, 3);
      expect(days.map((d) => d.name).toSet(), {'Push', 'Pull', 'Legs'});

      final plans = await ctx.workoutRepo.getWeekdayPlans('u1');
      expect(plans.length, 7);

      // Sunday should be rest
      final sunday = plans.firstWhere((p) => p.weekday == 7);
      expect(sunday.workoutDayId, isNull);
    });

    test('hasWorkoutDays is false for new user, true after seeding', () async {
      expect(await ctx.workoutRepo.hasWorkoutDays('u1'), false);
      await ctx.workoutRepo.seedDefaultWorkouts('u1');
      expect(await ctx.workoutRepo.hasWorkoutDays('u1'), true);
    });

    test('different users have isolated workout days', () async {
      await ctx.seedUser('u2', email: 'u2@test.com');
      await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
      await ctx.workoutRepo.createWorkoutDay('u2', 'Cardio', 0);

      final u1Days = await ctx.workoutRepo.getAllWorkoutDays('u1');
      final u2Days = await ctx.workoutRepo.getAllWorkoutDays('u2');
      expect(u1Days.length, 1);
      expect(u2Days.length, 1);
      expect(u1Days.first.name, 'Push');
      expect(u2Days.first.name, 'Cardio');
    });
  });
}
