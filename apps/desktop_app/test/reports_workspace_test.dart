import 'dart:io';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/backup/backup_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:desktop_app/ui/reports/reports_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReportsAuthService extends AuthService {
  _ReportsAuthService(this._user)
      : super(backendBaseUrl: 'http://localhost:3000');

  final AuthUser _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isOfflineSession => true;

  @override
  Dio createAuthenticatedClient() {
    throw StateError('Reports workspace tests must not use the network.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempSupportDir;
  late AppDatabase db;

  setUp(() async {
    tempSupportDir = await Directory.systemTemp.createTemp(
      'offline-school-reports-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return tempSupportDir.path;
      }
      return null;
    });

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    await _seedAttendanceWorkspace(db);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await db.close();
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  test('builds scoped daily and term attendance summaries offline', () async {
    final auth = _ReportsAuthService(
      const AuthUser(
        id: 'teacher-1',
        email: 'teacher@example.com',
        fullName: 'Teacher User',
        role: 'teacher',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
    );
    final service = ReportsService(
      auth: auth,
      db: db,
      backup: BackupService(db),
      sync: SyncService(db: db, auth: auth),
    );

    final workspace = await service.loadWorkspace();

    expect(workspace.canViewAttendanceReports, isTrue);
    expect(workspace.summaryCounts['Attendance Records'], 3);
    expect(workspace.dailyAttendanceSummaries, hasLength(2));
    final september3 = workspace.dailyAttendanceSummaries.singleWhere(
      (row) => row.date == '2026-09-03',
    );
    expect(september3.className, 'Basic 1A');
    expect(september3.present, 1);
    expect(september3.absent, 1);
    expect(september3.late, 0);
    expect(september3.excused, 0);
    expect(september3.total, 2);

    final ama = workspace.termAttendanceSummaries.singleWhere(
      (row) => row.studentName == 'Ama Mensah',
    );
    final kojo = workspace.termAttendanceSummaries.singleWhere(
      (row) => row.studentName == 'Kojo Boateng',
    );
    expect(ama.present, 1);
    expect(ama.late, 1);
    expect(ama.total, 2);
    expect(kojo.absent, 1);
    expect(kojo.total, 1);
    expect(
      workspace.dailyAttendanceSummaries
          .any((row) => row.className.contains('Other Campus')),
      isFalse,
    );
  });

  test('does not expose attendance detail reports to cashier role', () async {
    final auth = _ReportsAuthService(
      const AuthUser(
        id: 'cashier-1',
        email: 'cashier@example.com',
        fullName: 'Cashier User',
        role: 'cashier',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
    );
    final service = ReportsService(
      auth: auth,
      db: db,
      backup: BackupService(db),
      sync: SyncService(db: db, auth: auth),
    );

    final workspace = await service.loadWorkspace();

    expect(workspace.canViewAttendanceReports, isFalse);
    expect(workspace.dailyAttendanceSummaries, isEmpty);
    expect(workspace.termAttendanceSummaries, isEmpty);
  });
}

Future<void> _seedAttendanceWorkspace(AppDatabase db) async {
  await db.upsertAcademicYear(
    AcademicYearsCacheCompanion.insert(
      id: 'year-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      label: '2026/2027',
      startDate: '2026-09-01',
      endDate: '2027-07-31',
      isCurrent: const Value(true),
    ),
  );
  await db.upsertTerm(
    TermsCacheCompanion.insert(
      id: 'term-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      academicYearId: 'year-1',
      name: 'Term 1',
      termNumber: 1,
      startDate: '2026-09-01',
      endDate: '2026-12-18',
      isCurrent: const Value(true),
    ),
  );
  await db.upsertClassLevel(
    ClassLevelsCacheCompanion.insert(
      id: 'level-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      name: 'Basic 1',
      sortOrder: const Value(1),
    ),
  );
  await db.upsertClassArm(
    ClassArmsCacheCompanion.insert(
      id: 'arm-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      classLevelId: 'level-1',
      arm: 'A',
      displayName: 'Basic 1A',
    ),
  );
  await db.upsertStudent(
    StudentsCompanion.insert(
      id: 'student-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-1'),
      firstName: 'Ama',
      lastName: 'Mensah',
      status: const Value('active'),
    ),
  );
  await db.upsertStudent(
    StudentsCompanion.insert(
      id: 'student-2',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-1'),
      firstName: 'Kojo',
      lastName: 'Boateng',
      status: const Value('active'),
    ),
  );
  await db.upsertAttendanceRecord(
    AttendanceRecordsCompanion.insert(
      id: 'attendance-1',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-1'),
      studentId: 'student-1',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-09-03',
      status: const Value('present'),
    ),
  );
  await db.upsertAttendanceRecord(
    AttendanceRecordsCompanion.insert(
      id: 'attendance-2',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-1'),
      studentId: 'student-2',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-09-03',
      status: const Value('absent'),
    ),
  );
  await db.upsertAttendanceRecord(
    AttendanceRecordsCompanion.insert(
      id: 'attendance-3',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-1'),
      studentId: 'student-1',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-09-04',
      status: const Value('late'),
    ),
  );
  await db.upsertAttendanceRecord(
    AttendanceRecordsCompanion.insert(
      id: 'attendance-other-campus',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: const Value('campus-2'),
      studentId: 'student-1',
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      attendanceDate: '2026-09-03',
      status: const Value('excused'),
    ),
  );
}
