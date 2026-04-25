import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnlineAuthService extends AuthService {
  _OnlineAuthService(this._dio) : super(backendBaseUrl: 'http://localhost:3000');

  final Dio _dio;

  @override
  AuthUser? get currentUser => const AuthUser(
        id: 'teacher-1',
        email: 'teacher@example.com',
        fullName: 'Teacher User',
        role: 'teacher',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      );

  @override
  bool get isOfflineSession => false;

  @override
  bool get isAuthenticated => true;

  @override
  Dio createAuthenticatedClient() => _dio;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'defers pulled attendance when matching local natural-key work is pending under a different id',
      () async {
    final updatedAt = DateTime.parse('2026-04-24T09:00:00.000Z');
    await db.upsertAttendanceRecord(
      AttendanceRecordsCompanion(
        id: const Value('device-attendance-1'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        studentId: const Value('student-1'),
        classArmId: const Value('arm-1'),
        academicYearId: const Value('year-1'),
        termId: const Value('term-1'),
        attendanceDate: const Value('2026-04-24'),
        status: const Value('late'),
        recordedByUserId: const Value('teacher-1'),
        updatedAt: Value(updatedAt),
      ),
    );
    await db.enqueueSyncChange(
      entityType: 'attendance_record',
      entityId: 'device-attendance-1',
      operation: 'update',
      payload: {
        'id': 'device-attendance-1',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'campusId': 'campus-1',
        'studentId': 'student-1',
        'classArmId': 'arm-1',
        'academicYearId': 'year-1',
        'termId': 'term-1',
        'attendanceDate': '2026-04-24',
        'status': 'late',
        'recordedByUserId': 'teacher-1',
        'baseUpdatedAt': updatedAt.toIso8601String(),
      },
    );

    final service = SyncService(
      db: db,
      auth: _OnlineAuthService(Dio()),
    );

    final blockingEntityId = await service.findBlockingLocalEntityIdForPull(
      entityType: 'attendance_record',
      record: <String, dynamic>{
        'id': 'server-attendance-1',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'campusId': 'campus-1',
        'studentId': 'student-1',
        'classArmId': 'arm-1',
        'academicYearId': 'year-1',
        'termId': 'term-1',
        'attendanceDate': '2026-04-24',
        'status': 'present',
      },
    );

    expect(blockingEntityId, 'device-attendance-1');
  });
}
