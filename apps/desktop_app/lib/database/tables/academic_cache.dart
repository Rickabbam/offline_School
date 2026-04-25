import 'package:drift/drift.dart';

class AcademicYearsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get label => text().withLength(min: 1, max: 20)();
  TextColumn get startDate => text().named('start_date')();
  TextColumn get endDate => text().named('end_date')();
  BoolColumn get isCurrent =>
      boolean().named('is_current').withDefault(const Constant(false))();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TermsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get academicYearId => text().named('academic_year_id')();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get termNumber => integer().named('term_number')();
  TextColumn get startDate => text().named('start_date')();
  TextColumn get endDate => text().named('end_date')();
  BoolColumn get isCurrent =>
      boolean().named('is_current').withDefault(const Constant(false))();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ClassLevelsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ClassArmsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get classLevelId => text().named('class_level_id')();
  TextColumn get arm => text().withLength(min: 1, max: 50)();
  TextColumn get displayName =>
      text().named('display_name').withLength(min: 1, max: 150)();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SubjectsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get code => text().nullable()();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class GradingSchemesCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get bandsJson => text().named('bands_json')();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();
  IntColumn get serverRevision =>
      integer().named('server_revision').withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
