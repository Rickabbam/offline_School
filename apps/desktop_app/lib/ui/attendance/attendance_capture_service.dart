import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';

class AttendanceCaptureService {
  AttendanceCaptureService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<void> markAttendance({
    required AppDatabase db,
    required AuthUser user,
    required Student student,
    required String classArmId,
    required String academicYearId,
    required String termId,
    required DateTime date,
    required String status,
    String? notes,
  }) async {
    if (user.tenantId == null || user.schoolId == null) {
      throw StateError('Missing tenant or school scope.');
    }

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final existing = await db.findAttendanceRecord(
      scope: scope,
      classArmId: classArmId,
      studentId: student.id,
      date: dateStr,
    );
    final attendanceId = existing?.id ?? _uuid.v4();

    await db.transaction(() async {
      await db.upsertAttendanceRecord(
        AttendanceRecordsCompanion(
          id: Value(attendanceId),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          campusId: Value(user.campusId),
          studentId: Value(student.id),
          classArmId: Value(classArmId),
          academicYearId: Value(academicYearId),
          termId: Value(termId),
          attendanceDate: Value(dateStr),
          status: Value(status),
          notes: Value(notes),
          recordedByUserId: Value(user.id),
          syncStatus: const Value('local'),
        ),
      );

      await db.enqueueSyncChange(
        entityType: 'attendance_record',
        entityId: attendanceId,
        operation: existing == null ? 'create' : 'update',
        payload: {
          'id': attendanceId,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'campusId': user.campusId,
          'studentId': student.id,
          'classArmId': classArmId,
          'academicYearId': academicYearId,
          'termId': termId,
          'attendanceDate': dateStr,
          'status': status,
          'notes': notes,
          'recordedByUserId': user.id,
          if (existing != null) ...{
            'baseServerRevision': existing.serverRevision,
            'baseUpdatedAt': existing.updatedAt.toIso8601String(),
          },
        },
      );
    });
  }
}
