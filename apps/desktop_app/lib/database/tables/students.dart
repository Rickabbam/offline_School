import 'package:drift/drift.dart';

class Students extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get studentNumber => text().named('student_number').nullable()();
  TextColumn get firstName =>
      text().named('first_name').withLength(min: 1, max: 100)();
  TextColumn get middleName => text().named('middle_name').nullable()();
  TextColumn get lastName =>
      text().named('last_name').withLength(min: 1, max: 100)();
  TextColumn get dateOfBirth => text().named('date_of_birth').nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get profilePhotoUrl =>
      text().named('profile_photo_url').nullable()();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('local'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Guardians extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get studentId => text().named('student_id')();
  TextColumn get firstName => text().named('first_name')();
  TextColumn get lastName => text().named('last_name')();
  TextColumn get relationship =>
      text().withDefault(const Constant('guardian'))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get isPrimary =>
      boolean().named('is_primary').withDefault(const Constant(false))();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Enrollments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get studentId => text().named('student_id')();
  TextColumn get classArmId => text().named('class_arm_id')();
  TextColumn get academicYearId => text().named('academic_year_id')();
  TextColumn get enrollmentDate => text().named('enrollment_date')();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
