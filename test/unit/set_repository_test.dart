import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/data/database/app_database.dart';
import '../helpers/test_db.dart';

void main() {
  late TestDbContext ctx;
  late String dayId;
  late String exerciseId;

  setUp(() async {
    ctx = TestDbContext();
    await ctx.seedUser('u1');
    final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
    dayId = day.id;
    final ex = await ctx.exerciseRepo.createExercise(dayId, 'Bench Press', 0);
    exerciseId = ex.id;
  });

  tearDown(() => ctx.dispose());

  group('SetRepository.logSet', () {
    test('creates a set with correct fields', () async {
      final s = await ctx.setRepo.logSet(
        exerciseId: exerciseId,
        userId: 'u1',
        reps: 10,
        weight: 80.0,
      );

      expect(s.exerciseId, exerciseId);
      expect(s.userId, 'u1');
      expect(s.reps, 10);
      expect(s.weight, 80.0);
      expect(s.source, 'app'); // default
      expect(s.synced, false);
      expect(s.timestamp.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
    });

    test('set with liveActivity source', () async {
      final s = await ctx.setRepo.logSet(
        exerciseId: exerciseId,
        userId: 'u1',
        reps: 8,
        weight: 60.0,
        source: 'liveActivity',
      );

      expect(s.source, 'liveActivity');
    });

    test('logSet updates exercise lastSelectedReps and lastSelectedWeight', () async {
      await ctx.setRepo.logSet(
        exerciseId: exerciseId,
        userId: 'u1',
        reps: 12,
        weight: 85.0,
      );

      final ex = await ctx.exerciseRepo.getExerciseById(exerciseId);
      expect(ex!.lastSelectedReps, 12);
      expect(ex.lastSelectedWeight, 85.0);
    });

    test('multiple logs update lastSelected to the latest values', () async {
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 10, weight: 80.0);
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 82.5);

      final ex = await ctx.exerciseRepo.getExerciseById(exerciseId);
      expect(ex!.lastSelectedReps, 8);
      expect(ex.lastSelectedWeight, 82.5);
    });
  });

  group('SetRepository.getTodaySets', () {
    test('returns only today\'s sets', () async {
      // Log a set (today)
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);

      final todaySets = await ctx.setRepo.getTodaySets(exerciseId);
      expect(todaySets.length, 1);
    });

    test('returns empty for exercise with no sets', () async {
      final ex2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);
      final todaySets = await ctx.setRepo.getTodaySets(ex2.id);
      expect(todaySets, isEmpty);
    });
  });

  group('SetRepository.getTodaySetCount', () {
    test('counts correctly', () async {
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 6, weight: 62.5);

      final count = await ctx.setRepo.getTodaySetCount(exerciseId);
      expect(count, 3);
    });

    test('returns 0 when no sets today', () async {
      final count = await ctx.setRepo.getTodaySetCount(exerciseId);
      expect(count, 0);
    });
  });

  group('SetRepository.getLastPerformance', () {
    test('returns most recent set ever', () async {
      // Insert with explicit timestamps to guarantee ordering (Drift stores seconds)
      final t1 = DateTime(2026, 3, 2, 10, 0, 0);
      final t2 = DateTime(2026, 3, 2, 10, 0, 5); // 5 seconds later

      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's1', exerciseId: exerciseId, userId: 'u1',
          reps: 10, weight: 70.0, timestamp: Value(t1),
        ),
      );
      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's2', exerciseId: exerciseId, userId: 'u1',
          reps: 8, weight: 75.0, timestamp: Value(t2),
        ),
      );

      final last = await ctx.setRepo.getLastPerformance(exerciseId);
      expect(last, isNotNull);
      expect(last!.reps, 8);
      expect(last.weight, 75.0);
    });

    test('returns null when no sets exist', () async {
      final last = await ctx.setRepo.getLastPerformance(exerciseId);
      expect(last, isNull);
    });
  });

  group('SetRepository.getMostRecentExerciseIdToday', () {
    test('returns the exercise with most recent set today', () async {
      final ex2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      // Use explicit timestamps with second-level separation (Drift stores seconds)
      final now = DateTime.now();
      final t1 = now;
      final t2 = now.add(const Duration(seconds: 5));

      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's1', exerciseId: exerciseId, userId: 'u1',
          reps: 8, weight: 60.0, timestamp: Value(t1),
        ),
      );
      await ctx.db.into(ctx.db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's2', exerciseId: ex2.id, userId: 'u1',
          reps: 10, weight: 40.0, timestamp: Value(t2),
        ),
      );

      final result = await ctx.setRepo.getMostRecentExerciseIdToday(
        'u1', [exerciseId, ex2.id]);
      expect(result, ex2.id);
    });

    test('returns null when no sets today', () async {
      final result = await ctx.setRepo.getMostRecentExerciseIdToday(
        'u1', [exerciseId]);
      expect(result, isNull);
    });

    test('returns null for empty exercise list', () async {
      final result = await ctx.setRepo.getMostRecentExerciseIdToday('u1', []);
      expect(result, isNull);
    });
  });

  group('SetRepository sync', () {
    test('getUnsyncedSets returns unsynced sets', () async {
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 10, weight: 65.0);

      final unsynced = await ctx.setRepo.getUnsyncedSets('u1');
      expect(unsynced.length, 2);
      expect(unsynced.every((s) => s.synced == false), true);
    });

    test('markSynced sets synced=true', () async {
      final s1 = await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      final s2 = await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 10, weight: 65.0);

      await ctx.setRepo.markSynced([s1.id]);

      final unsynced = await ctx.setRepo.getUnsyncedSets('u1');
      expect(unsynced.length, 1);
      expect(unsynced.first.id, s2.id);
    });

    test('markSynced with empty list does nothing', () async {
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.markSynced([]);
      final unsynced = await ctx.setRepo.getUnsyncedSets('u1');
      expect(unsynced.length, 1);
    });
  });

  group('SetRepository edge cases', () {
    test('logging set for nonexistent exercise still inserts (FK not enforced by default)', () async {
      // Drift SQLite doesn't enforce FK by default unless pragma is set
      final s = await ctx.setRepo.logSet(
        exerciseId: 'ghost-exercise',
        userId: 'u1',
        reps: 8,
        weight: 60.0,
      );
      expect(s.exerciseId, 'ghost-exercise');
    });

    test('large number of sets (performance sanity)', () async {
      for (int i = 0; i < 200; i++) {
        await ctx.setRepo.logSet(
          exerciseId: exerciseId,
          userId: 'u1',
          reps: 8 + (i % 5),
          weight: 60.0 + (i % 10) * 2.5,
        );
      }

      final count = await ctx.setRepo.getTodaySetCount(exerciseId);
      expect(count, 200);

      final last = await ctx.setRepo.getLastPerformance(exerciseId);
      expect(last, isNotNull);
    });
  });

  group('SetRepository.logSet setNumber', () {
    test('auto-increments setNumber for each set today', () async {
      final s1 = await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      final s2 = await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      final s3 = await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 6, weight: 62.5);

      expect(s1.setNumber, 1);
      expect(s2.setNumber, 2);
      expect(s3.setNumber, 3);
    });

    test('setNumber is per-exercise', () async {
      final ex2 = await ctx.exerciseRepo.createExercise(dayId, 'OHP', 1);

      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);
      await ctx.setRepo.logSet(
        exerciseId: exerciseId, userId: 'u1', reps: 8, weight: 60.0);

      final s = await ctx.setRepo.logSet(
        exerciseId: ex2.id, userId: 'u1', reps: 10, weight: 40.0);
      expect(s.setNumber, 1); // First set for OHP today
    });

    test('rir is stored when provided', () async {
      final s = await ctx.setRepo.logSet(
        exerciseId: exerciseId,
        userId: 'u1',
        reps: 8,
        weight: 60.0,
        rir: 2,
      );
      expect(s.rir, 2);
    });

    test('rir defaults to null', () async {
      final s = await ctx.setRepo.logSet(
        exerciseId: exerciseId,
        userId: 'u1',
        reps: 8,
        weight: 60.0,
      );
      expect(s.rir, isNull);
    });
  });

  group('ExerciseRepository.updateRepTarget', () {
    test('updates repTargetMin and repTargetMax', () async {
      await ctx.exerciseRepo.updateRepTarget(exerciseId, 6, 10);
      final ex = await ctx.exerciseRepo.getExerciseById(exerciseId);
      expect(ex!.repTargetMin, 6);
      expect(ex.repTargetMax, 10);
    });

    test('AMRAP sets both to 0', () async {
      await ctx.exerciseRepo.updateRepTarget(exerciseId, 0, 0);
      final ex = await ctx.exerciseRepo.getExerciseById(exerciseId);
      expect(ex!.repTargetMin, 0);
      expect(ex.repTargetMax, 0);
    });

    test('default values are 8 and 12', () async {
      final ex = await ctx.exerciseRepo.getExerciseById(exerciseId);
      expect(ex!.repTargetMin, 8);
      expect(ex.repTargetMax, 12);
    });
  });
}
