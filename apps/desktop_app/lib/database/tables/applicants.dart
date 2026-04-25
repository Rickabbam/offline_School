import 'package:drift/drift.dart';

class Applicants extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get firstName => text().named('first_name')();
  TextColumn get middleName => text().named('middle_name').nullable()();
  TextColumn get lastName => text().named('last_name')();
  TextColumn get dateOfBirth => text().named('date_of_birth').nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get classLevelId => text().named('class_level_id').nullable()();
  TextColumn get academicYearId =>
      text().named('academic_year_id').nullable()();
  TextColumn get status => text().withDefault(const Constant('applied'))();
  TextColumn get guardianName => text().named('guardian_name').nullable()();
  TextColumn get guardianPhone => text().named('guardian_phone').nullable()();
  TextColumn get guardianEmail => text().named('guardian_email').nullable()();
  TextColumn get documentNotes => text().named('document_notes').nullable()();
  TextColumn get studentId => text().named('student_id').nullable()();
  DateTimeColumn get admittedAt => dateTime().named('admitted_at').nullable()();
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
