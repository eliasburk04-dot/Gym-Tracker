import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SetRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SetRepository(this._db);

  /// Log a new set. Returns the created set.
  Future<WorkoutSet> logSet({
    required String exerciseId,
    required String userId,
    required int reps,
    required double weight,
    String source = 'app',
    int? rir,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Compute set number (1-based, per exercise today)
    final todaySets = await getTodaySets(exerciseId);
    final setNumber = todaySets.length + 1;

    await _db.into(_db.workoutSets).insert(WorkoutSetsCompanion.insert(
      id: id,
      exerciseId: exerciseId,
      userId: userId,
      reps: reps,
      weight: weight,
      setNumber: Value(setNumber),
      rir: Value(rir),
      source: Value(source),
      timestamp: Value(now),
    ));

    // Update exercise's last selected values
    await (_db.update(_db.exercises)
          ..where((t) => t.id.equals(exerciseId)))
        .write(ExercisesCompanion(
      lastSelectedReps: Value(reps),
      lastSelectedWeight: Value(weight),
      updatedAt: Value(now),
    ));

    return (_db.select(_db.workoutSets)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Get all sets for an exercise today
  Future<List<WorkoutSet>> getTodaySets(String exerciseId) {
    final todayStart = _todayStart();
    return (_db.select(_db.workoutSets)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.timestamp.isBiggerOrEqualValue(todayStart))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  /// Watch today's sets for an exercise
  Stream<List<WorkoutSet>> watchTodaySets(String exerciseId) {
    final todayStart = _todayStart();
    return (_db.select(_db.workoutSets)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.timestamp.isBiggerOrEqualValue(todayStart))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
  }

  /// Watch all sets for today (all exercises) for a user
  Stream<List<WorkoutSet>> watchAllTodaySets(String userId) {
    final todayStart = _todayStart();
    return (_db.select(_db.workoutSets)
          ..where((t) =>
              t.userId.equals(userId) &
              t.timestamp.isBiggerOrEqualValue(todayStart))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  /// Get the count of sets today for an exercise
  Future<int> getTodaySetCount(String exerciseId) async {
    final sets = await getTodaySets(exerciseId);
    return sets.length;
  }

  /// Get the last logged set for an exercise (ever — for "last performance")
  Future<WorkoutSet?> getLastPerformance(String exerciseId) {
    return (_db.select(_db.workoutSets)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get most recently interacted exercise today (for current exercise inference)
  Future<String?> getMostRecentExerciseIdToday(
      String userId, List<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return null;
    final todayStart = _todayStart();
    final result = await (_db.select(_db.workoutSets)
          ..where((t) =>
              t.userId.equals(userId) &
              t.exerciseId.isIn(exerciseIds) &
              t.timestamp.isBiggerOrEqualValue(todayStart))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return result?.exerciseId;
  }

  /// Get unsynced sets
  Future<List<WorkoutSet>> getUnsyncedSets(String userId) {
    return (_db.select(_db.workoutSets)
          ..where((t) =>
              t.userId.equals(userId) & t.synced.equals(false)))
        .get();
  }

  /// Mark sets as synced
  Future<void> markSynced(List<String> ids) async {
    await (_db.update(_db.workoutSets)
          ..where((t) => t.id.isIn(ids)))
        .write(const WorkoutSetsCompanion(synced: Value(true)));
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
