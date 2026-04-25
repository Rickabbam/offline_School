import 'package:drift/drift.dart';

class FeeCategories extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get billingTerm =>
      text().named('billing_term').withDefault(const Constant('per_term'))();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
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

class FeeStructureItems extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get feeCategoryId => text().named('fee_category_id')();
  TextColumn get classLevelId => text().named('class_level_id').nullable()();
  TextColumn get termId => text().named('term_id').nullable()();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
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

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get studentId => text().named('student_id')();
  TextColumn get academicYearId => text().named('academic_year_id')();
  TextColumn get termId => text().named('term_id')();
  TextColumn get classArmId => text().named('class_arm_id')();
  TextColumn get invoiceCode =>
      text().named('invoice_code').withLength(min: 1, max: 64)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get lineItemsJson => text().named('line_items_json')();
  RealColumn get totalAmount => real().named('total_amount')();
  TextColumn get generatedByUserId =>
      text().named('generated_by_user_id').nullable()();
  DateTimeColumn get postedAt => dateTime().named('posted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
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

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get invoiceId => text().named('invoice_id')();
  TextColumn get paymentCode =>
      text().named('payment_code').withLength(min: 1, max: 64)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get amount => real()();
  TextColumn get paymentMode =>
      text().named('payment_mode').withLength(min: 1, max: 32)();
  TextColumn get paymentDate => text().named('payment_date')();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receivedByUserId =>
      text().named('received_by_user_id').nullable()();
  DateTimeColumn get postedAt => dateTime().named('posted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
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

class PaymentReversals extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get paymentId => text().named('payment_id')();
  TextColumn get invoiceId => text().named('invoice_id')();
  RealColumn get amount => real()();
  TextColumn get reason => text().withLength(min: 1, max: 500)();
  TextColumn get reversedByUserId =>
      text().named('reversed_by_user_id').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
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
