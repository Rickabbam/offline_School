import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/attendance/attendance_capture_service.dart';

void main() {
  late AppDatabase db;
  late AttendanceCaptureService service;
  const user = AuthUser(
    id: 'teacher-1',
    email: 'teacher@example.com',
    fullName: 'Teacher One',
    role: 'teacher',
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );
  const scope = LocalDataScope(
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    service = AttendanceCaptureService();

    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: Value(scope.campusId),
        firstName: 'Ama',
        lastName: 'Mensah',
      ),
    );
    await db.upsertEnrollment(
      EnrollmentsCompanion.insert(
        id: 'enrollment-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        studentId: 'student-1',
        classArmId: 'arm-1',
        academicYearId: 'year-1',
        enrollmentDate: '2026-04-24',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('offline attendance create stores local row and queues create mutation',
      () async {
    final student = (await db.getStudentsForClassArm('arm-1', scope: scope)).single;

    await service.markAttendance(
      db: db,
      user: user,
      student: student,
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      date: DateTime.utc(2026, 4, 24),
      status: 'present',
    );

    final record = await db.findAttendanceRecord(
      scope: scope,
      classArmId: 'arm-1',
      studentId: 'student-1',
      date: '2026-04-24',
    );
    final queue = await db.select(db.syncQueue).get();

    expect(record, isNotNull);
    expect(record!.status, 'present');
    expect(queue.single.operation, 'create');
  });

  test('offline attendance update carries base revision metadata', () async {
    final updatedAt = DateTime.parse('2026-04-24T09:00:00.000Z');
    await db.upsertAttendanceRecord(
      AttendanceRecordsCompanion(
        id: const Value('attendance-1'),
        tenantId: Value(scope.tenantId),
        schoolId: Value(scope.schoolId),
        campusId: Value(scope.campusId),
        studentId: const Value('student-1'),
        classArmId: const Value('arm-1'),
        academicYearId: const Value('year-1'),
        termId: const Value('term-1'),
        attendanceDate: const Value('2026-04-24'),
        status: const Value('absent'),
        serverRevision: const Value(14),
        updatedAt: Value(updatedAt),
      ),
    );

    final student = (await db.getStudentsForClassArm('arm-1', scope: scope)).single;
    await service.markAttendance(
      db: db,
      user: user,
      student: student,
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      date: DateTime.utc(2026, 4, 24),
      status: 'late',
    );

    final queue = await db.select(db.syncQueue).get();
    final payload = jsonDecode(queue.single.payloadJson) as Map<String, dynamic>;

    expect(queue.single.operation, 'update');
    expect(payload['baseServerRevision'], 14);
    expect(
      DateTime.parse('${payload['baseUpdatedAt']}').toUtc(),
      updatedAt.toUtc(),
    );
  });
}
