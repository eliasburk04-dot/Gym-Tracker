import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:taplift/data/database/app_database.dart';
import 'package:taplift/data/repositories/workout_repository.dart';
import 'package:taplift/data/repositories/exercise_repository.dart';
import 'package:taplift/data/repositories/set_repository.dart';

/// Creates a fresh in-memory database for each test.
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Convenience: creates db + all three repos.
class TestDbContext {
  final AppDatabase db;
  final WorkoutRepository workoutRepo;
  final ExerciseRepository exerciseRepo;
  final SetRepository setRepo;

  TestDbContext._(this.db, this.workoutRepo, this.exerciseRepo, this.setRepo);

  factory TestDbContext() {
    final db = createTestDatabase();
    return TestDbContext._(
      db,
      WorkoutRepository(db),
      ExerciseRepository(db),
      SetRepository(db),
    );
  }

  /// Seed a user profile for testing.
  Future<void> seedUser(String userId, {String email = 'test@test.com'}) async {
    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: userId,
        email: Value(email),
        authProvider: 'email',
      ),
    );
  }

  /// Seed the default PPL workout data and return workout day IDs.
  Future<Map<String, String>> seedDefaultWorkout(String userId) async {
    await workoutRepo.seedDefaultWorkouts(userId);
    final days = await workoutRepo.getAllWorkoutDays(userId);
    return {for (final d in days) d.name: d.id};
  }

  Future<void> dispose() async {
    await db.close();
  }
}
