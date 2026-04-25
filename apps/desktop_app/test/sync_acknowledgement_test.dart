import 'dart:convert';

import 'package:desktop_app/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
  });

  tearDown(() async {
    await db.close();
  });

  test('applies canonical push acknowledgement in one local transaction',
      () async {
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'device-enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-04-23',
      ),
    );
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-1',
            entityType: 'enrollment',
            entityId: 'device-enrollment-1',
            operation: 'create',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'studentId': 'student-1',
              'classArmId': 'arm-1',
              'academicYearId': 'year-1',
              'enrollmentDate': '2026-04-23',
            }),
            idempotencyKey: 'enrollment:device-enrollment-1:queue-1',
            status: const Value('in_progress'),
          ),
        );

    await db.applyPushAcknowledgement(
      queueItemId: 'queue-1',
      entityType: 'enrollment',
      requestedEntityId: 'device-enrollment-1',
      canonicalEntityId: 'server-enrollment-1',
      serverRevision: 77,
      tenantId: 'tenant-1',
      schoolId: 'school-1',
    );

    final enrollments = await db.select(db.enrollments).get();
    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-1')))
        .getSingle();

    expect(enrollments, hasLength(1));
    expect(enrollments.single.id, 'server-enrollment-1');
    expect(enrollments.single.serverRevision, 77);
    expect(queueItem.status, 'done');
  });

  test('does not complete queue when acknowledgement misses local scope',
      () async {
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-2',
            entityType: 'enrollment',
            entityId: 'missing-enrollment',
            operation: 'create',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'studentId': 'student-1',
              'classArmId': 'arm-1',
              'academicYearId': 'year-1',
              'enrollmentDate': '2026-04-23',
            }),
            idempotencyKey: 'enrollment:missing-enrollment:queue-2',
            status: const Value('in_progress'),
          ),
        );

    await expectLater(
      db.applyPushAcknowledgement(
        queueItemId: 'queue-2',
        entityType: 'enrollment',
        requestedEntityId: 'missing-enrollment',
        canonicalEntityId: 'server-enrollment-2',
        serverRevision: 78,
        tenantId: 'tenant-1',
        schoolId: 'school-1',
      ),
      throwsStateError,
    );

    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-2')))
        .getSingle();
    expect(queueItem.status, 'in_progress');
  });

  test('merges canonical enrollment acknowledgement onto the existing row',
      () async {
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_local_enrollment_student_year_unique',
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'server-enrollment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-old',
        academicYearId: 'year-1',
        enrollmentDate: '2026-04-01',
        serverRevision: const Value(12),
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'device-enrollment-2',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        studentId: 'student-1',
        classArmId: 'arm-new',
        academicYearId: 'year-1',
        enrollmentDate: '2026-04-23',
      ),
    );
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-3',
            entityType: 'enrollment',
            entityId: 'device-enrollment-2',
            operation: 'create',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'studentId': 'student-1',
              'classArmId': 'arm-new',
              'academicYearId': 'year-1',
              'enrollmentDate': '2026-04-23',
            }),
            idempotencyKey: 'enrollment:device-enrollment-2:queue-3',
            status: const Value('in_progress'),
          ),
        );

    await db.applyPushAcknowledgement(
      queueItemId: 'queue-3',
      entityType: 'enrollment',
      requestedEntityId: 'device-enrollment-2',
      canonicalEntityId: 'server-enrollment-1',
      serverRevision: 79,
      tenantId: 'tenant-1',
      schoolId: 'school-1',
    );

    final enrollments = await db.select(db.enrollments).get();
    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-3')))
        .getSingle();

    expect(enrollments, hasLength(1));
    expect(enrollments.single.id, 'server-enrollment-1');
    expect(enrollments.single.classArmId, 'arm-new');
    expect(enrollments.single.enrollmentDate, '2026-04-23');
    expect(enrollments.single.serverRevision, 79);
    expect(queueItem.status, 'done');
  });

  test('merges canonical attendance acknowledgement onto the existing row',
      () async {
    final localUpdatedAt = DateTime.parse('2026-04-23T08:30:00.000Z');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_local_attendance_natural_unique',
    );

    await db.upsertAttendanceRecord(
      AttendanceRecordsCompanion.insert(
        id: 'server-attendance-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: const Value('campus-1'),
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        termId: 'term-1',
        attendanceDate: '2026-04-23',
        status: const Value('absent'),
        notes: const Value('Old note'),
        recordedByUserId: const Value('teacher-old'),
        serverRevision: const Value(33),
      ),
    );
    await db.upsertAttendanceRecord(
      AttendanceRecordsCompanion(
        id: const Value('device-attendance-2'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        studentId: const Value('student-1'),
        classArmId: const Value('arm-1'),
        academicYearId: const Value('year-1'),
        termId: const Value('term-1'),
        attendanceDate: const Value('2026-04-23'),
        status: const Value('present'),
        notes: const Value('Late arrival cleared'),
        recordedByUserId: const Value('teacher-new'),
        updatedAt: Value(localUpdatedAt),
      ),
    );
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-4',
            entityType: 'attendance_record',
            entityId: 'device-attendance-2',
            operation: 'create',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'campusId': 'campus-1',
              'studentId': 'student-1',
              'classArmId': 'arm-1',
              'academicYearId': 'year-1',
              'termId': 'term-1',
              'attendanceDate': '2026-04-23',
              'status': 'present',
              'notes': 'Late arrival cleared',
              'recordedByUserId': 'teacher-new',
            }),
            idempotencyKey: 'attendance_record:device-attendance-2:queue-4',
            status: const Value('in_progress'),
          ),
        );

    await db.applyPushAcknowledgement(
      queueItemId: 'queue-4',
      entityType: 'attendance_record',
      requestedEntityId: 'device-attendance-2',
      canonicalEntityId: 'server-attendance-1',
      serverRevision: 88,
      tenantId: 'tenant-1',
      schoolId: 'school-1',
    );

    final records = await db.select(db.attendanceRecords).get();
    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-4')))
        .getSingle();

    expect(records, hasLength(1));
    expect(records.single.id, 'server-attendance-1');
    expect(records.single.status, 'present');
    expect(records.single.notes, 'Late arrival cleared');
    expect(records.single.recordedByUserId, 'teacher-new');
    expect(records.single.updatedAt.toUtc(), localUpdatedAt.toUtc());
    expect(records.single.serverRevision, 88);
    expect(records.single.syncStatus, 'synced');
    expect(queueItem.status, 'done');
  });

  test(
      'merges canonical staff teaching assignment acknowledgement onto the existing row',
      () async {
    final localUpdatedAt = DateTime.utc(2026, 4, 23, 12, 45);
    await db.customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_local_staff_assignment_subject_unique
      ON staff_teaching_assignments(
        tenant_id,
        school_id,
        staff_id,
        assignment_type,
        subject_id
      )
      WHERE deleted = 0
        AND assignment_type = 'subject_teacher'
        AND subject_id IS NOT NULL
    ''');
    await db.upsertStaffAssignment(
      StaffTeachingAssignmentsCompanion.insert(
        id: 'server-assignment-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        staffId: 'staff-1',
        assignmentType: 'subject_teacher',
        subjectId: const Value('subject-old'),
        classArmId: const Value(null),
        serverRevision: const Value(76),
      ),
    );
    await db.upsertStaffAssignment(
      StaffTeachingAssignmentsCompanion(
        id: const Value('device-assignment-2'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        staffId: const Value('staff-1'),
        assignmentType: const Value('subject_teacher'),
        subjectId: const Value('subject-new'),
        classArmId: const Value(null),
        createdAt: Value(localUpdatedAt),
        updatedAt: Value(localUpdatedAt),
      ),
    );
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-5',
            entityType: 'staff_teaching_assignment',
            entityId: 'device-assignment-2',
            operation: 'create',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'staffId': 'staff-1',
              'assignmentType': 'subject_teacher',
              'subjectId': 'subject-new',
              'classArmId': null,
            }),
            idempotencyKey:
                'staff_teaching_assignment:device-assignment-2:queue-5',
            status: const Value('in_progress'),
          ),
        );

    await db.applyPushAcknowledgement(
      queueItemId: 'queue-5',
      entityType: 'staff_teaching_assignment',
      requestedEntityId: 'device-assignment-2',
      canonicalEntityId: 'server-assignment-1',
      serverRevision: 91,
      tenantId: 'tenant-1',
      schoolId: 'school-1',
    );

    final assignments = await db.select(db.staffTeachingAssignments).get();
    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-5')))
        .getSingle();

    expect(assignments, hasLength(1));
    expect(assignments.single.id, 'server-assignment-1');
    expect(assignments.single.staffId, 'staff-1');
    expect(assignments.single.assignmentType, 'subject_teacher');
    expect(assignments.single.subjectId, 'subject-new');
    expect(assignments.single.updatedAt.toUtc(), localUpdatedAt.toUtc());
    expect(assignments.single.serverRevision, 91);
    expect(queueItem.status, 'done');
  });
}
