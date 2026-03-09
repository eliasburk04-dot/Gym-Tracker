import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class WorkoutRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  WorkoutRepository(this._db);

  // ── Workout Days ──

  Stream<List<WorkoutDay>> watchAllWorkoutDays(String userId) {
    return (_db.select(_db.workoutDays)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<WorkoutDay>> getAllWorkoutDays(String userId) {
    return (_db.select(_db.workoutDays)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
  }

  Future<WorkoutDay?> getWorkoutDayForWeekday(
      String userId, int weekday) async {
    final plan = await (_db.select(_db.weekdayPlans)
          ..where(
              (t) => t.userId.equals(userId) & t.weekday.equals(weekday)))
        .getSingleOrNull();
    if (plan == null || plan.workoutDayId == null) return null;
    return (_db.select(_db.workoutDays)
          ..where((t) => t.id.equals(plan.workoutDayId!)))
        .getSingleOrNull();
  }

  Future<WorkoutDay> createWorkoutDay(
      String userId, String name, int sortIndex) async {
    final id = _uuid.v4();
    final companion = WorkoutDaysCompanion.insert(
      id: id,
      userId: userId,
      name: name,
      sortIndex: Value(sortIndex),
    );
    await _db.into(_db.workoutDays).insert(companion);
    return (_db.select(_db.workoutDays)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> updateWorkoutDay(String id, String name) async {
    await (_db.update(_db.workoutDays)..where((t) => t.id.equals(id)))
        .write(WorkoutDaysCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteWorkoutDay(String id) async {
    // Delete associated exercises, weekday plans
    await (_db.delete(_db.exercises)
          ..where((t) => t.workoutDayId.equals(id)))
        .go();
    await (_db.delete(_db.weekdayPlans)
          ..where((t) => t.workoutDayId.equals(id)))
        .go();
    await (_db.delete(_db.workoutDays)..where((t) => t.id.equals(id))).go();
  }

  // ── Weekday Plans ──

  Stream<List<WeekdayPlan>> watchWeekdayPlans(String userId) {
    return (_db.select(_db.weekdayPlans)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.weekday)]))
        .watch();
  }

  Future<List<WeekdayPlan>> getWeekdayPlans(String userId) {
    return (_db.select(_db.weekdayPlans)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.weekday)]))
        .get();
  }

  Future<void> setWeekdayPlan(
      String userId, int weekday, String? workoutDayId) async {
    // Upsert: delete existing for this weekday, then insert
    await (_db.delete(_db.weekdayPlans)
          ..where(
              (t) => t.userId.equals(userId) & t.weekday.equals(weekday)))
        .go();
    await _db.into(_db.weekdayPlans).insert(WeekdayPlansCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      weekday: weekday,
      workoutDayId: Value(workoutDayId),
    ));
  }

  // ── Seed Default Workouts ──

  Future<bool> hasWorkoutDays(String userId) async {
    final days = await getAllWorkoutDays(userId);
    return days.isNotEmpty;
  }

  Future<void> seedDefaultWorkouts(String userId) async {
    // Push day
    final push = await createWorkoutDay(userId, 'Push', 0);
    final pushExercises = [
      'Bench Press',
      'Overhead Press',
      'Incline Dumbbell Press',
      'Lateral Raises',
      'Tricep Pushdowns',
    ];
    for (var i = 0; i < pushExercises.length; i++) {
      await createExercise(push.id, pushExercises[i], i);
    }

    // Pull day
    final pull = await createWorkoutDay(userId, 'Pull', 1);
    final pullExercises = [
      'Barbell Rows',
      'Pull-ups',
      'Face Pulls',
      'Barbell Curls',
      'Hammer Curls',
    ];
    for (var i = 0; i < pullExercises.length; i++) {
      await createExercise(pull.id, pullExercises[i], i);
    }

    // Legs day
    final legs = await createWorkoutDay(userId, 'Legs', 2);
    final legsExercises = [
      'Squats',
      'Romanian Deadlifts',
      'Leg Press',
      'Leg Curls',
      'Calf Raises',
    ];
    for (var i = 0; i < legsExercises.length; i++) {
      await createExercise(legs.id, legsExercises[i], i);
    }

    // Default weekday mapping: Push-Pull-Legs-Push-Pull-Legs-Rest
    final mapping = [push.id, pull.id, legs.id, push.id, pull.id, legs.id];
    for (var i = 1; i <= 7; i++) {
      if (i <= 6) {
        await setWeekdayPlan(userId, i, mapping[i - 1]);
      } else {
        await setWeekdayPlan(userId, i, null); // Sunday = Rest
      }
    }
  }

  // ── Exercises (convenience) ──

  Future<void> createExercise(
      String workoutDayId, String name, int sortIndex) async {
    await _db.into(_db.exercises).insert(ExercisesCompanion.insert(
      id: _uuid.v4(),
      workoutDayId: workoutDayId,
      name: name,
      sortIndex: Value(sortIndex),
    ));
  }

  // ── Server Pull Upserts ──

  /// Upsert a workout day received from the server (last-write-wins by updatedAt).
  Future<void> upsertWorkoutDayFromServer({
    required String id,
    required String userId,
    required String name,
    required int sortIndex,
    DateTime? updatedAt,
  }) async {
    final existing = await (_db.select(_db.workoutDays)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.workoutDays).insert(WorkoutDaysCompanion.insert(
        id: id,
        userId: userId,
        name: name,
        sortIndex: Value(sortIndex),
      ));
    } else {
      // Only overwrite if server version is newer (or no local updatedAt)
      final serverTime = updatedAt ?? DateTime(0);
      if (serverTime.isAfter(existing.updatedAt)) {
        await (_db.update(_db.workoutDays)..where((t) => t.id.equals(id)))
            .write(WorkoutDaysCompanion(
          name: Value(name),
          sortIndex: Value(sortIndex),
          updatedAt: Value(serverTime),
        ));
      }
    }
  }

  /// Upsert an exercise received from the server (last-write-wins by updatedAt).
  Future<void> upsertExerciseFromServer({
    required String id,
    required String workoutDayId,
    required String name,
    required int sortIndex,
    required int lastSelectedReps,
    required double lastSelectedWeight,
    required int targetSets,
    required double targetWeight,
    required int repTargetMin,
    required int repTargetMax,
    DateTime? updatedAt,
  }) async {
    final existing = await (_db.select(_db.exercises)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.exercises).insert(ExercisesCompanion.insert(
        id: id,
        workoutDayId: workoutDayId,
        name: name,
        sortIndex: Value(sortIndex),
        lastSelectedReps: Value(lastSelectedReps),
        lastSelectedWeight: Value(lastSelectedWeight),
        targetSets: Value(targetSets),
        targetWeight: Value(targetWeight),
        repTargetMin: Value(repTargetMin),
        repTargetMax: Value(repTargetMax),
      ));
    } else {
      final serverTime = updatedAt ?? DateTime(0);
      if (serverTime.isAfter(existing.updatedAt)) {
        await (_db.update(_db.exercises)..where((t) => t.id.equals(id)))
            .write(ExercisesCompanion(
          name: Value(name),
          sortIndex: Value(sortIndex),
          lastSelectedReps: Value(lastSelectedReps),
          lastSelectedWeight: Value(lastSelectedWeight),
          targetSets: Value(targetSets),
          targetWeight: Value(targetWeight),
          repTargetMin: Value(repTargetMin),
          repTargetMax: Value(repTargetMax),
          updatedAt: Value(serverTime),
        ));
      }
    }
  }
}
