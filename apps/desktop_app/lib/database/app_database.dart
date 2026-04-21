import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/sync_queue.dart';
import 'tables/sync_state.dart';

part 'app_database.g.dart';

/// The main local SQLite database for the desktop app.
///
/// Each campus installation has exactly one database file on disk.
/// Tables are defined as Drift [Table] subclasses and referenced here.
///
/// Schema version history:
///   1 — Phase A baseline: sync_queue + sync_state tables.
@DriftDatabase(tables: [SyncQueue, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Future migrations are added here as version increments.
          // Example:
          //   if (from < 2) { await m.createTable(newTable); }
        },
        beforeOpen: (details) async {
          // Enforce foreign keys on every connection.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Called from main() to ensure all migrations have run before the UI loads.
  Future<void> runMigrations() async {
    // Drift runs migrations automatically on first open via [migration].
    // This method exists as an explicit hook for startup sequencing.
    await executor.ensureOpen(this);
  }

  // ─── SyncQueue queries ─────────────────────────────────────────────────────

  /// Returns all queue items in [status] 'pending', ordered oldest first.
  Future<List<SyncQueueData>> getPendingQueueItems() =>
      (select(syncQueue)..where((t) => t.status.equals('pending'))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Marks a queue item as 'done' after successful push.
  Future<void> markQueueItemDone(String id) => (update(syncQueue)
        ..where((t) => t.id.equals(id)))
      .write(const SyncQueueCompanion(status: Value('done')));

  /// Increments retry count and resets to 'pending' for retry.
  Future<void> incrementQueueRetry(String id) async {
    final item = await (select(syncQueue)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (item == null) return;
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        status: const Value('pending'),
      ),
    );
  }

  /// Marks a queue item permanently failed (too many retries).
  Future<void> markQueueItemFailed(String id) => (update(syncQueue)
        ..where((t) => t.id.equals(id)))
      .write(const SyncQueueCompanion(status: Value('failed')));

  // ─── SyncState queries ─────────────────────────────────────────────────────

  /// Returns the last known server revision for [entityType], or 0.
  Future<int> getLastRevision(String entityType) async {
    final row = await (select(syncState)
          ..where((t) => t.entityType.equals(entityType)))
        .getSingleOrNull();
    return row?.lastServerRevision ?? 0;
  }

  /// Updates the stored server revision for [entityType].
  Future<void> updateLastRevision(String entityType, int revision) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(
        entityType: Value(entityType),
        lastServerRevision: Value(revision),
        lastPulledAt: Value(DateTime.now()),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationSupportDirectory();
    final file = File(p.join(dbDir.path, 'offline_school.db'));
    return NativeDatabase.createInBackground(file);
  });
}
