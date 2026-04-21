import 'package:drift/drift.dart';

class AttendanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get studentId => text().named('student_id')();
  TextColumn get classArmId => text().named('class_arm_id')();
  TextColumn get academicYearId => text().named('academic_year_id')();
  TextColumn get termId => text().named('term_id')();
  TextColumn get attendanceDate => text().named('attendance_date')();
  // present | absent | late | excused
  TextColumn get status => text().withDefault(const Constant('present'))();
  TextColumn get notes => text().nullable()();
  TextColumn get recordedByUserId => text().named('recorded_by_user_id').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
