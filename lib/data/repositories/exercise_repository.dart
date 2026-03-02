import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ExerciseRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ExerciseRepository(this._db);

  Stream<List<Exercise>> watchExercisesForDay(String workoutDayId) {
    return (_db.select(_db.exercises)
          ..where((t) => t.workoutDayId.equals(workoutDayId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<Exercise>> getExercisesForDay(String workoutDayId) {
    return (_db.select(_db.exercises)
          ..where((t) => t.workoutDayId.equals(workoutDayId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
  }

  Future<Exercise?> getExerciseById(String id) {
    return (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Exercise> createExercise(
      String workoutDayId, String name, int sortIndex) async {
    final id = _uuid.v4();
    await _db.into(_db.exercises).insert(ExercisesCompanion.insert(
      id: id,
      workoutDayId: workoutDayId,
      name: name,
      sortIndex: Value(sortIndex),
    ));
    return (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> updateExercise(String id, {String? name, int? sortIndex}) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        sortIndex:
            sortIndex != null ? Value(sortIndex) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLastSelected(
      String id, int reps, double weight) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        lastSelectedReps: Value(reps),
        lastSelectedWeight: Value(weight),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteExercise(String id) async {
    await (_db.delete(_db.workoutSets)
          ..where((t) => t.exerciseId.equals(id)))
        .go();
    await (_db.delete(_db.exercises)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderExercises(List<String> exerciseIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < exerciseIds.length; i++) {
        await (_db.update(_db.exercises)
              ..where((t) => t.id.equals(exerciseIds[i])))
            .write(ExercisesCompanion(sortIndex: Value(i)));
      }
    });
  }
}
