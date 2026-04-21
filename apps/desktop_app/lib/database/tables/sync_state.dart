import 'package:drift/drift.dart';

/// Tracks the last successfully pulled server_revision per entity type.
/// Used to request only delta (incremental) updates from the backend.
class SyncState extends Table {
  /// Entity type name, e.g. 'student', 'attendance_record'.
  TextColumn get entityType => text().withLength(min: 1, max: 100)();

  /// The last server_revision value received for this entity type.
  /// Start at 0 — meaning "pull everything from the beginning".
  IntColumn get lastServerRevision =>
      integer().withDefault(const Constant(0))();

  /// Timestamp of the last successful pull for this entity type.
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entityType};
}
