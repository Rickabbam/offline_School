import 'package:drift/drift.dart';

class TenantProfileCache extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get status => text().withLength(min: 1, max: 50)();
  TextColumn get contactEmail => text().named('contact_email').nullable()();
  TextColumn get contactPhone => text().named('contact_phone').nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SchoolProfileCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get shortName => text().named('short_name').nullable()();
  TextColumn get schoolType => text().named('school_type')();
  TextColumn get address => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get contactPhone => text().named('contact_phone').nullable()();
  TextColumn get contactEmail => text().named('contact_email').nullable()();
  TextColumn get onboardingDefaultsJson =>
      text().named('onboarding_defaults_json')();
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

class CampusProfileCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get address => text().nullable()();
  TextColumn get contactPhone => text().named('contact_phone').nullable()();
  TextColumn get registrationCode =>
      text().named('registration_code').nullable()();
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
