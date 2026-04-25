import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/students/student_editor_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StudentEditorService service;
  const user = AuthUser(
    id: 'user-1',
    email: 'admin@example.com',
    fullName: 'Admin User',
    role: 'admin',
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
    service = StudentEditorService();

    await db.upsertAcademicYear(
      AcademicYearsCacheCompanion.insert(
        id: 'year-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        label: '2026/2027',
        startDate: '2026-09-01',
        endDate: '2027-07-31',
        isCurrent: const Value(true),
      ),
    );
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        classLevelId: 'level-1',
        arm: 'A',
        displayName: 'Basic 1A',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('creates offline student, guardian, and enrollment queue records',
      () async {
    await service.saveStudent(
      db: db,
      user: user,
      input: const StudentEditorInput(
        firstName: 'Ama',
        middleName: '',
        lastName: 'Mensah',
        studentNumber: 'ST-001',
        dateOfBirth: '2014-05-20',
        gender: 'female',
        status: 'active',
        guardianFirstName: 'Kojo',
        guardianLastName: 'Mensah',
        guardianPhone: '0200000000',
        guardianEmail: 'guardian@example.com',
        guardianRelationship: 'father',
        academicYearId: 'year-1',
        classArmId: 'arm-1',
        guardianId: null,
        currentEnrollmentId: null,
      ),
    );

    final students = await db.select(db.students).get();
    final guardians = await db.select(db.guardians).get();
    final enrollments = await db.select(db.enrollments).get();
    final queueItems = await db.select(db.syncQueue).get();

    expect(students, hasLength(1));
    expect(guardians, hasLength(1));
    expect(enrollments, hasLength(1));
    expect(queueItems.map((item) => item.entityType).toList(),
        ['student', 'guardian', 'enrollment']);
  });

  test('clearing guardian and enrollment soft deletes them and queues deletes',
      () async {
    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('synced'),
        serverRevision: const Value(8),
      ),
    );
    await db.upsertGuardian(
      GuardiansCompanion.insert(
        id: 'guardian-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        studentId: 'student-1',
        firstName: 'Kojo',
        lastName: 'Mensah',
        relationship: const Value('father'),
        isPrimary: const Value(true),
        serverRevision: const Value(9),
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
        enrollmentDate: '2026-09-02',
        serverRevision: const Value(10),
      ),
    );
    final existing = await db.findStudentById(
      scope: scope,
      studentId: 'student-1',
    );

    await service.saveStudent(
      db: db,
      user: user,
      existing: existing!,
      input: const StudentEditorInput(
        firstName: 'Ama',
        middleName: '',
        lastName: 'Mensah',
        studentNumber: '',
        dateOfBirth: '',
        gender: null,
        status: 'active',
        guardianFirstName: '',
        guardianLastName: '',
        guardianPhone: '',
        guardianEmail: '',
        guardianRelationship: 'guardian',
        academicYearId: null,
        classArmId: null,
        guardianId: 'guardian-1',
        currentEnrollmentId: 'enrollment-1',
      ),
    );

    final guardians = await db.select(db.guardians).get();
    final enrollments = await db.select(db.enrollments).get();
    final queueItems = await db.select(db.syncQueue).get();
    final guardianDelete = queueItems.firstWhere(
      (item) => item.entityType == 'guardian',
    );
    final enrollmentDelete = queueItems.firstWhere(
      (item) => item.entityType == 'enrollment',
    );

    expect(guardians.single.deleted, isTrue);
    expect(enrollments.single.deleted, isTrue);
    expect(guardianDelete.operation, 'delete');
    expect(enrollmentDelete.operation, 'delete');

    final guardianPayload =
        jsonDecode(guardianDelete.payloadJson) as Map<String, dynamic>;
    final enrollmentPayload =
        jsonDecode(enrollmentDelete.payloadJson) as Map<String, dynamic>;

    expect(guardianPayload['baseServerRevision'], 9);
    expect(enrollmentPayload['baseServerRevision'], 10);
  });

  test('rejects partial enrollment selection before writing local state', () async {
    await expectLater(
      () => service.saveStudent(
        db: db,
        user: user,
        input: const StudentEditorInput(
          firstName: 'Ama',
          middleName: '',
          lastName: 'Mensah',
          studentNumber: '',
          dateOfBirth: '',
          gender: null,
          status: 'active',
          guardianFirstName: '',
          guardianLastName: '',
          guardianPhone: '',
          guardianEmail: '',
          guardianRelationship: 'guardian',
          academicYearId: 'year-1',
          classArmId: null,
          guardianId: null,
          currentEnrollmentId: null,
        ),
      ),
      throwsA(
        isA<StudentEditorValidationException>().having(
          (error) => error.message,
          'message',
          'Academic year and class arm must both be selected together.',
        ),
      ),
    );

    expect(await db.select(db.students).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('deletes student locally and cascades guardian and enrollment deletes', () async {
    await db.upsertStudent(
      StudentsCompanion.insert(
        id: 'student-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        status: const Value('active'),
        syncStatus: const Value('synced'),
        serverRevision: const Value(8),
      ),
    );
    await db.upsertGuardian(
      GuardiansCompanion.insert(
        id: 'guardian-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        studentId: 'student-1',
        firstName: 'Kojo',
        lastName: 'Mensah',
        relationship: const Value('father'),
        isPrimary: const Value(true),
        serverRevision: const Value(9),
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
        enrollmentDate: '2026-09-02',
        serverRevision: const Value(10),
      ),
    );

    final existing = await db.findStudentById(
      scope: scope,
      studentId: 'student-1',
    );

    await service.deleteStudent(
      db: db,
      user: user,
      existing: existing!,
    );

    final student = await db.findStudentById(
      scope: const LocalDataScope(
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: null,
      ),
      studentId: 'student-1',
    );
    final guardians = await db.select(db.guardians).get();
    final enrollments = await db.select(db.enrollments).get();
    final queueItems = await db.select(db.syncQueue).get();

    expect(student?.deleted, isTrue);
    expect(student?.syncStatus, 'local');
    expect(guardians.single.deleted, isTrue);
    expect(enrollments.single.deleted, isTrue);
    expect(
      queueItems.map((item) => '${item.entityType}:${item.operation}').toList(),
      ['student:delete', 'guardian:delete', 'enrollment:delete'],
    );
  });
}
