import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';

class StudentEditorValidationException implements Exception {
  const StudentEditorValidationException(this.message);

  final String message;
}

class StudentEditorInput {
  const StudentEditorInput({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.studentNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.status,
    required this.guardianFirstName,
    required this.guardianLastName,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.guardianRelationship,
    required this.academicYearId,
    required this.classArmId,
    required this.guardianId,
    required this.currentEnrollmentId,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String studentNumber;
  final String dateOfBirth;
  final String? gender;
  final String status;
  final String guardianFirstName;
  final String guardianLastName;
  final String guardianPhone;
  final String guardianEmail;
  final String guardianRelationship;
  final String? academicYearId;
  final String? classArmId;
  final String? guardianId;
  final String? currentEnrollmentId;
}

class StudentEditorService {
  StudentEditorService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<void> saveStudent({
    required AppDatabase db,
    required AuthUser user,
    required StudentEditorInput input,
    Student? existing,
  }) async {
    if (user.tenantId == null || user.schoolId == null) {
      throw const StudentEditorValidationException(
        'Missing tenant or school scope.',
      );
    }

    final hasGuardianName = input.guardianFirstName.trim().isNotEmpty ||
        input.guardianLastName.trim().isNotEmpty;
    if (hasGuardianName &&
        (input.guardianFirstName.trim().isEmpty ||
            input.guardianLastName.trim().isEmpty)) {
      throw const StudentEditorValidationException(
        'Guardian first and last name are both required.',
      );
    }

    final hasAcademicYear = input.academicYearId != null;
    final hasClassArm = input.classArmId != null;
    if (hasAcademicYear != hasClassArm) {
      throw const StudentEditorValidationException(
        'Academic year and class arm must both be selected together.',
      );
    }

    final isNew = existing == null;
    final studentId = isNew ? _uuid.v4() : existing.id;
    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );

    await db.transaction(() async {
      await db.upsertStudent(
        StudentsCompanion(
          id: Value(studentId),
          tenantId: Value(scope.tenantId),
          schoolId: Value(scope.schoolId),
          campusId: Value(scope.campusId),
          firstName: Value(input.firstName.trim()),
          middleName: Value(_nullIfBlank(input.middleName)),
          lastName: Value(input.lastName.trim()),
          studentNumber: Value(_nullIfBlank(input.studentNumber)),
          dateOfBirth: Value(_nullIfBlank(input.dateOfBirth)),
          gender: Value(input.gender),
          status: Value(input.status),
          syncStatus: const Value('local'),
        ),
      );

      await db.enqueueSyncChange(
        entityType: 'student',
        entityId: studentId,
        operation: isNew ? 'create' : 'update',
        payload: {
          'id': studentId,
          'tenantId': scope.tenantId,
          'schoolId': scope.schoolId,
          'campusId': scope.campusId,
          'studentNumber': _nullIfBlank(input.studentNumber),
          'firstName': input.firstName.trim(),
          'middleName': _nullIfBlank(input.middleName),
          'lastName': input.lastName.trim(),
          'dateOfBirth': _nullIfBlank(input.dateOfBirth),
          'gender': input.gender,
          'status': input.status,
          if (!isNew) ...{
            'baseServerRevision': existing.serverRevision,
            'baseUpdatedAt': existing.updatedAt.toIso8601String(),
          },
        },
      );

      final existingGuardians = await db.getGuardiansForStudent(
        studentId,
        scope: scope,
      );
      final activeGuardian = input.guardianId == null
          ? existingGuardians.firstOrNull
          : existingGuardians
                  .where((guardian) => guardian.id == input.guardianId)
                  .firstOrNull ??
              existingGuardians.firstOrNull;

      if (hasGuardianName) {
        final guardianId = activeGuardian?.id ?? input.guardianId ?? _uuid.v4();
        await db.upsertGuardian(
          GuardiansCompanion(
            id: Value(guardianId),
            tenantId: Value(scope.tenantId),
            schoolId: Value(scope.schoolId),
            studentId: Value(studentId),
            firstName: Value(input.guardianFirstName.trim()),
            lastName: Value(input.guardianLastName.trim()),
            relationship: Value(input.guardianRelationship),
            phone: Value(_nullIfBlank(input.guardianPhone)),
            email: Value(_nullIfBlank(input.guardianEmail)),
            isPrimary: const Value(true),
            deleted: const Value(false),
            createdAt: activeGuardian == null
                ? const Value.absent()
                : Value(activeGuardian.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'guardian',
          entityId: guardianId,
          operation: activeGuardian == null ? 'create' : 'update',
          payload: {
            'id': guardianId,
            'tenantId': scope.tenantId,
            'schoolId': scope.schoolId,
            'studentId': studentId,
            'firstName': input.guardianFirstName.trim(),
            'lastName': input.guardianLastName.trim(),
            'relationship': input.guardianRelationship,
            'phone': _nullIfBlank(input.guardianPhone),
            'email': _nullIfBlank(input.guardianEmail),
            'isPrimary': true,
            if (activeGuardian != null)
              'baseServerRevision': activeGuardian.serverRevision,
          },
        );
      } else if (activeGuardian != null) {
        await db.upsertGuardian(
          GuardiansCompanion(
            id: Value(activeGuardian.id),
            tenantId: Value(activeGuardian.tenantId),
            schoolId: Value(activeGuardian.schoolId),
            studentId: Value(activeGuardian.studentId),
            firstName: Value(activeGuardian.firstName),
            lastName: Value(activeGuardian.lastName),
            relationship: Value(activeGuardian.relationship),
            phone: Value(activeGuardian.phone),
            email: Value(activeGuardian.email),
            isPrimary: Value(activeGuardian.isPrimary),
            deleted: const Value(true),
            createdAt: Value(activeGuardian.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'guardian',
          entityId: activeGuardian.id,
          operation: 'delete',
          payload: {
            'id': activeGuardian.id,
            'tenantId': activeGuardian.tenantId,
            'schoolId': activeGuardian.schoolId,
            'studentId': activeGuardian.studentId,
            'baseServerRevision': activeGuardian.serverRevision,
          },
        );
      }

      final existingEnrollments = await db.getEnrollmentsForStudent(
        studentId,
        scope: scope,
      );
      final currentEnrollment = input.currentEnrollmentId == null
          ? existingEnrollments.firstOrNull
          : existingEnrollments
                  .where((enrollment) => enrollment.id == input.currentEnrollmentId)
                  .firstOrNull ??
              existingEnrollments.firstOrNull;

      if (input.academicYearId != null && input.classArmId != null) {
        final existingEnrollment = await db.findEnrollment(
          scope: scope,
          studentId: studentId,
          academicYearId: input.academicYearId!,
        );
        final enrollmentId = existingEnrollment?.id ?? _uuid.v4();
        final enrollmentDate =
            existingEnrollment?.enrollmentDate ?? _todayIso();
        await db.upsertEnrollment(
          EnrollmentsCompanion(
            id: Value(enrollmentId),
            tenantId: Value(scope.tenantId),
            schoolId: Value(scope.schoolId),
            studentId: Value(studentId),
            classArmId: Value(input.classArmId!),
            academicYearId: Value(input.academicYearId!),
            enrollmentDate: Value(enrollmentDate),
            deleted: const Value(false),
            createdAt: existingEnrollment == null
                ? const Value.absent()
                : Value(existingEnrollment.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'enrollment',
          entityId: enrollmentId,
          operation: existingEnrollment == null ? 'create' : 'update',
          payload: {
            'id': enrollmentId,
            'tenantId': scope.tenantId,
            'schoolId': scope.schoolId,
            'studentId': studentId,
            'classArmId': input.classArmId,
            'academicYearId': input.academicYearId,
            'enrollmentDate': enrollmentDate,
            if (existingEnrollment != null)
              'baseServerRevision': existingEnrollment.serverRevision,
          },
        );
      } else if (currentEnrollment != null) {
        await db.upsertEnrollment(
          EnrollmentsCompanion(
            id: Value(currentEnrollment.id),
            tenantId: Value(currentEnrollment.tenantId),
            schoolId: Value(currentEnrollment.schoolId),
            studentId: Value(currentEnrollment.studentId),
            classArmId: Value(currentEnrollment.classArmId),
            academicYearId: Value(currentEnrollment.academicYearId),
            enrollmentDate: Value(currentEnrollment.enrollmentDate),
            deleted: const Value(true),
            createdAt: Value(currentEnrollment.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'enrollment',
          entityId: currentEnrollment.id,
          operation: 'delete',
          payload: {
            'id': currentEnrollment.id,
            'tenantId': currentEnrollment.tenantId,
            'schoolId': currentEnrollment.schoolId,
            'studentId': currentEnrollment.studentId,
            'classArmId': currentEnrollment.classArmId,
            'academicYearId': currentEnrollment.academicYearId,
            'enrollmentDate': currentEnrollment.enrollmentDate,
            'baseServerRevision': currentEnrollment.serverRevision,
          },
        );
      }
    });
  }

  Future<void> deleteStudent({
    required AppDatabase db,
    required AuthUser user,
    required Student existing,
  }) async {
    if (user.tenantId == null || user.schoolId == null) {
      throw const StudentEditorValidationException(
        'Missing tenant or school scope.',
      );
    }

    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );

    await db.transaction(() async {
      await db.upsertStudent(
        StudentsCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          campusId: Value(existing.campusId),
          firstName: Value(existing.firstName),
          middleName: Value(existing.middleName),
          lastName: Value(existing.lastName),
          studentNumber: Value(existing.studentNumber),
          dateOfBirth: Value(existing.dateOfBirth),
          gender: Value(existing.gender),
          status: Value(existing.status),
          syncStatus: const Value('local'),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
        ),
      );
      await db.enqueueSyncChange(
        entityType: 'student',
        entityId: existing.id,
        operation: 'delete',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'campusId': existing.campusId,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );

      final guardians = await db.getGuardiansForStudent(existing.id, scope: scope);
      for (final guardian in guardians) {
        await db.upsertGuardian(
          GuardiansCompanion(
            id: Value(guardian.id),
            tenantId: Value(guardian.tenantId),
            schoolId: Value(guardian.schoolId),
            studentId: Value(guardian.studentId),
            firstName: Value(guardian.firstName),
            lastName: Value(guardian.lastName),
            relationship: Value(guardian.relationship),
            phone: Value(guardian.phone),
            email: Value(guardian.email),
            isPrimary: Value(guardian.isPrimary),
            deleted: const Value(true),
            createdAt: Value(guardian.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'guardian',
          entityId: guardian.id,
          operation: 'delete',
          payload: {
            'id': guardian.id,
            'tenantId': guardian.tenantId,
            'schoolId': guardian.schoolId,
            'studentId': guardian.studentId,
            'baseServerRevision': guardian.serverRevision,
          },
        );
      }

      final enrollments = await db.getEnrollmentsForStudent(
        existing.id,
        scope: scope,
      );
      for (final enrollment in enrollments) {
        await db.upsertEnrollment(
          EnrollmentsCompanion(
            id: Value(enrollment.id),
            tenantId: Value(enrollment.tenantId),
            schoolId: Value(enrollment.schoolId),
            studentId: Value(enrollment.studentId),
            classArmId: Value(enrollment.classArmId),
            academicYearId: Value(enrollment.academicYearId),
            enrollmentDate: Value(enrollment.enrollmentDate),
            deleted: const Value(true),
            createdAt: Value(enrollment.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'enrollment',
          entityId: enrollment.id,
          operation: 'delete',
          payload: {
            'id': enrollment.id,
            'tenantId': enrollment.tenantId,
            'schoolId': enrollment.schoolId,
            'studentId': enrollment.studentId,
            'classArmId': enrollment.classArmId,
            'academicYearId': enrollment.academicYearId,
            'enrollmentDate': enrollment.enrollmentDate,
            'baseServerRevision': enrollment.serverRevision,
          },
        );
      }
    });
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
