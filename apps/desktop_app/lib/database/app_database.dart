import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/sync_queue.dart';
import 'tables/sync_state.dart';
import 'tables/students.dart';
import 'tables/staff.dart';
import 'tables/applicants.dart';
import 'tables/attendance_records.dart';

part 'app_database.g.dart';

/// The main local SQLite database for the desktop app.
///
/// Schema version history:
///   1 — Phase A baseline: sync_queue + sync_state tables.
///   2 — Phase B: students, guardians, enrollments, staff, applicants,
///                attendance_records tables.
@DriftDatabase(tables: [
  SyncQueue,
  SyncState,
  Students,
  Guardians,
  Enrollments,
  Staff,
  Applicants,
  AttendanceRecords,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Called from main() to ensure all migrations have run before the UI loads.
  Future<void> runMigrations() async {
    await executor.ensureOpen(this);
  }

  // ─── SyncQueue queries ─────────────────────────────────────────────────────

  Future<List<SyncQueueData>> getPendingQueueItems() =>
      (select(syncQueue)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> markQueueItemDone(String id) => (update(syncQueue)
        ..where((t) => t.id.equals(id)))
      .write(const SyncQueueCompanion(status: Value('done')));

  Future<void> incrementQueueRetry(String id) async {
    final item =
        await (select(syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return;
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        status: const Value('pending'),
      ),
    );
  }

  Future<void> markQueueItemFailed(String id) => (update(syncQueue)
        ..where((t) => t.id.equals(id)))
      .write(const SyncQueueCompanion(status: Value('failed')));

  // ─── SyncState queries ─────────────────────────────────────────────────────

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

  // ─── Student queries ──────────────────────────────────────────────────────

  Future<List<StudentData>> getStudents({String? search}) {
    final q = select(students)..where((t) => t.deleted.equals(false));
    if (search != null && search.isNotEmpty) {
      q.where((t) =>
          t.firstName.like('%$search%') |
          t.lastName.like('%$search%') |
          (t.studentNumber.isNotNull() & t.studentNumber.like('%$search%')));
    }
    return q.get();
  }

  Future<void> upsertStudent(StudentsCompanion student) =>
      into(students).insertOnConflictUpdate(student);

  // ─── Staff queries ────────────────────────────────────────────────────────

  Future<List<StaffData>> getAllStaff({String? search}) {
    final q = select(staff)..where((t) => t.deleted.equals(false));
    if (search != null && search.isNotEmpty) {
      q.where((t) =>
          t.firstName.like('%$search%') | t.lastName.like('%$search%'));
    }
    return q.get();
  }

  Future<void> upsertStaff(StaffCompanion s) =>
      into(staff).insertOnConflictUpdate(s);

  // ─── Applicant queries ────────────────────────────────────────────────────

  Future<List<ApplicantData>> getApplicants({String? status}) {
    final q = select(applicants)..where((t) => t.deleted.equals(false));
    if (status != null) {
      q.where((t) => t.status.equals(status));
    }
    return q.get();
  }

  Future<void> upsertApplicant(ApplicantsCompanion a) =>
      into(applicants).insertOnConflictUpdate(a);

  // ─── Attendance queries ───────────────────────────────────────────────────

  Future<List<AttendanceRecordData>> getAttendanceForClass({
    required String classArmId,
    required String date,
  }) {
    return (select(attendanceRecords)
          ..where((t) =>
              t.classArmId.equals(classArmId) &
              t.attendanceDate.equals(date) &
              t.deleted.equals(false)))
        .get();
  }

  Future<void> upsertAttendanceRecord(AttendanceRecordsCompanion r) =>
      into(attendanceRecords).insertOnConflictUpdate(r);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationSupportDirectory();
    final file = File(p.join(dbDir.path, 'offline_school.db'));
    return NativeDatabase.createInBackground(file);
  });
}
