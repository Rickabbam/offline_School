import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/database/tables/academic_cache.dart';
import 'package:desktop_app/database/tables/applicants.dart';
import 'package:desktop_app/database/tables/attendance_records.dart';
import 'package:desktop_app/database/tables/finance.dart';
import 'package:desktop_app/database/tables/reconciliation_requests.dart';
import 'package:desktop_app/database/tables/staff.dart';
import 'package:desktop_app/database/tables/students.dart';
import 'package:desktop_app/database/tables/sync_conflicts.dart';
import 'package:desktop_app/database/tables/sync_queue.dart';
import 'package:desktop_app/database/tables/sync_state.dart';
import 'package:desktop_app/database/tables/workspace_cache.dart';

part 'app_database.g.dart';

class LocalDataScope {
  const LocalDataScope({
    required this.tenantId,
    required this.schoolId,
    this.campusId,
  });

  final String tenantId;
  final String schoolId;
  final String? campusId;
}

class LocalApplicantEnrollmentResult {
  const LocalApplicantEnrollmentResult({
    required this.studentId,
    required this.enrollmentId,
    this.guardianId,
  });

  final String studentId;
  final String enrollmentId;
  final String? guardianId;
}

/// The main local SQLite database for the desktop app.
///
/// Schema version history:
///   1 - Phase A baseline: sync_queue + sync_state tables.
///   2 - Phase B: students, guardians, enrollments, staff, applicants,
///                attendance_records tables.
///   3 - Phase B: academic metadata cache for offline attendance workspace.
///   4 - Phase B: subjects cache and staff teaching assignments.
///   5 - Phase B: durable local sync conflict log for manual review.
///   6 - Phase B: local natural-key uniqueness for attendance and enrollments.
///   7 - Phase B: local Lamport clocks on sync queue items.
///   8 - Phase B: durable server revisions for sync conflict detection.
///   9 - Phase B: grading scheme offline cache and sync support.
///   10 - Phase B: school and campus workspace cache.
///   11 - Phase B: durable reconciliation request cache for offline recovery visibility.
///   12 - Phase C: fee structures cache for offline finance configuration.
///   13 - Phase C: offline invoice generation and lifecycle cache.
///   14 - Phase C: offline payments and reversal entries.
///   15 - Phase B: tenant workspace cache for scoped identity bootstrap.
@DriftDatabase(tables: [
  SyncQueue,
  SyncState,
  SyncConflicts,
  SyncReconciliationRequestsCache,
  AcademicYearsCache,
  TermsCache,
  ClassLevelsCache,
  ClassArmsCache,
  SubjectsCache,
  GradingSchemesCache,
  FeeCategories,
  FeeStructureItems,
  Invoices,
  Payments,
  PaymentReversals,
  TenantProfileCache,
  SchoolProfileCache,
  CampusProfileCache,
  Students,
  Guardians,
  Enrollments,
  Staff,
  StaffTeachingAssignments,
  Applicants,
  AttendanceRecords,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : _uuid = const Uuid(),
        super(_openConnection());

  AppDatabase.forTesting(super.executor) : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(students);
            await m.createTable(guardians);
            await m.createTable(enrollments);
            await m.createTable(staff);
            await m.createTable(applicants);
            await m.createTable(attendanceRecords);
          }
          if (from < 3) {
            await m.createTable(academicYearsCache);
            await m.createTable(termsCache);
            await m.createTable(classLevelsCache);
            await m.createTable(classArmsCache);
          }
          if (from < 4) {
            await m.createTable(subjectsCache);
            await m.createTable(staffTeachingAssignments);
            await customStatement(
              'ALTER TABLE staff ADD COLUMN department TEXT',
            );
          }
          if (from < 5) {
            await m.createTable(syncConflicts);
          }
          if (from < 6) {
            await _ensureOperationalUniqueIndexes();
          }
          if (from < 7) {
            await customStatement(
              'ALTER TABLE sync_queue ADD COLUMN lamport_clock INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement('''
              UPDATE sync_queue
              SET lamport_clock = (
                SELECT COUNT(*)
                FROM sync_queue older
                WHERE older.created_at < sync_queue.created_at
                   OR (older.created_at = sync_queue.created_at AND older.id <= sync_queue.id)
              )
              WHERE lamport_clock = 0
            ''');
          }
          if (from < 8) {
            for (final statement in [
              "ALTER TABLE students ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE guardians ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE enrollments ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE staff ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE staff_teaching_assignments ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE applicants ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE attendance_records ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE academic_years_cache ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE terms_cache ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE class_levels_cache ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE class_arms_cache ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
              "ALTER TABLE subjects_cache ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0",
            ]) {
              await customStatement(statement);
            }
          }
          if (from < 9) {
            await m.createTable(gradingSchemesCache);
          }
          if (from < 10) {
            await m.createTable(schoolProfileCache);
            await m.createTable(campusProfileCache);
          }
          if (from < 11) {
            await m.createTable(syncReconciliationRequestsCache);
          }
          if (from < 12) {
            await m.createTable(feeCategories);
            await m.createTable(feeStructureItems);
          }
          if (from < 13) {
            await m.createTable(invoices);
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_local_invoices_student_term_unique
              ON invoices(tenant_id, school_id, student_id, term_id)
              WHERE deleted = 0
            ''');
          }
          if (from < 14) {
            await m.createTable(payments);
            await m.createTable(paymentReversals);
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_local_payment_reversals_payment_unique
              ON payment_reversals(tenant_id, school_id, payment_id)
              WHERE deleted = 0
            ''');
          }
          if (from < 15) {
            await m.createTable(tenantProfileCache);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await _ensureOperationalUniqueIndexes();
        },
      );

  /// Called from main() to ensure all migrations have run before the UI loads.
  Future<void> runMigrations() async {
    await executor.ensureOpen(this);
  }

  Future<void> exportBackupSnapshot(String outputPath) async {
    final escapedPath = outputPath.replaceAll("'", "''");
    await customStatement("VACUUM INTO '$escapedPath'");
  }

  Future<String> databaseFilePath() async {
    final dbDir = await getApplicationSupportDirectory();
    return p.join(dbDir.path, 'offline_school.db');
  }

  Future<void> replaceFromBackupSnapshot(String snapshotPath) async {
    final snapshotFile = File(snapshotPath);
    if (!await snapshotFile.exists()) {
      throw StateError('Restore snapshot does not exist: $snapshotPath');
    }

    final targetPath = await databaseFilePath();
    final targetFile = File(targetPath);
    final tempRestoreFile = File('$targetPath.restore.tmp');
    final walFile = File('$targetPath-wal');
    final shmFile = File('$targetPath-shm');

    await close();
    await tempRestoreFile.parent.create(recursive: true);
    if (await tempRestoreFile.exists()) {
      await tempRestoreFile.delete();
    }
    await snapshotFile.copy(tempRestoreFile.path);
    if (await walFile.exists()) {
      await walFile.delete();
    }
    if (await shmFile.exists()) {
      await shmFile.delete();
    }
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempRestoreFile.rename(targetPath);
  }

  Future<List<SyncQueueData>> getPendingQueueItems() => (select(syncQueue)
        ..where((t) => t.status.equals('pending'))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();

  Future<void> resetInProgressQueueItems() =>
      (update(syncQueue)..where((t) => t.status.equals('in_progress')))
          .write(const SyncQueueCompanion(status: Value('pending')));

  Future<SyncQueueData?> claimNextPendingQueueItem() async {
    return transaction(() async {
      final item = await (select(syncQueue)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      if (item == null) {
        return null;
      }

      final claimed = await (update(syncQueue)
            ..where(
              (t) => t.id.equals(item.id) & t.status.equals('pending'),
            ))
          .write(const SyncQueueCompanion(status: Value('in_progress')));
      if (claimed == 0) {
        return null;
      }

      return item;
    });
  }

  Future<void> markQueueItemDone(String id) =>
      (update(syncQueue)..where((t) => t.id.equals(id)))
          .write(const SyncQueueCompanion(status: Value('done')));

  Future<void> applyPushAcknowledgement({
    required String queueItemId,
    required String entityType,
    required String requestedEntityId,
    required String canonicalEntityId,
    required int serverRevision,
    required String tenantId,
    required String schoolId,
  }) async {
    final tableName = _tableNameForSyncEntity(entityType);
    if (tableName == null) {
      await markQueueItemDone(queueItemId);
      return;
    }

    await transaction(() async {
      final escapedTable = tableName;
      final requestedIdSql = _escapeSql(requestedEntityId);
      final canonicalIdSql = _escapeSql(canonicalEntityId);
      final tenantIdSql = _escapeSql(tenantId);
      final schoolIdSql = _escapeSql(schoolId);
      final scopeSql = entityType == 'school'
          ? "tenant_id = '$tenantIdSql'"
          : "tenant_id = '$tenantIdSql' AND school_id = '$schoolIdSql'";
      final existingScopeSql = entityType == 'school'
          ? "existing.tenant_id = '$tenantIdSql'"
          : "existing.tenant_id = '$tenantIdSql' AND existing.school_id = '$schoolIdSql'";
      final requestedScopeSql = entityType == 'school'
          ? "requested.tenant_id = '$tenantIdSql'"
          : "requested.tenant_id = '$tenantIdSql' AND requested.school_id = '$schoolIdSql'";
      final syncedStatusSql =
          _hasSyncStatus(entityType) ? ", sync_status = 'synced'" : "";

      if (requestedEntityId != canonicalEntityId) {
        final mergeColumns = _mergeColumnsForSyncEntity(entityType);
        final canonicalExists = (await customSelect(
              '''
            SELECT 1 AS present
            FROM $escapedTable existing
            WHERE existing.id = '$canonicalIdSql'
              AND $existingScopeSql
            LIMIT 1
          ''',
              readsFrom: {_tableForSyncEntity(entityType)!},
            ).getSingleOrNull()) !=
            null;
        if (mergeColumns.isNotEmpty) {
          if (canonicalExists) {
            await customStatement('''
              UPDATE $escapedTable
              SET deleted = 1
              WHERE id = '$requestedIdSql'
                AND $scopeSql
            ''');
          }
          final mergeAssignments = mergeColumns
              .map(
                (column) => "$column = (SELECT $column FROM $escapedTable"
                    " requested WHERE requested.id = '$requestedIdSql'"
                    " AND $requestedScopeSql)",
              )
              .join(', ');
          await customStatement('''
            UPDATE $escapedTable
            SET $mergeAssignments
            WHERE id = '$canonicalIdSql'
              AND $scopeSql
              AND EXISTS (
                SELECT 1
                FROM $escapedTable requested
                WHERE requested.id = '$requestedIdSql'
                  AND $requestedScopeSql
              )
          ''');
        }
        await customStatement('''
          UPDATE $escapedTable
          SET id = '$canonicalIdSql'
          WHERE id = '$requestedIdSql'
            AND $scopeSql
            AND NOT EXISTS (
              SELECT 1
              FROM $escapedTable existing
              WHERE existing.id = '$canonicalIdSql'
                AND $existingScopeSql
            )
        ''');
        await customStatement('''
          DELETE FROM $escapedTable
          WHERE id = '$requestedIdSql'
            AND $scopeSql
            AND EXISTS (
              SELECT 1
              FROM $escapedTable existing
              WHERE existing.id = '$canonicalIdSql'
                AND $existingScopeSql
            )
        ''');
      }

      final updatedRows = await customUpdate(
        '''
        UPDATE $escapedTable
        SET server_revision = $serverRevision$syncedStatusSql
        WHERE id = '$canonicalIdSql'
          AND $scopeSql
      ''',
        updates: {_tableForSyncEntity(entityType)!},
      );
      if (updatedRows == 0) {
        throw StateError(
          'Push acknowledgement for $entityType/$canonicalEntityId did not '
          'match any row in the active local scope.',
        );
      }

      await markQueueItemDone(queueItemId);
    });
  }

  TableInfo<Table, Object?>? _tableForSyncEntity(String entityType) {
    switch (entityType) {
      case 'student':
        return students;
      case 'guardian':
        return guardians;
      case 'enrollment':
        return enrollments;
      case 'staff':
        return staff;
      case 'staff_teaching_assignment':
        return staffTeachingAssignments;
      case 'applicant':
        return applicants;
      case 'attendance_record':
        return attendanceRecords;
      case 'academic_year':
        return academicYearsCache;
      case 'term':
        return termsCache;
      case 'class_level':
        return classLevelsCache;
      case 'class_arm':
        return classArmsCache;
      case 'subject':
        return subjectsCache;
      case 'school':
        return schoolProfileCache;
      case 'campus':
        return campusProfileCache;
      case 'grading_scheme':
        return gradingSchemesCache;
      case 'fee_category':
        return feeCategories;
      case 'fee_structure_item':
        return feeStructureItems;
      case 'invoice':
        return invoices;
      case 'payment':
        return payments;
      case 'payment_reversal':
        return paymentReversals;
      default:
        return null;
    }
  }

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

  Future<void> markQueueItemFailed(String id) =>
      (update(syncQueue)..where((t) => t.id.equals(id)))
          .write(const SyncQueueCompanion(status: Value('failed')));

  Future<void> resetQueueItemToPending(String id) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        const SyncQueueCompanion(
          status: Value('pending'),
          retryCount: Value(0),
        ),
      );

  Future<void> enqueueSyncChange({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return _insertSyncQueueItem(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  Future<int> getLastRevision(String entityType) async {
    final row = await (select(syncState)
          ..where((t) => t.entityType.equals(entityType)))
        .getSingleOrNull();
    return row?.lastServerRevision ?? 0;
  }

  Future<void> updateLastRevision(String entityType, int revision) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(
        entityType: Value(entityType),
        lastServerRevision: Value(revision),
        lastPulledAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<SyncStateData>> getAllSyncStates() {
    return (select(syncState)..orderBy([(t) => OrderingTerm.asc(t.entityType)]))
        .get();
  }

  Future<Map<String, int>> getSyncQueueCounts() async {
    final rows = await customSelect(
      '''
      SELECT status, COUNT(*) AS total
      FROM sync_queue
      GROUP BY status
      ''',
      readsFrom: {syncQueue},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('status'): row.read<int>('total'),
    };
  }

  Future<void> reconcileLocalScope({
    required LocalDataScope scope,
  }) async {
    final campusPredicate = scope.campusId == null || scope.campusId!.isEmpty
        ? ''
        : " OR campus_id <> '${_escapeSql(scope.campusId!)}'";
    final studentScopeSubquery = '''
      SELECT id
      FROM students
      WHERE tenant_id = '${_escapeSql(scope.tenantId)}'
        AND school_id = '${_escapeSql(scope.schoolId)}'
        ${scope.campusId == null || scope.campusId!.isEmpty ? '' : "AND campus_id = '${_escapeSql(scope.campusId!)}'"}
    ''';
    final staffScopeSubquery = '''
      SELECT id
      FROM staff
      WHERE tenant_id = '${_escapeSql(scope.tenantId)}'
        AND school_id = '${_escapeSql(scope.schoolId)}'
        ${scope.campusId == null || scope.campusId!.isEmpty ? '' : "AND campus_id = '${_escapeSql(scope.campusId!)}'"}
    ''';

    await transaction(() async {
      await customStatement('''
        DELETE FROM tenant_profile_cache
        WHERE id <> '${_escapeSql(scope.tenantId)}'
      ''');

      await customStatement('''
        DELETE FROM school_profile_cache
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR id <> '${_escapeSql(scope.schoolId)}'
      ''');

      for (final tableName in [
        'academic_years_cache',
        'terms_cache',
        'class_levels_cache',
        'class_arms_cache',
        'subjects_cache',
        'grading_schemes_cache',
        'fee_categories',
        'fee_structure_items',
      ]) {
        await customStatement('''
          DELETE FROM $tableName
          WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
             OR school_id <> '${_escapeSql(scope.schoolId)}'
        ''');
      }

      await customStatement('''
        DELETE FROM campus_profile_cache
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'
           ${scope.campusId == null || scope.campusId!.isEmpty ? '' : "OR id <> '${_escapeSql(scope.campusId!)}'"}
      ''');

      for (final tableName in [
        'students',
        'staff',
        'applicants',
        'attendance_records',
        'invoices',
        'payments',
        'payment_reversals'
      ]) {
        await customStatement('''
          DELETE FROM $tableName
          WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
             OR school_id <> '${_escapeSql(scope.schoolId)}'$campusPredicate
        ''');
      }

      await customStatement('''
        DELETE FROM guardians
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'
           OR student_id NOT IN ($studentScopeSubquery)
      ''');
      await customStatement('''
        DELETE FROM enrollments
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'
           OR student_id NOT IN ($studentScopeSubquery)
      ''');
      await customStatement('''
        DELETE FROM staff_teaching_assignments
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'
           OR staff_id NOT IN ($staffScopeSubquery)
      ''');
      await customStatement('''
        DELETE FROM sync_queue
        WHERE COALESCE(json_extract(payload_json, '\$.tenantId'), '') <> '${_escapeSql(scope.tenantId)}'
           OR COALESCE(json_extract(payload_json, '\$.schoolId'), '') <> '${_escapeSql(scope.schoolId)}'
           ${scope.campusId == null || scope.campusId!.isEmpty ? '' : """
           OR (
             entity_type IN ('student', 'staff', 'applicant', 'attendance_record', 'invoice', 'payment', 'payment_reversal')
             AND COALESCE(json_extract(payload_json, '\$.campusId'), '') <> '${_escapeSql(scope.campusId!)}'
           )
           """}
           OR (
             entity_type IN ('guardian', 'enrollment')
             AND COALESCE(json_extract(payload_json, '\$.studentId'), '') NOT IN ($studentScopeSubquery)
           )
           OR (
             entity_type = 'staff_teaching_assignment'
             AND COALESCE(json_extract(payload_json, '\$.staffId'), '') NOT IN ($staffScopeSubquery)
           )
      ''');
      await customStatement('''
        DELETE FROM sync_conflicts
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'$campusPredicate
      ''');
      await customStatement('''
        DELETE FROM sync_reconciliation_requests_cache
        WHERE tenant_id <> '${_escapeSql(scope.tenantId)}'
           OR school_id <> '${_escapeSql(scope.schoolId)}'$campusPredicate
      ''');

      await delete(syncState).go();
    });
  }

  Future<void> upsertReconciliationRequestCache(
    SyncReconciliationRequestsCacheCompanion value,
  ) =>
      into(syncReconciliationRequestsCache).insertOnConflictUpdate(value);

  Future<void> clearPendingReconciliationRequestForDevice({
    required LocalDataScope scope,
    required String targetDeviceId,
  }) async {
    await (delete(syncReconciliationRequestsCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _matchesNullableText(t.campusId, scope.campusId) &
              t.targetDeviceId.equals(targetDeviceId) &
              t.status.equals('pending')))
        .go();
  }

  Future<void> markReconciliationRequestApplied({
    required LocalDataScope scope,
    required String requestId,
    required String targetDeviceId,
    DateTime? acknowledgedAt,
  }) {
    return (update(syncReconciliationRequestsCache)
          ..where((t) =>
              t.id.equals(requestId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _matchesNullableText(t.campusId, scope.campusId) &
              t.targetDeviceId.equals(targetDeviceId)))
        .write(
      SyncReconciliationRequestsCacheCompanion(
        status: const Value('applied'),
        acknowledgedAt: Value(acknowledgedAt ?? DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<SyncReconciliationRequestsCacheData>>
      getRecentReconciliationRequests({
    required LocalDataScope scope,
    int limit = 10,
  }) {
    return (select(syncReconciliationRequestsCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope))
          ..orderBy([
            (t) => OrderingTerm.desc(t.requestedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> getPendingReconciliationRequestCount({
    required LocalDataScope scope,
  }) {
    final query = selectOnly(syncReconciliationRequestsCache)
      ..addColumns([syncReconciliationRequestsCache.id.count()])
      ..where(
        syncReconciliationRequestsCache.tenantId.equals(scope.tenantId) &
            syncReconciliationRequestsCache.schoolId.equals(scope.schoolId) &
            _campusScopeFilter(
                syncReconciliationRequestsCache.campusId, scope) &
            syncReconciliationRequestsCache.status.equals('pending'),
      );
    return query
        .map((row) => row.read(syncReconciliationRequestsCache.id.count()) ?? 0)
        .getSingle();
  }

  Future<List<SyncQueueData>> getRecentSyncQueueItems({int limit = 10}) {
    return (select(syncQueue)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getFailedSyncQueueItems({int limit = 20}) {
    return (select(syncQueue)
          ..where((t) => t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getRetryableFailedSyncQueueItems({
    int limit = 100,
  }) async {
    final conflictedQueueIds = await (select(syncConflicts)
          ..where((t) => t.status.equals('open') & t.queueItemId.isNotNull()))
        .map((row) => row.queueItemId!)
        .get();

    final query = select(syncQueue)..where((t) => t.status.equals('failed'));
    if (conflictedQueueIds.isNotEmpty) {
      query.where((t) => t.id.isNotIn(conflictedQueueIds));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return query.get();
  }

  Future<void> recordSyncConflict({
    required String? queueItemId,
    required String tenantId,
    required String schoolId,
    required String? campusId,
    required String entityType,
    required String entityId,
    required String operation,
    required String conflictType,
    required Map<String, dynamic> payload,
    String? serverMessage,
    Map<String, dynamic>? response,
  }) async {
    final existing = await (select(syncConflicts)
          ..where((t) {
            final queueFilter = queueItemId == null
                ? t.queueItemId.isNull()
                : t.queueItemId.equals(queueItemId);
            return queueFilter &
                t.tenantId.equals(tenantId) &
                t.schoolId.equals(schoolId) &
                _matchesNullableText(t.campusId, campusId) &
                t.entityType.equals(entityType) &
                t.entityId.equals(entityId) &
                t.conflictType.equals(conflictType) &
                t.status.equals('open');
          })
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (update(syncConflicts)..where((t) => t.id.equals(existing.id)))
          .write(
        SyncConflictsCompanion(
          payloadJson: Value(jsonEncode(payload)),
          serverMessage: Value(serverMessage),
          responseJson: Value(response == null ? null : jsonEncode(response)),
        ),
      );
      return;
    }

    await into(syncConflicts).insert(
      SyncConflictsCompanion.insert(
        id: _uuid.v4(),
        queueItemId: Value(queueItemId),
        tenantId: tenantId,
        schoolId: schoolId,
        campusId: Value(campusId),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        conflictType: conflictType,
        payloadJson: jsonEncode(payload),
        serverMessage: Value(serverMessage),
        responseJson: Value(response == null ? null : jsonEncode(response)),
      ),
    );
  }

  Future<bool> hasBlockingSyncStateForEntity({
    required String entityType,
    required String entityId,
  }) async {
    final queueItem = await (select(syncQueue)
          ..where((t) =>
              t.entityType.equals(entityType) &
              t.entityId.equals(entityId) &
              (t.status.equals('pending') |
                  t.status.equals('in_progress') |
                  t.status.equals('failed')))
          ..limit(1))
        .getSingleOrNull();
    if (queueItem != null) {
      return true;
    }

    final conflict = await (select(syncConflicts)
          ..where((t) =>
              t.entityType.equals(entityType) &
              t.entityId.equals(entityId) &
              t.conflictType.isNotValue('pull_deferred') &
              t.status.equals('open'))
          ..limit(1))
        .getSingleOrNull();
    return conflict != null;
  }

  Future<void> resolveOpenSyncConflictForEntity({
    required String tenantId,
    required String schoolId,
    required String? campusId,
    required String entityType,
    required String entityId,
    required String conflictType,
  }) {
    return (update(syncConflicts)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.schoolId.equals(schoolId) &
              _matchesNullableText(t.campusId, campusId) &
              t.entityType.equals(entityType) &
              t.entityId.equals(entityId) &
              t.conflictType.equals(conflictType) &
              t.status.equals('open')))
        .write(const SyncConflictsCompanion(status: Value('resolved')));
  }

  Future<List<SyncConflict>> getRecentSyncConflicts({
    required LocalDataScope scope,
    int limit = 12,
  }) {
    final query = select(syncConflicts)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.status.equals('open'))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return query.get();
  }

  Future<List<SyncConflict>> getOpenSyncConflicts({int limit = 20}) {
    return (select(syncConflicts)
          ..where((t) => t.status.equals('open'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<SyncConflict?> getOpenSyncConflictById({
    required LocalDataScope scope,
    required String conflictId,
  }) {
    return (select(syncConflicts)
          ..where((t) =>
              t.id.equals(conflictId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.status.equals('open'))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> getOpenSyncConflictCount({
    required LocalDataScope scope,
  }) {
    final query = selectOnly(syncConflicts)
      ..addColumns([syncConflicts.id.count()])
      ..where(
        syncConflicts.tenantId.equals(scope.tenantId) &
            syncConflicts.schoolId.equals(scope.schoolId) &
            _campusScopeFilter(syncConflicts.campusId, scope) &
            syncConflicts.status.equals('open'),
      );
    return query
        .map((row) => row.read(syncConflicts.id.count()) ?? 0)
        .getSingle();
  }

  Future<void> ignoreSyncConflict({
    required LocalDataScope scope,
    required String conflictId,
  }) {
    return (update(syncConflicts)
          ..where((t) =>
              t.id.equals(conflictId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.status.equals('open')))
        .write(const SyncConflictsCompanion(status: Value('ignored')));
  }

  Future<void> requeueSyncConflict({
    required LocalDataScope scope,
    required String conflictId,
  }) async {
    await transaction(() async {
      final conflict = await (select(syncConflicts)
            ..where((t) =>
                t.id.equals(conflictId) &
                t.tenantId.equals(scope.tenantId) &
                t.schoolId.equals(scope.schoolId) &
                _campusScopeFilter(t.campusId, scope) &
                t.status.equals('open'))
            ..limit(1))
          .getSingleOrNull();
      if (conflict == null) {
        return;
      }

      if (conflict.queueItemId != null) {
        await resetQueueItemToPending(conflict.queueItemId!);
      }

      await (update(syncConflicts)..where((t) => t.id.equals(conflict.id)))
          .write(
        const SyncConflictsCompanion(status: Value('requeued')),
      );
    });
  }

  Future<List<AcademicYearsCacheData>> getAcademicYears({
    required LocalDataScope scope,
  }) {
    return (select(academicYearsCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isCurrent),
            (t) => OrderingTerm.asc(t.startDate),
          ]))
        .get();
  }

  Future<void> upsertAcademicYear(AcademicYearsCacheCompanion value) =>
      into(academicYearsCache).insertOnConflictUpdate(value);

  Future<List<TermsCacheData>> getTerms({
    required LocalDataScope scope,
    String? academicYearId,
  }) {
    final query = select(termsCache)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          t.deleted.equals(false));
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.isCurrent),
      (t) => OrderingTerm.asc(t.termNumber),
    ]);
    return query.get();
  }

  Future<void> upsertTerm(TermsCacheCompanion value) =>
      into(termsCache).insertOnConflictUpdate(value);

  Future<TermsCacheData?> findTermById({
    required LocalDataScope scope,
    required String termId,
  }) {
    return (select(termsCache)
          ..where((t) =>
              t.id.equals(termId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<ClassLevelsCacheData>> getClassLevels({
    required LocalDataScope scope,
  }) {
    return (select(classLevelsCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<void> upsertClassLevel(ClassLevelsCacheCompanion value) =>
      into(classLevelsCache).insertOnConflictUpdate(value);

  Future<ClassLevelsCacheData?> findClassLevelById({
    required LocalDataScope scope,
    required String classLevelId,
  }) {
    return (select(classLevelsCache)
          ..where((t) =>
              t.id.equals(classLevelId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<ClassArmsCacheData>> getClassArms({
    required LocalDataScope scope,
    String? classLevelId,
  }) {
    final query = select(classArmsCache)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          t.deleted.equals(false));
    if (classLevelId != null) {
      query.where((t) => t.classLevelId.equals(classLevelId));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.displayName)]);
    return query.get();
  }

  Future<void> upsertClassArm(ClassArmsCacheCompanion value) =>
      into(classArmsCache).insertOnConflictUpdate(value);

  Future<ClassArmsCacheData?> findClassArmById({
    required LocalDataScope scope,
    required String classArmId,
  }) {
    return (select(classArmsCache)
          ..where((t) =>
              t.id.equals(classArmId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<SubjectsCacheData>> getSubjects({
    required LocalDataScope scope,
  }) {
    return (select(subjectsCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<void> upsertSubject(SubjectsCacheCompanion value) =>
      into(subjectsCache).insertOnConflictUpdate(value);

  Future<TenantProfileCacheData?> getTenantProfile({
    required String tenantId,
  }) {
    return (select(tenantProfileCache)
          ..where((t) => t.id.equals(tenantId) & t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertTenantProfile(TenantProfileCacheCompanion value) =>
      into(tenantProfileCache).insertOnConflictUpdate(value);

  Future<SchoolProfileCacheData?> getSchoolProfile({
    required String tenantId,
    required String schoolId,
  }) {
    return (select(schoolProfileCache)
          ..where((t) =>
              t.id.equals(schoolId) &
              t.tenantId.equals(tenantId) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertSchoolProfile(SchoolProfileCacheCompanion value) =>
      into(schoolProfileCache).insertOnConflictUpdate(value);

  Future<CampusProfileCacheData?> getCampusProfile({
    required LocalDataScope scope,
  }) {
    if (scope.campusId == null || scope.campusId!.isEmpty) {
      return Future.value(null);
    }

    return (select(campusProfileCache)
          ..where((t) =>
              t.id.equals(scope.campusId!) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertCampusProfile(CampusProfileCacheCompanion value) =>
      into(campusProfileCache).insertOnConflictUpdate(value);

  Future<List<GradingSchemesCacheData>> getGradingSchemes({
    required LocalDataScope scope,
  }) {
    return (select(gradingSchemesCache)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<GradingSchemesCacheData?> findGradingSchemeById({
    required LocalDataScope scope,
    required String gradingSchemeId,
  }) {
    return (select(gradingSchemesCache)
          ..where((t) =>
              t.id.equals(gradingSchemeId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertGradingScheme(GradingSchemesCacheCompanion value) =>
      into(gradingSchemesCache).insertOnConflictUpdate(value);

  Future<List<FeeCategory>> getFeeCategories({
    required LocalDataScope scope,
  }) {
    return (select(feeCategories)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isActive),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<FeeCategory?> findFeeCategoryById({
    required LocalDataScope scope,
    required String feeCategoryId,
  }) {
    return (select(feeCategories)
          ..where((t) =>
              t.id.equals(feeCategoryId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertFeeCategory(FeeCategoriesCompanion value) =>
      into(feeCategories).insertOnConflictUpdate(value);

  Future<List<FeeStructureItem>> getFeeStructureItems({
    required LocalDataScope scope,
  }) {
    return (select(feeStructureItems)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.feeCategoryId),
            (t) => OrderingTerm.asc(t.classLevelId),
            (t) => OrderingTerm.asc(t.termId),
            (t) => OrderingTerm.asc(t.amount),
          ]))
        .get();
  }

  Future<FeeStructureItem?> findFeeStructureItemById({
    required LocalDataScope scope,
    required String feeStructureItemId,
  }) {
    return (select(feeStructureItems)
          ..where((t) =>
              t.id.equals(feeStructureItemId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<FeeStructureItem?> findFeeStructureItemByRule({
    required LocalDataScope scope,
    required String feeCategoryId,
    String? classLevelId,
    String? termId,
    String? excludeId,
  }) {
    final query = select(feeStructureItems)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          t.feeCategoryId.equals(feeCategoryId) &
          _matchesNullableText(t.classLevelId, classLevelId) &
          _matchesNullableText(t.termId, termId) &
          t.deleted.equals(false));
    if (excludeId != null && excludeId.isNotEmpty) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    query.limit(1);
    return query.getSingleOrNull();
  }

  Future<void> upsertFeeStructureItem(FeeStructureItemsCompanion value) =>
      into(feeStructureItems).insertOnConflictUpdate(value);

  Future<List<Payment>> getPayments({
    required LocalDataScope scope,
    String? invoiceId,
  }) {
    final query = select(payments)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (invoiceId != null && invoiceId.isNotEmpty) {
      query.where((t) => t.invoiceId.equals(invoiceId));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.asc(t.paymentCode),
    ]);
    return query.get();
  }

  Future<Payment?> findPaymentById({
    required LocalDataScope scope,
    required String paymentId,
  }) {
    return (select(payments)
          ..where((t) =>
              t.id.equals(paymentId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertPayment(PaymentsCompanion value) =>
      into(payments).insertOnConflictUpdate(value);

  Future<List<PaymentReversal>> getPaymentReversals({
    required LocalDataScope scope,
    String? invoiceId,
    String? paymentId,
  }) {
    final query = select(paymentReversals)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (invoiceId != null && invoiceId.isNotEmpty) {
      query.where((t) => t.invoiceId.equals(invoiceId));
    }
    if (paymentId != null && paymentId.isNotEmpty) {
      query.where((t) => t.paymentId.equals(paymentId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<PaymentReversal?> findPaymentReversalByPaymentId({
    required LocalDataScope scope,
    required String paymentId,
  }) {
    return (select(paymentReversals)
          ..where((t) =>
              t.paymentId.equals(paymentId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertPaymentReversal(PaymentReversalsCompanion value) =>
      into(paymentReversals).insertOnConflictUpdate(value);

  Future<List<Invoice>> getInvoices({
    required LocalDataScope scope,
    String? termId,
    String? status,
  }) {
    final query = select(invoices)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (termId != null && termId.isNotEmpty) {
      query.where((t) => t.termId.equals(termId));
    }
    if (status != null && status.isNotEmpty) {
      query.where((t) => t.status.equals(status));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.asc(t.invoiceCode),
    ]);
    return query.get();
  }

  Future<Invoice?> findInvoiceById({
    required LocalDataScope scope,
    required String invoiceId,
  }) {
    return (select(invoices)
          ..where((t) =>
              t.id.equals(invoiceId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Invoice?> findInvoiceByStudentTerm({
    required LocalDataScope scope,
    required String studentId,
    required String termId,
  }) {
    return (select(invoices)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.studentId.equals(studentId) &
              t.termId.equals(termId) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertInvoice(InvoicesCompanion value) =>
      into(invoices).insertOnConflictUpdate(value);

  Future<List<Student>> getStudents({
    required LocalDataScope scope,
    String? search,
  }) {
    final q = select(students)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (search != null && search.isNotEmpty) {
      q.where((t) =>
          t.firstName.like('%$search%') |
          t.lastName.like('%$search%') |
          (t.studentNumber.isNotNull() & t.studentNumber.like('%$search%')));
    }
    return q.get();
  }

  Future<List<Student>> getStudentsForClassArm(
    String classArmId, {
    required LocalDataScope scope,
  }) async {
    final query = select(students).join([
      innerJoin(
        enrollments,
        enrollments.studentId.equalsExp(students.id) &
            enrollments.tenantId.equals(scope.tenantId) &
            enrollments.schoolId.equals(scope.schoolId) &
            enrollments.classArmId.equals(classArmId) &
            enrollments.deleted.equals(false),
      ),
    ])
      ..where(
        students.tenantId.equals(scope.tenantId) &
            students.schoolId.equals(scope.schoolId) &
            _campusScopeFilter(students.campusId, scope) &
            students.deleted.equals(false),
      );

    final rows = await query.get();
    final seenIds = <String>{};
    return rows
        .map((row) => row.readTable(students))
        .where((student) => seenIds.add(student.id))
        .toList(growable: false);
  }

  Future<void> upsertStudent(StudentsCompanion student) =>
      into(students).insertOnConflictUpdate(student);

  Future<Student?> findStudentById({
    required LocalDataScope scope,
    required String studentId,
  }) {
    return (select(students)
          ..where((t) =>
              t.id.equals(studentId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Guardian>> getGuardiansForStudent(
    String studentId, {
    required LocalDataScope scope,
  }) {
    return (select(guardians)
          ..where(
            (t) =>
                t.tenantId.equals(scope.tenantId) &
                t.schoolId.equals(scope.schoolId) &
                t.studentId.equals(studentId) &
                t.deleted.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPrimary),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<void> upsertGuardian(GuardiansCompanion guardian) =>
      into(guardians).insertOnConflictUpdate(guardian);

  Future<List<Enrollment>> getEnrollmentsForStudent(
    String studentId, {
    required LocalDataScope scope,
  }) {
    return (select(enrollments)
          ..where(
            (t) =>
                t.tenantId.equals(scope.tenantId) &
                t.schoolId.equals(scope.schoolId) &
                t.studentId.equals(studentId) &
                t.deleted.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .get();
  }

  Future<List<Enrollment>> getEnrollmentsForAcademicYear(
    String academicYearId, {
    required LocalDataScope scope,
  }) {
    return (select(enrollments)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.academicYearId.equals(academicYearId) &
              t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<Enrollment?> findEnrollment({
    required LocalDataScope scope,
    required String studentId,
    required String academicYearId,
  }) {
    return (select(enrollments)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.studentId.equals(studentId) &
              t.academicYearId.equals(academicYearId) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertEnrollment(EnrollmentsCompanion enrollment) =>
      into(enrollments).insertOnConflictUpdate(enrollment);

  Future<List<StaffData>> getAllStaff({
    required LocalDataScope scope,
    String? search,
  }) {
    final q = select(staff)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (search != null && search.isNotEmpty) {
      q.where(
          (t) => t.firstName.like('%$search%') | t.lastName.like('%$search%'));
    }
    return q.get();
  }

  Future<void> upsertStaff(StaffCompanion value) =>
      into(staff).insertOnConflictUpdate(value);

  Future<List<StaffTeachingAssignment>> getStaffAssignments(
    String staffId, {
    required LocalDataScope scope,
  }) {
    return (select(staffTeachingAssignments)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              t.staffId.equals(staffId) &
              t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.assignmentType)]))
        .get();
  }

  Future<void> upsertStaffAssignment(StaffTeachingAssignmentsCompanion value) =>
      into(staffTeachingAssignments).insertOnConflictUpdate(value);

  Future<List<Applicant>> getApplicants({
    required LocalDataScope scope,
    String? status,
  }) {
    final q = select(applicants)
      ..where((t) =>
          t.tenantId.equals(scope.tenantId) &
          t.schoolId.equals(scope.schoolId) &
          _campusScopeFilter(t.campusId, scope) &
          t.deleted.equals(false));
    if (status != null) {
      q.where((t) => t.status.equals(status));
    }
    return q.get();
  }

  Future<void> upsertApplicant(ApplicantsCompanion value) =>
      into(applicants).insertOnConflictUpdate(value);

  Future<Applicant?> findApplicantById({
    required LocalDataScope scope,
    required String applicantId,
  }) {
    return (select(applicants)
          ..where((t) =>
              t.id.equals(applicantId) &
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Applicant> updateApplicantLocally({
    required LocalDataScope scope,
    required String applicantId,
    required String firstName,
    required String? middleName,
    required String lastName,
    required String? dateOfBirth,
    required String? gender,
    required String? classLevelId,
    required String? academicYearId,
    required String? guardianName,
    required String? guardianPhone,
    required String? guardianEmail,
    required String? documentNotes,
  }) async {
    return transaction(() async {
      final applicant = await findApplicantById(
        scope: scope,
        applicantId: applicantId,
      );
      if (applicant == null) {
        throw StateError('Applicant not found in the active local scope.');
      }
      if (applicant.status == 'enrolled') {
        throw StateError('Enrolled applicants cannot be edited.');
      }

      final now = DateTime.now();
      final payload = {
        'id': applicant.id,
        'tenantId': applicant.tenantId,
        'schoolId': applicant.schoolId,
        'campusId': applicant.campusId,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'classLevelId': classLevelId,
        'academicYearId': academicYearId,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'guardianEmail': guardianEmail,
        'documentNotes': documentNotes,
        'status': applicant.status,
        'studentId': applicant.studentId,
        'admittedAt': applicant.admittedAt?.toIso8601String(),
        'baseServerRevision': applicant.serverRevision,
        'baseUpdatedAt': applicant.updatedAt.toIso8601String(),
      };

      await upsertApplicant(
        ApplicantsCompanion(
          id: Value(applicant.id),
          tenantId: Value(applicant.tenantId),
          schoolId: Value(applicant.schoolId),
          campusId: Value(applicant.campusId),
          firstName: Value(firstName),
          middleName: Value(middleName),
          lastName: Value(lastName),
          dateOfBirth: Value(dateOfBirth),
          gender: Value(gender),
          classLevelId: Value(classLevelId),
          academicYearId: Value(academicYearId),
          status: Value(applicant.status),
          guardianName: Value(guardianName),
          guardianPhone: Value(guardianPhone),
          guardianEmail: Value(guardianEmail),
          documentNotes: Value(documentNotes),
          studentId: Value(applicant.studentId),
          admittedAt: Value(applicant.admittedAt),
          syncStatus: const Value('local'),
          deleted: Value(applicant.deleted),
          createdAt: Value(applicant.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _insertSyncQueueItem(
        entityType: 'applicant',
        entityId: applicant.id,
        operation: 'update',
        payload: payload,
      );

      return (await findApplicantById(
        scope: scope,
        applicantId: applicantId,
      ))!;
    });
  }

  Future<LocalApplicantEnrollmentResult> enrollApplicantLocally({
    required LocalDataScope scope,
    required String applicantId,
    required String academicYearId,
    required String classArmId,
    required String enrollmentDate,
  }) async {
    return transaction(() async {
      final applicant = await findApplicantById(
        scope: scope,
        applicantId: applicantId,
      );
      if (applicant == null) {
        throw StateError('Applicant not found in the active local scope.');
      }
      if (applicant.status != 'admitted') {
        throw StateError('Applicant must be admitted before enrollment.');
      }
      if (applicant.studentId != null && applicant.studentId!.isNotEmpty) {
        throw StateError('Applicant is already linked to a student record.');
      }

      final academicYear = await (select(academicYearsCache)
            ..where((t) =>
                t.id.equals(academicYearId) &
                t.tenantId.equals(scope.tenantId) &
                t.schoolId.equals(scope.schoolId) &
                t.deleted.equals(false))
            ..limit(1))
          .getSingleOrNull();
      if (academicYear == null) {
        throw StateError('Academic year not found in the active local scope.');
      }

      final classArm = await (select(classArmsCache)
            ..where((t) =>
                t.id.equals(classArmId) &
                t.tenantId.equals(scope.tenantId) &
                t.schoolId.equals(scope.schoolId) &
                t.deleted.equals(false))
            ..limit(1))
          .getSingleOrNull();
      if (classArm == null) {
        throw StateError('Class arm not found in the active local scope.');
      }
      if (applicant.classLevelId != null &&
          applicant.classLevelId != classArm.classLevelId) {
        throw StateError(
          'Selected class arm does not match the applicant class level.',
        );
      }

      final studentId = _uuid.v4();
      final studentPayload = {
        'id': studentId,
        'tenantId': scope.tenantId,
        'schoolId': scope.schoolId,
        'campusId': applicant.campusId ?? scope.campusId,
        'studentNumber': null,
        'firstName': applicant.firstName,
        'middleName': applicant.middleName,
        'lastName': applicant.lastName,
        'dateOfBirth': applicant.dateOfBirth,
        'gender': applicant.gender,
        'status': 'active',
      };

      await upsertStudent(
        StudentsCompanion(
          id: Value(studentId),
          tenantId: Value(scope.tenantId),
          schoolId: Value(scope.schoolId),
          campusId: Value(applicant.campusId ?? scope.campusId),
          firstName: Value(applicant.firstName),
          middleName: Value(applicant.middleName),
          lastName: Value(applicant.lastName),
          studentNumber: const Value(null),
          dateOfBirth: Value(applicant.dateOfBirth),
          gender: Value(applicant.gender),
          status: const Value('active'),
          syncStatus: const Value('local'),
        ),
      );
      await _insertSyncQueueItem(
        entityType: 'student',
        entityId: studentId,
        operation: 'create',
        payload: studentPayload,
      );

      String? guardianId;
      final guardianName = _splitFullName(applicant.guardianName);
      if (guardianName != null) {
        guardianId = _uuid.v4();
        final guardianPayload = {
          'id': guardianId,
          'tenantId': scope.tenantId,
          'schoolId': scope.schoolId,
          'studentId': studentId,
          'firstName': guardianName.$1,
          'lastName': guardianName.$2,
          'relationship': 'guardian',
          'phone': applicant.guardianPhone,
          'email': applicant.guardianEmail,
          'isPrimary': true,
        };

        await upsertGuardian(
          GuardiansCompanion(
            id: Value(guardianId),
            tenantId: Value(scope.tenantId),
            schoolId: Value(scope.schoolId),
            studentId: Value(studentId),
            firstName: Value(guardianName.$1),
            lastName: Value(guardianName.$2),
            relationship: const Value('guardian'),
            phone: Value(applicant.guardianPhone),
            email: Value(applicant.guardianEmail),
            isPrimary: const Value(true),
          ),
        );
        await _insertSyncQueueItem(
          entityType: 'guardian',
          entityId: guardianId,
          operation: 'create',
          payload: guardianPayload,
        );
      }

      final enrollmentId = _uuid.v4();
      final enrollmentPayload = {
        'id': enrollmentId,
        'tenantId': scope.tenantId,
        'schoolId': scope.schoolId,
        'studentId': studentId,
        'classArmId': classArmId,
        'academicYearId': academicYearId,
        'enrollmentDate': enrollmentDate,
      };

      await upsertEnrollment(
        EnrollmentsCompanion(
          id: Value(enrollmentId),
          tenantId: Value(scope.tenantId),
          schoolId: Value(scope.schoolId),
          studentId: Value(studentId),
          classArmId: Value(classArmId),
          academicYearId: Value(academicYearId),
          enrollmentDate: Value(enrollmentDate),
        ),
      );
      await _insertSyncQueueItem(
        entityType: 'enrollment',
        entityId: enrollmentId,
        operation: 'create',
        payload: enrollmentPayload,
      );

      final admittedAt = applicant.admittedAt ?? DateTime.now();
      final applicantPayload = {
        'id': applicant.id,
        'tenantId': applicant.tenantId,
        'schoolId': applicant.schoolId,
        'campusId': applicant.campusId,
        'firstName': applicant.firstName,
        'middleName': applicant.middleName,
        'lastName': applicant.lastName,
        'dateOfBirth': applicant.dateOfBirth,
        'gender': applicant.gender,
        'classLevelId': applicant.classLevelId,
        'academicYearId': academicYearId,
        'guardianName': applicant.guardianName,
        'guardianPhone': applicant.guardianPhone,
        'guardianEmail': applicant.guardianEmail,
        'documentNotes': applicant.documentNotes,
        'status': 'enrolled',
        'studentId': studentId,
        'admittedAt': admittedAt.toIso8601String(),
        'baseServerRevision': applicant.serverRevision,
        'baseUpdatedAt': applicant.updatedAt.toIso8601String(),
      };

      await upsertApplicant(
        ApplicantsCompanion(
          id: Value(applicant.id),
          tenantId: Value(applicant.tenantId),
          schoolId: Value(applicant.schoolId),
          campusId: Value(applicant.campusId),
          firstName: Value(applicant.firstName),
          middleName: Value(applicant.middleName),
          lastName: Value(applicant.lastName),
          dateOfBirth: Value(applicant.dateOfBirth),
          gender: Value(applicant.gender),
          classLevelId: Value(applicant.classLevelId),
          academicYearId: Value(academicYearId),
          status: const Value('enrolled'),
          guardianName: Value(applicant.guardianName),
          guardianPhone: Value(applicant.guardianPhone),
          guardianEmail: Value(applicant.guardianEmail),
          documentNotes: Value(applicant.documentNotes),
          studentId: Value(studentId),
          admittedAt: Value(admittedAt),
          syncStatus: const Value('local'),
          deleted: Value(applicant.deleted),
          createdAt: Value(applicant.createdAt),
        ),
      );
      await _insertSyncQueueItem(
        entityType: 'applicant',
        entityId: applicant.id,
        operation: 'update',
        payload: applicantPayload,
      );

      return LocalApplicantEnrollmentResult(
        studentId: studentId,
        enrollmentId: enrollmentId,
        guardianId: guardianId,
      );
    });
  }

  Future<List<AttendanceRecord>> getAttendanceForClass({
    required LocalDataScope scope,
    required String classArmId,
    required String date,
  }) {
    return (select(attendanceRecords)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.classArmId.equals(classArmId) &
              t.attendanceDate.equals(date) &
              t.deleted.equals(false)))
        .get();
  }

  Future<List<AttendanceRecord>> getAttendanceForClassTerm({
    required LocalDataScope scope,
    required String classArmId,
    required String termId,
  }) {
    return (select(attendanceRecords)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.classArmId.equals(classArmId) &
              t.termId.equals(termId) &
              t.deleted.equals(false)))
        .get();
  }

  Future<AttendanceRecord?> findAttendanceRecord({
    required LocalDataScope scope,
    required String classArmId,
    required String studentId,
    required String date,
  }) {
    return (select(attendanceRecords)
          ..where((t) =>
              t.tenantId.equals(scope.tenantId) &
              t.schoolId.equals(scope.schoolId) &
              _campusScopeFilter(t.campusId, scope) &
              t.classArmId.equals(classArmId) &
              t.studentId.equals(studentId) &
              t.attendanceDate.equals(date) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> getScopedAttendanceRecordCount({
    required LocalDataScope scope,
  }) {
    final campusWhere = scope.campusId == null ? '' : ' AND campus_id = ?';
    return customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM attendance_records
      WHERE tenant_id = ?
        AND school_id = ?
        AND deleted = 0$campusWhere
      ''',
      variables: [
        Variable<String>(scope.tenantId),
        Variable<String>(scope.schoolId),
        if (scope.campusId != null) Variable<String>(scope.campusId!),
      ],
      readsFrom: {attendanceRecords},
    ).getSingle().then((row) => row.read<int>('total'));
  }

  Future<void> upsertAttendanceRecord(AttendanceRecordsCompanion value) =>
      into(attendanceRecords).insertOnConflictUpdate(value);

  Future<void> _insertSyncQueueItem({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await transaction(() async {
      final existing = await _findCompactableQueueItem(
        entityType: entityType,
        entityId: entityId,
      );
      if (existing != null) {
        final mergedOperation = _mergeQueuedOperation(
          existing.operation,
          operation,
        );
        if (mergedOperation == null) {
          await (delete(syncQueue)..where((t) => t.id.equals(existing.id)))
              .go();
          return;
        }

        await (update(syncQueue)..where((t) => t.id.equals(existing.id))).write(
          SyncQueueCompanion(
            operation: Value(mergedOperation),
            payloadJson: Value(jsonEncode(payload)),
            status: const Value('pending'),
            retryCount: const Value(0),
          ),
        );
        return;
      }

      final queueId = _uuid.v4();
      final lamportClock = await _nextLamportClock();
      await into(syncQueue).insert(
        SyncQueueCompanion.insert(
          id: queueId,
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payloadJson: jsonEncode(payload),
          idempotencyKey: '$entityType:$entityId:$queueId',
          lamportClock: Value(lamportClock),
        ),
      );
    });
  }

  Future<SyncQueueData?> _findCompactableQueueItem({
    required String entityType,
    required String entityId,
  }) async {
    final conflictedQueueIds = await (select(syncConflicts)
          ..where((t) => t.status.equals('open') & t.queueItemId.isNotNull()))
        .map((row) => row.queueItemId!)
        .get();

    final query = select(syncQueue)
      ..where((t) =>
          t.entityType.equals(entityType) &
          t.entityId.equals(entityId) &
          (t.status.equals('pending') | t.status.equals('failed')));
    if (conflictedQueueIds.isNotEmpty) {
      query.where((t) => t.id.isNotIn(conflictedQueueIds));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  String? _mergeQueuedOperation(
      String existingOperation, String nextOperation) {
    if (existingOperation == 'create' && nextOperation == 'update') {
      return 'create';
    }
    if (existingOperation == 'create' && nextOperation == 'delete') {
      return null;
    }
    if (existingOperation == 'update' && nextOperation == 'update') {
      return 'update';
    }
    if (existingOperation == 'update' && nextOperation == 'delete') {
      return 'delete';
    }
    if (existingOperation == 'delete' && nextOperation == 'create') {
      return 'update';
    }
    if (existingOperation == 'delete' && nextOperation == 'update') {
      return 'delete';
    }
    return nextOperation;
  }

  Future<int> _nextLamportClock() async {
    final row = await customSelect(
      '''
      SELECT COALESCE(MAX(lamport_clock), 0) AS max_clock
      FROM sync_queue
      ''',
      readsFrom: {syncQueue},
    ).getSingle();
    return row.read<int>('max_clock') + 1;
  }

  Future<void> _ensureOperationalUniqueIndexes() async {
    await transaction(() async {
      await customStatement('''
        DELETE FROM attendance_records
        WHERE id IN (
          SELECT older.id
          FROM attendance_records older
          JOIN attendance_records newer
            ON older.id <> newer.id
           AND older.deleted = 0
           AND newer.deleted = 0
           AND older.tenant_id = newer.tenant_id
           AND older.school_id = newer.school_id
           AND COALESCE(older.campus_id, '') = COALESCE(newer.campus_id, '')
           AND older.student_id = newer.student_id
           AND older.class_arm_id = newer.class_arm_id
           AND older.attendance_date = newer.attendance_date
           AND (
             older.updated_at < newer.updated_at OR
             (older.updated_at = newer.updated_at AND older.created_at < newer.created_at) OR
             (older.updated_at = newer.updated_at AND older.created_at = newer.created_at AND older.id < newer.id)
           )
        )
      ''');
      await customStatement('''
        DELETE FROM enrollments
        WHERE id IN (
          SELECT older.id
          FROM enrollments older
          JOIN enrollments newer
            ON older.id <> newer.id
           AND older.deleted = 0
           AND newer.deleted = 0
           AND older.tenant_id = newer.tenant_id
           AND older.school_id = newer.school_id
           AND older.student_id = newer.student_id
           AND older.academic_year_id = newer.academic_year_id
           AND (
             older.created_at < newer.created_at OR
             (older.created_at = newer.created_at AND older.id < newer.id)
           )
        )
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_local_attendance_natural_unique
        ON attendance_records(
          tenant_id,
          school_id,
          COALESCE(campus_id, ''),
          student_id,
          class_arm_id,
          attendance_date
        )
        WHERE deleted = 0
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_local_enrollment_student_year_unique
        ON enrollments(
          tenant_id,
          school_id,
          student_id,
          academic_year_id
        )
        WHERE deleted = 0
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_local_invoices_student_term_unique
        ON invoices(
          tenant_id,
          school_id,
          student_id,
          term_id
        )
        WHERE deleted = 0
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_local_payment_reversals_payment_unique
        ON payment_reversals(
          tenant_id,
          school_id,
          payment_id
        )
        WHERE deleted = 0
      ''');
    });
  }
}

Expression<bool> _campusScopeFilter(
  GeneratedColumn<String> campusColumn,
  LocalDataScope scope,
) {
  if (scope.campusId == null || scope.campusId!.isEmpty) {
    return const Constant(true);
  }
  return campusColumn.equals(scope.campusId!);
}

Expression<bool> _matchesNullableText(
  GeneratedColumn<String> column,
  String? value,
) {
  if (value == null || value.isEmpty) {
    return column.isNull();
  }
  return column.equals(value);
}

String _escapeSql(String value) => value.replaceAll("'", "''");

String? _tableNameForSyncEntity(String entityType) {
  switch (entityType) {
    case 'student':
      return 'students';
    case 'guardian':
      return 'guardians';
    case 'enrollment':
      return 'enrollments';
    case 'staff':
      return 'staff';
    case 'staff_teaching_assignment':
      return 'staff_teaching_assignments';
    case 'applicant':
      return 'applicants';
    case 'attendance_record':
      return 'attendance_records';
    case 'academic_year':
      return 'academic_years_cache';
    case 'term':
      return 'terms_cache';
    case 'class_level':
      return 'class_levels_cache';
    case 'class_arm':
      return 'class_arms_cache';
    case 'subject':
      return 'subjects_cache';
    case 'school':
      return 'school_profile_cache';
    case 'campus':
      return 'campus_profile_cache';
    case 'grading_scheme':
      return 'grading_schemes_cache';
    case 'fee_category':
      return 'fee_categories';
    case 'fee_structure_item':
      return 'fee_structure_items';
    case 'invoice':
      return 'invoices';
    case 'payment':
      return 'payments';
    case 'payment_reversal':
      return 'payment_reversals';
    default:
      return null;
  }
}

bool _hasSyncStatus(String entityType) {
  return {
    'student',
    'staff',
    'applicant',
    'attendance_record',
    'invoice',
    'payment',
    'payment_reversal',
  }.contains(entityType);
}

List<String> _mergeColumnsForSyncEntity(String entityType) {
  switch (entityType) {
    case 'staff_teaching_assignment':
      return const [
        'staff_id',
        'assignment_type',
        'subject_id',
        'class_arm_id',
        'updated_at',
      ];
    case 'enrollment':
      return const [
        'student_id',
        'class_arm_id',
        'academic_year_id',
        'enrollment_date',
      ];
    case 'attendance_record':
      return const [
        'campus_id',
        'student_id',
        'class_arm_id',
        'academic_year_id',
        'term_id',
        'attendance_date',
        'status',
        'notes',
        'recorded_by_user_id',
        'updated_at',
      ];
    case 'fee_structure_item':
      return const [
        'fee_category_id',
        'class_level_id',
        'term_id',
        'amount',
        'notes',
        'updated_at',
      ];
    case 'invoice':
      return const [
        'campus_id',
        'student_id',
        'academic_year_id',
        'term_id',
        'class_arm_id',
        'invoice_code',
        'status',
        'line_items_json',
        'total_amount',
        'generated_by_user_id',
        'posted_at',
        'updated_at',
      ];
    case 'payment':
      return const [
        'campus_id',
        'invoice_id',
        'payment_code',
        'status',
        'amount',
        'payment_mode',
        'payment_date',
        'reference',
        'notes',
        'received_by_user_id',
        'posted_at',
        'updated_at',
      ];
    case 'payment_reversal':
      return const [
        'campus_id',
        'payment_id',
        'invoice_id',
        'amount',
        'reason',
        'reversed_by_user_id',
        'updated_at',
      ];
    default:
      return const [];
  }
}

(String, String)? _splitFullName(String? fullName) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return (parts.first, 'Guardian');
  }
  return (parts.first, parts.sublist(1).join(' '));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationSupportDirectory();
    final file = File(p.join(dbDir.path, 'offline_school.db'));
    return NativeDatabase.createInBackground(file);
  });
}
