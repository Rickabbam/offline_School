import 'package:drift/drift.dart';

class SyncReconciliationRequestsCache extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get targetDeviceId => text().named('target_device_id')();
  TextColumn get reason => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get requestedAt => dateTime().named('requested_at')();
  DateTimeColumn get acknowledgedAt =>
      dateTime().named('acknowledged_at').nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
