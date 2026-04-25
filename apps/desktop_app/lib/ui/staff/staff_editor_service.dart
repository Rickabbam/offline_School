import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';

class StaffEditorValidationException implements Exception {
  const StaffEditorValidationException(this.message);

  final String message;
}

class StaffEditorInput {
  const StaffEditorInput({
    required this.staffNumber,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.phone,
    required this.email,
    required this.department,
    required this.systemRole,
    required this.employmentType,
    required this.dateJoined,
    required this.isActive,
    required this.classTeacherClassArmId,
    required this.subjectIds,
  });

  final String staffNumber;
  final String firstName;
  final String middleName;
  final String lastName;
  final String? gender;
  final String phone;
  final String email;
  final String department;
  final String systemRole;
  final String employmentType;
  final String dateJoined;
  final bool isActive;
  final String? classTeacherClassArmId;
  final Set<String> subjectIds;
}

class StaffEditorService {
  StaffEditorService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<void> saveStaff({
    required AppDatabase db,
    required AuthUser user,
    required StaffEditorInput input,
    StaffData? existing,
  }) async {
    if (user.tenantId == null || user.schoolId == null) {
      throw const StaffEditorValidationException(
        'Missing tenant or school scope.',
      );
    }

    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final isNew = existing == null;
    final id = existing?.id ?? _uuid.v4();

    await db.transaction(() async {
      await db.upsertStaff(
        StaffCompanion(
          id: Value(id),
          tenantId: Value(scope.tenantId),
          schoolId: Value(scope.schoolId),
          campusId: Value(scope.campusId),
          staffNumber: Value(_nullIfBlank(input.staffNumber)),
          firstName: Value(input.firstName.trim()),
          middleName: Value(_nullIfBlank(input.middleName)),
          lastName: Value(input.lastName.trim()),
          gender: Value(input.gender),
          phone: Value(_nullIfBlank(input.phone)),
          email: Value(_nullIfBlank(input.email)),
          department: Value(_nullIfBlank(input.department)),
          systemRole: Value(input.systemRole),
          employmentType: Value(input.employmentType),
          dateJoined: Value(_nullIfBlank(input.dateJoined)),
          isActive: Value(input.isActive),
          syncStatus: const Value('local'),
        ),
      );

      await db.enqueueSyncChange(
        entityType: 'staff',
        entityId: id,
        operation: isNew ? 'create' : 'update',
        payload: {
          'id': id,
          'tenantId': scope.tenantId,
          'schoolId': scope.schoolId,
          'campusId': scope.campusId,
          'staffNumber': _nullIfBlank(input.staffNumber),
          'firstName': input.firstName.trim(),
          'middleName': _nullIfBlank(input.middleName),
          'lastName': input.lastName.trim(),
          'gender': input.gender,
          'phone': _nullIfBlank(input.phone),
          'email': _nullIfBlank(input.email),
          'department': _nullIfBlank(input.department),
          'systemRole': input.systemRole,
          'employmentType': input.employmentType,
          'dateJoined': _nullIfBlank(input.dateJoined),
          'isActive': input.isActive,
          if (!isNew) ...{
            'baseServerRevision': existing.serverRevision,
            'baseUpdatedAt': existing.updatedAt.toIso8601String(),
          },
        },
      );

      await _syncAssignments(
        db,
        scope: scope,
        staffId: id,
        classTeacherClassArmId: input.classTeacherClassArmId,
        subjectIds: input.subjectIds,
      );
    });
  }

  Future<void> deleteStaff({
    required AppDatabase db,
    required AuthUser user,
    required StaffData existing,
  }) async {
    if (user.tenantId == null || user.schoolId == null) {
      throw const StaffEditorValidationException(
        'Missing tenant or school scope.',
      );
    }

    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );

    await db.transaction(() async {
      await db.upsertStaff(
        StaffCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          campusId: Value(existing.campusId),
          userId: Value(existing.userId),
          staffNumber: Value(existing.staffNumber),
          firstName: Value(existing.firstName),
          middleName: Value(existing.middleName),
          lastName: Value(existing.lastName),
          gender: Value(existing.gender),
          phone: Value(existing.phone),
          email: Value(existing.email),
          department: Value(existing.department),
          systemRole: Value(existing.systemRole),
          employmentType: Value(existing.employmentType),
          dateJoined: Value(existing.dateJoined),
          isActive: Value(existing.isActive),
          syncStatus: const Value('local'),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
        ),
      );
      await db.enqueueSyncChange(
        entityType: 'staff',
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

      final assignments = await db.getStaffAssignments(existing.id, scope: scope);
      for (final assignment in assignments) {
        await db.upsertStaffAssignment(
          StaffTeachingAssignmentsCompanion(
            id: Value(assignment.id),
            tenantId: Value(assignment.tenantId),
            schoolId: Value(assignment.schoolId),
            staffId: Value(assignment.staffId),
            assignmentType: Value(assignment.assignmentType),
            subjectId: Value(assignment.subjectId),
            classArmId: Value(assignment.classArmId),
            deleted: const Value(true),
            createdAt: Value(assignment.createdAt),
          ),
        );
        await db.enqueueSyncChange(
          entityType: 'staff_teaching_assignment',
          entityId: assignment.id,
          operation: 'delete',
          payload: {
            'id': assignment.id,
            'tenantId': assignment.tenantId,
            'schoolId': assignment.schoolId,
            'staffId': assignment.staffId,
            'assignmentType': assignment.assignmentType,
            'subjectId': assignment.subjectId,
            'classArmId': assignment.classArmId,
            'baseServerRevision': assignment.serverRevision,
            'baseUpdatedAt': assignment.updatedAt.toIso8601String(),
          },
        );
      }
    });
  }

  Future<void> _syncAssignments(
    AppDatabase db, {
    required LocalDataScope scope,
    required String staffId,
    required String? classTeacherClassArmId,
    required Set<String> subjectIds,
  }) async {
    final existingAssignments = await db.getStaffAssignments(staffId, scope: scope);

    final desiredKeys = <String>{};
    if (classTeacherClassArmId != null) {
      desiredKeys.add('class_teacher:$classTeacherClassArmId');
    }
    for (final subjectId in subjectIds) {
      desiredKeys.add('subject_teacher:$subjectId');
    }

    for (final assignment in existingAssignments) {
      final key = assignment.assignmentType == 'class_teacher'
          ? 'class_teacher:${assignment.classArmId}'
          : 'subject_teacher:${assignment.subjectId}';
      if (desiredKeys.contains(key)) {
        continue;
      }
      await db.upsertStaffAssignment(
        StaffTeachingAssignmentsCompanion(
          id: Value(assignment.id),
          tenantId: Value(assignment.tenantId),
          schoolId: Value(assignment.schoolId),
          staffId: Value(assignment.staffId),
          assignmentType: Value(assignment.assignmentType),
          subjectId: Value(assignment.subjectId),
          classArmId: Value(assignment.classArmId),
          deleted: const Value(true),
          createdAt: Value(assignment.createdAt),
        ),
      );
      await db.enqueueSyncChange(
        entityType: 'staff_teaching_assignment',
        entityId: assignment.id,
        operation: 'delete',
        payload: {
          'id': assignment.id,
          'tenantId': assignment.tenantId,
          'schoolId': assignment.schoolId,
          'staffId': assignment.staffId,
          'assignmentType': assignment.assignmentType,
          'subjectId': assignment.subjectId,
          'classArmId': assignment.classArmId,
          'baseServerRevision': assignment.serverRevision,
          'baseUpdatedAt': assignment.updatedAt.toIso8601String(),
        },
      );
    }

    Future<void> ensureAssignment({
      required String assignmentType,
      String? subjectId,
      String? classArmId,
    }) async {
      final existing =
          existingAssignments.cast<StaffTeachingAssignment?>().firstWhere(
                (item) =>
                    item != null &&
                    item.assignmentType == assignmentType &&
                    item.subjectId == subjectId &&
                    item.classArmId == classArmId &&
                    !item.deleted,
                orElse: () => null,
              );
      final assignmentId = existing?.id ?? _uuid.v4();
      await db.upsertStaffAssignment(
        StaffTeachingAssignmentsCompanion(
          id: Value(assignmentId),
          tenantId: Value(scope.tenantId),
          schoolId: Value(scope.schoolId),
          staffId: Value(staffId),
          assignmentType: Value(assignmentType),
          subjectId: Value(subjectId),
          classArmId: Value(classArmId),
          deleted: const Value(false),
          createdAt: existing == null
              ? const Value.absent()
              : Value(existing.createdAt),
        ),
      );
      await db.enqueueSyncChange(
        entityType: 'staff_teaching_assignment',
        entityId: assignmentId,
        operation: existing == null ? 'create' : 'update',
        payload: {
          'id': assignmentId,
          'tenantId': scope.tenantId,
          'schoolId': scope.schoolId,
          'staffId': staffId,
          'assignmentType': assignmentType,
          'subjectId': subjectId,
          'classArmId': classArmId,
          if (existing != null) ...{
            'baseServerRevision': existing.serverRevision,
            'baseUpdatedAt': existing.updatedAt.toIso8601String(),
          },
        },
      );
    }

    if (classTeacherClassArmId != null) {
      await ensureAssignment(
        assignmentType: 'class_teacher',
        classArmId: classTeacherClassArmId,
      );
    }
    for (final subjectId in subjectIds) {
      await ensureAssignment(
        assignmentType: 'subject_teacher',
        subjectId: subjectId,
      );
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
