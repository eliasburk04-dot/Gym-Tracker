import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/user_profiles_table.dart';
import 'tables/workout_days_table.dart';
import 'tables/weekday_plans_table.dart';
import 'tables/exercises_table.dart';
import 'tables/workout_sets_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [UserProfiles, WorkoutDays, WeekdayPlans, Exercises, WorkoutSets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS workout_sets_external_event_id_unique '
        'ON workout_sets (external_event_id)',
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Add targetSets and targetWeight columns to exercises
        await m.addColumn(exercises, exercises.targetSets);
        await m.addColumn(exercises, exercises.targetWeight);
      }
      if (from < 3) {
        // Add rep target range columns
        await m.addColumn(exercises, exercises.repTargetMin);
        await m.addColumn(exercises, exercises.repTargetMax);
        // Add setNumber and rir columns to workout_sets
        await m.addColumn(workoutSets, workoutSets.setNumber);
        await m.addColumn(workoutSets, workoutSets.rir);
      }
      if (from < 4) {
        await m.addColumn(workoutSets, workoutSets.externalEventId);
        await m.addColumn(workoutSets, workoutSets.originSessionId);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS workout_sets_external_event_id_unique '
          'ON workout_sets (external_event_id)',
        );
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'taplift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
