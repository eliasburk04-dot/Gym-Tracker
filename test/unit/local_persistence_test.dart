import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Local Persistence (Drift)', () {
    test('Inserts and queries across relationships: WorkoutDay -> Exercise -> Set', () async {
      // Create user profile
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u1',
          email: const Value('test@example.com'),
          displayName: const Value('Test User'),
          authProvider: 'email',
        ),
      );

      // Create a Workout Day
      await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(
          id: 'd1',
          userId: 'u1',
          name: 'Push Day',
        ),
      );

      // Create an Exercise
      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: 'e1',
          workoutDayId: 'd1',
          name: 'Bench Press',
        ),
      );

      // Log a Set
      await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's1',
          exerciseId: 'e1',
          userId: 'u1',
          reps: 8,
          weight: 80.0,
        ),
      );

      // Query Back
      final sets = await db.select(db.workoutSets).get();
      expect(sets.length, 1);
      expect(sets.first.weight, 80.0);
      expect(sets.first.reps, 8);
      expect(sets.first.exerciseId, 'e1');
      expect(sets.first.userId, 'u1');

      final exercises = await db.select(db.exercises).get();
      expect(exercises.length, 1);
      expect(exercises.first.workoutDayId, 'd1');
    });
    
    test('Transaction Safety: Multiple quick writes', () async {
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u1',
          email: const Value('test@example.com'),
          authProvider: 'email',
        ),
      );

      await db.transaction(() async {
        await db.into(db.workoutDays).insert(
           WorkoutDaysCompanion.insert(id: 'd1', userId: 'u1', name: 'A'),
        );
        await db.into(db.workoutDays).insert(
           WorkoutDaysCompanion.insert(id: 'd2', userId: 'u1', name: 'B'),
        );
      });

      final days = await db.select(db.workoutDays).get();
      expect(days.length, 2);
    });

    test('Transaction rollback: failing insert rolls back entire transaction', () async {
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u1',
          authProvider: 'email',
        ),
      );

      await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(id: 'd_pre', userId: 'u1', name: 'Pre'),
      );

      try {
        await db.transaction(() async {
          await db.into(db.workoutDays).insert(
            WorkoutDaysCompanion.insert(id: 'd1', userId: 'u1', name: 'OK'),
          );
          // Duplicate primary key → should fail and roll back
          await db.into(db.workoutDays).insert(
            WorkoutDaysCompanion.insert(id: 'd1', userId: 'u1', name: 'Dup'),
          );
        });
        fail('Should have thrown');
      } catch (_) {
        // Expected
      }

      // Only the pre-existing row should survive
      final days = await db.select(db.workoutDays).get();
      expect(days.length, 1);
      expect(days.first.id, 'd_pre');
    });

    test('Concurrent writes to different tables succeed', () async {
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(id: 'u1', authProvider: 'email'),
      );

      await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(id: 'd1', userId: 'u1', name: 'Push'),
      );

      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(id: 'e1', workoutDayId: 'd1', name: 'Bench'),
      );

      // Simulate "concurrent" writes (interleaved inserts)
      final futures = <Future>[];
      for (int i = 0; i < 20; i++) {
        futures.add(
          db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: 's$i',
              exerciseId: 'e1',
              userId: 'u1',
              reps: 8,
              weight: 60.0 + i,
            ),
          ),
        );
      }
      await Future.wait(futures);

      final sets = await db.select(db.workoutSets).get();
      expect(sets.length, 20);
    });

    test('Default values populated correctly', () async {
      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: 'e1',
          workoutDayId: 'd1',
          name: 'Test Exercise',
        ),
      );

      final ex = await (db.select(db.exercises)
            ..where((t) => t.id.equals('e1')))
          .getSingle();

      expect(ex.lastSelectedReps, 8); // default
      expect(ex.lastSelectedWeight, 20.0); // default
      expect(ex.sortIndex, 0); // default
    });

    test('WorkoutSet default values', () async {
      await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          id: 's1',
          exerciseId: 'e1',
          userId: 'u1',
          reps: 10,
          weight: 50.0,
        ),
      );

      final s = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals('s1')))
          .getSingle();

      expect(s.source, 'app'); // default
      expect(s.synced, false); // default
    });
  });
}
