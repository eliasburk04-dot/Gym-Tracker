import 'package:drift/drift.dart';

/// Maps weekdays (1=Mon..7=Sun) to a workout day or rest.
class WeekdayPlans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get weekday => integer()(); // 1=Monday .. 7=Sunday
  TextColumn get workoutDayId => text().nullable()(); // null = Rest day

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
