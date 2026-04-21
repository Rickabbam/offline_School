import 'package:drift/drift.dart';

class Staff extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get staffNumber => text().named('staff_number').nullable()();
  TextColumn get firstName => text().named('first_name')();
  TextColumn get middleName => text().named('middle_name').nullable()();
  TextColumn get lastName => text().named('last_name')();
  TextColumn get gender => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get systemRole => text().named('system_role').withDefault(const Constant('teacher'))();
  TextColumn get employmentType => text().named('employment_type').withDefault(const Constant('permanent'))();
  TextColumn get dateJoined => text().named('date_joined').nullable()();
  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
