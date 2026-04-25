import 'dart:convert';

import 'package:desktop_app/database/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  const scope = LocalDataScope(
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();

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
    await db.upsertClassLevel(
      ClassLevelsCacheCompanion.insert(
        id: 'level-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        name: 'Basic 1',
        sortOrder: const Value(1),
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

  test('offline applicant enrollment creates student, guardian, enrollment, and applicant sync changes',
      () async {
    await db.upsertApplicant(
      ApplicantsCompanion.insert(
        id: 'app-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        classLevelId: const Value('level-1'),
        academicYearId: const Value('year-1'),
        status: const Value('admitted'),
        guardianName: const Value('Kojo Mensah'),
        guardianPhone: const Value('0200000000'),
        guardianEmail: const Value('guardian@example.com'),
        documentNotes: const Value('Birth certificate seen'),
        admittedAt: Value(DateTime.utc(2026, 4, 20)),
        syncStatus: const Value('local'),
        serverRevision: const Value(7),
      ),
    );

    final result = await db.enrollApplicantLocally(
      scope: scope,
      applicantId: 'app-1',
      academicYearId: 'year-1',
      classArmId: 'arm-1',
      enrollmentDate: '2026-04-23',
    );

    final student = await db.findStudentById(
      scope: scope,
      studentId: result.studentId,
    );
    final guardians = await db.getGuardiansForStudent(
      result.studentId,
      scope: scope,
    );
    final enrollments = await db.getEnrollmentsForStudent(
      result.studentId,
      scope: scope,
    );
    final applicant = await db.findApplicantById(
      scope: scope,
      applicantId: 'app-1',
    );
    final queue = await db.select(db.syncQueue).get();

    expect(student, isNotNull);
    expect(student!.firstName, 'Ama');
    expect(guardians, hasLength(1));
    expect(guardians.single.firstName, 'Kojo');
    expect(enrollments, hasLength(1));
    expect(enrollments.single.classArmId, 'arm-1');
    expect(applicant, isNotNull);
    expect(applicant!.status, 'enrolled');
    expect(applicant.studentId, result.studentId);
    expect(queue.map((item) => item.entityType).toList(),
        ['student', 'guardian', 'enrollment', 'applicant']);

    final applicantPayload = jsonDecode(
      queue.firstWhere((item) => item.entityType == 'applicant').payloadJson,
    ) as Map<String, dynamic>;
    expect(applicantPayload['status'], 'enrolled');
    expect(applicantPayload['studentId'], result.studentId);
    expect(applicantPayload['baseServerRevision'], 7);
  });

  test('offline applicant enrollment rejects class arm outside applicant class level',
      () async {
    await db.upsertClassArm(
      ClassArmsCacheCompanion.insert(
        id: 'arm-2',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        classLevelId: 'level-2',
        arm: 'A',
        displayName: 'Basic 2A',
      ),
    );
    await db.upsertApplicant(
      ApplicantsCompanion.insert(
        id: 'app-2',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Efua',
        lastName: 'Owusu',
        classLevelId: const Value('level-1'),
        status: const Value('admitted'),
      ),
    );

    await expectLater(
      () => db.enrollApplicantLocally(
        scope: scope,
        applicantId: 'app-2',
        academicYearId: 'year-1',
        classArmId: 'arm-2',
        enrollmentDate: '2026-04-23',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Selected class arm does not match the applicant class level.',
        ),
      ),
    );

    expect(await db.select(db.students).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('offline applicant edit updates local row and queues a replay-safe update',
      () async {
    final createdAt = DateTime.utc(2026, 4, 20, 12);
    await db.upsertApplicant(
      ApplicantsCompanion.insert(
        id: 'app-3',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Ama',
        lastName: 'Mensah',
        classLevelId: const Value('level-1'),
        academicYearId: const Value('year-1'),
        guardianName: const Value('Kojo Mensah'),
        guardianPhone: const Value('0200000000'),
        guardianEmail: const Value('guardian@example.com'),
        documentNotes: const Value('Initial note'),
        status: const Value('admitted'),
        admittedAt: Value(DateTime.utc(2026, 4, 20)),
        syncStatus: const Value('synced'),
        serverRevision: const Value(9),
        createdAt: Value(createdAt),
        updatedAt: Value(createdAt),
      ),
    );

    final updated = await db.updateApplicantLocally(
      scope: scope,
      applicantId: 'app-3',
      firstName: 'Ama',
      middleName: 'Serwaa',
      lastName: 'Mensah',
      dateOfBirth: '2012-01-12',
      gender: 'female',
      classLevelId: 'level-1',
      academicYearId: 'year-1',
      guardianName: 'Kojo Mensah',
      guardianPhone: '0240000000',
      guardianEmail: 'newguardian@example.com',
      documentNotes: 'Updated note',
    );

    final queue = await db.select(db.syncQueue).get();
    final payload = jsonDecode(queue.single.payloadJson) as Map<String, dynamic>;

    expect(updated.middleName, 'Serwaa');
    expect(updated.guardianPhone, '0240000000');
    expect(updated.documentNotes, 'Updated note');
    expect(updated.status, 'admitted');
    expect(queue.single.entityType, 'applicant');
    expect(queue.single.operation, 'update');
    expect(payload['baseServerRevision'], 9);
    expect(payload['status'], 'admitted');
    expect(payload['middleName'], 'Serwaa');
    expect(payload['guardianPhone'], '0240000000');
  });
}
