import 'package:drift/drift.dart';

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get workoutDayId => text()();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  IntColumn get lastSelectedReps =>
      integer().withDefault(const Constant(8))();
  RealColumn get lastSelectedWeight =>
      real().withDefault(const Constant(20.0))();

  /// Target number of sets for this exercise (user-configurable)
  IntColumn get targetSets => integer().withDefault(const Constant(3))();

  /// Target working weight for this exercise (user-configurable, 0 = not set)
  RealColumn get targetWeight => real().withDefault(const Constant(0.0))();

  /// Rep target range: minimum reps (0 = AMRAP)
  IntColumn get repTargetMin => integer().withDefault(const Constant(8))();

  /// Rep target range: maximum reps (0 = AMRAP / no upper bound)
  IntColumn get repTargetMax => integer().withDefault(const Constant(12))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
