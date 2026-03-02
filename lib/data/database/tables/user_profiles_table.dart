import 'package:drift/drift.dart';

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get authProvider => text()(); // 'apple', 'google', 'email'
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  RealColumn get weightIncrement =>
      real().withDefault(const Constant(2.5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
