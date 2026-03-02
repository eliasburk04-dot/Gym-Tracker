import 'package:drift/drift.dart';

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId => text()();
  TextColumn get userId => text()();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  TextColumn get source =>
      text().withDefault(const Constant('app'))(); // 'app' | 'liveActivity'
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
