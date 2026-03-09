import 'package:drift/drift.dart';

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId => text()();
  TextColumn get userId => text()();
  IntColumn get setNumber => integer().withDefault(const Constant(1))();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  IntColumn get rir =>
      integer().nullable()(); // Rate of Perceived Exertion inverse — nullable
  TextColumn get externalEventId => text().nullable()();
  TextColumn get originSessionId => text().nullable()();
  TextColumn get source =>
      text().withDefault(const Constant('app'))(); // 'app' | 'liveActivity'
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
