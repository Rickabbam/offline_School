import 'package:drift/drift.dart';

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get queueItemId => text().named('queue_item_id').nullable()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get schoolId => text().named('school_id')();
  TextColumn get campusId => text().named('campus_id').nullable()();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get operation => text()();
  TextColumn get conflictType => text().named('conflict_type')();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get serverMessage => text().named('server_message').nullable()();
  TextColumn get responseJson => text().named('response_json').nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
