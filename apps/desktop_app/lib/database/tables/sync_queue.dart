import 'package:drift/drift.dart';

/// Tracks every local write that needs to be pushed to the backend.
class SyncQueue extends Table {
  /// UUID primary key (generated locally with uuid package).
  TextColumn get id => text()();

  /// Entity type name, e.g. 'student', 'attendance_record'.
  TextColumn get entityType => text().withLength(min: 1, max: 100)();

  /// UUID of the affected entity.
  TextColumn get entityId => text()();

  /// One of: create, update, delete.
  TextColumn get operation => text().withLength(min: 1, max: 20)();

  /// JSON-encoded payload of the full entity state at write time.
  TextColumn get payloadJson => text()();

  /// One of: pending, in_progress, done, failed.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Number of push attempts made so far.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Stable key used on the backend to de-duplicate repeated pushes.
  TextColumn get idempotencyKey => text()();

  /// Local timestamp of when the queue item was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
