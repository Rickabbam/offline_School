import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/attendance/attendance_capture_service.dart';
import 'package:desktop_app/ui/attendance/attendance_workspace_service.dart';
import 'package:desktop_app/ui/onboarding/onboarding_models.dart';
import 'package:desktop_app/ui/onboarding/onboarding_service.dart';
import 'package:desktop_app/ui/students/student_editor_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _PhaseBAuthService extends AuthService {
  _PhaseBAuthService(this._responseData)
      : super(backendBaseUrl: 'http://localhost:3000');

  final Map<String, dynamic> _responseData;
  AuthUser? _currentUser = const AuthUser(
    id: 'admin-1',
    email: 'admin@example.com',
    fullName: 'Admin User',
    role: 'admin',
    tenantId: null,
    schoolId: null,
    campusId: null,
  );
  String? trustedOfflineToken;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<String?> getDeviceFingerprint() async => 'device-fingerprint-1';

  @override
  Future<String> ensureDeviceFingerprint() async => 'device-fingerprint-1';

  @override
  Dio createAuthenticatedClient() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/onboarding/bootstrap-school') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: _responseData,
                statusCode: 200,
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected request in Phase B verification test.',
            ),
          );
        },
      ),
    );
    return dio;
  }

  @override
  AuthUser updateCurrentUserFromJson(Map<String, dynamic> json) {
    final user = AuthUser.fromJson(json);
    _currentUser = user;
    return user;
  }

  @override
  Future<void> replaceTrustedDeviceCredentials({
    required String offlineToken,
    required AuthUser user,
  }) async {
    trustedOfflineToken = offlineToken;
    _currentUser = user;
  }

  @override
  Future<void> clearTrustedDeviceAccessCache() async {
    trustedOfflineToken = null;
  }
}

Future<void> _acknowledgeAllPendingQueueItems(AppDatabase db) async {
  final items = await db.select(db.syncQueue).get();
  var revision = 200;
  for (final item in items) {
    final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    await db.applyPushAcknowledgement(
      queueItemId: item.id,
      entityType: item.entityType,
      requestedEntityId: item.entityId,
      canonicalEntityId: item.entityId,
      serverRevision: revision++,
      tenantId: '${payload['tenantId']}',
      schoolId: '${payload['schoolId']}',
    );
  }
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
      'Phase B verification covers admin bootstrap, offline teacher attendance, and sync reconciliation',
      () async {
    final responseData = {
      'user': {
        'id': 'admin-1',
        'email': 'admin@example.com',
        'fullName': 'Admin User',
        'role': 'admin',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'campusId': 'campus-1',
      },
      'school': {
        'id': 'school-1',
        'tenantId': 'tenant-1',
        'name': 'Pilot School',
        'shortName': 'PS',
        'schoolType': 'basic',
        'address': 'Main Street',
        'region': 'Greater Accra',
        'district': 'Accra Metro',
        'contactPhone': '0200000000',
        'contactEmail': 'pilot@example.com',
        'onboardingDefaults': {
          'feeCategories': [
            {
              'name': 'Tuition',
              'defaultAmount': 450.0,
              'billingTerm': 'per_term',
            },
          ],
          'receiptFormat': {
            'receiptPrefix': 'RCP',
            'nextReceiptNumber': 1,
          },
          'notifications': {
            'smsEnabled': false,
            'paymentReceiptsEnabled': true,
            'feeRemindersEnabled': true,
          },
          'staffRoles': [
            {'role': 'admin', 'enabled': true, 'headcount': 1},
            {'role': 'teacher', 'enabled': true, 'headcount': 4},
          ],
        },
        'serverRevision': 10,
        'deleted': false,
        'createdAt': '2026-04-23T12:00:00.000Z',
        'updatedAt': '2026-04-23T12:00:00.000Z',
      },
      'campus': {
        'id': 'campus-1',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'name': 'Main Campus',
        'address': 'Main Street',
        'contactPhone': '0200000000',
        'registrationCode': 'MAIN',
        'serverRevision': 11,
        'deleted': false,
        'createdAt': '2026-04-23T12:00:00.000Z',
        'updatedAt': '2026-04-23T12:00:00.000Z',
      },
      'bootstrapSnapshot': {
        'academicYear': {
          'id': 'year-1',
          'tenantId': 'tenant-1',
          'schoolId': 'school-1',
          'label': '2026/2027',
          'startDate': '2026-09-01',
          'endDate': '2027-07-31',
          'isCurrent': true,
          'serverRevision': 12,
          'deleted': false,
          'createdAt': '2026-04-23T12:00:00.000Z',
          'updatedAt': '2026-04-23T12:00:00.000Z',
        },
        'terms': [
          {
            'id': 'term-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'academicYearId': 'year-1',
            'name': 'Term 1',
            'termNumber': 1,
            'startDate': '2026-09-01',
            'endDate': '2026-12-18',
            'isCurrent': true,
            'serverRevision': 13,
            'deleted': false,
            'createdAt': '2026-04-23T12:00:00.000Z',
            'updatedAt': '2026-04-23T12:00:00.000Z',
          },
        ],
        'classLevels': [
          {
            'id': 'level-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'name': 'Basic 1',
            'sortOrder': 1,
            'serverRevision': 14,
            'deleted': false,
            'createdAt': '2026-04-23T12:00:00.000Z',
            'updatedAt': '2026-04-23T12:00:00.000Z',
          },
        ],
        'classArms': [
          {
            'id': 'arm-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'classLevelId': 'level-1',
            'arm': 'A',
            'displayName': 'Basic 1A',
            'serverRevision': 15,
            'deleted': false,
            'createdAt': '2026-04-23T12:00:00.000Z',
            'updatedAt': '2026-04-23T12:00:00.000Z',
          },
        ],
        'subjects': [
          {
            'id': 'subject-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'name': 'Mathematics',
            'code': 'MATH',
            'serverRevision': 16,
            'deleted': false,
            'createdAt': '2026-04-23T12:00:00.000Z',
            'updatedAt': '2026-04-23T12:00:00.000Z',
          },
        ],
        'gradingScheme': {
          'id': 'scheme-1',
          'tenantId': 'tenant-1',
          'schoolId': 'school-1',
          'name': 'Default',
          'bands': [
            {'grade': 'A', 'min': 80, 'max': 100, 'remark': 'Excellent'},
          ],
          'isDefault': true,
          'serverRevision': 17,
          'deleted': false,
          'createdAt': '2026-04-23T12:00:00.000Z',
          'updatedAt': '2026-04-23T12:00:00.000Z',
        },
      },
      'deviceRegistration': {
        'offlineToken': 'offline-token-1',
      },
    };

    final auth = _PhaseBAuthService(responseData);
    final onboarding = OnboardingService(auth, db);
    final studentEditor = StudentEditorService();
    final attendanceWorkspace = AttendanceWorkspaceService(db);
    final attendanceCapture = AttendanceCaptureService();

    const draft = OnboardingDraft(
      school: SchoolProfileDraft(
        name: 'Pilot School',
        schoolType: 'basic',
      ),
      campus: CampusSetupDraft(name: 'Main Campus'),
      academicYear: AcademicYearDraft(
        label: '2026/2027',
        startDate: '2026-09-01',
        endDate: '2027-07-31',
        terms: [
          AcademicTermDraft(
            name: 'Term 1',
            termNumber: 1,
            startDate: '2026-09-01',
            endDate: '2026-12-18',
            isCurrent: true,
          ),
        ],
      ),
      classSetup: ClassSetupDraft(
        levels: [
          ClassLevelDraft(name: 'Basic 1', sortOrder: 1, arms: ['A']),
        ],
        subjects: [
          SubjectDraft(name: 'Mathematics', code: 'MATH'),
        ],
      ),
      gradingScheme: GradingSchemeDraft(
        name: 'Default',
        bands: [
          GradeBandDraft(grade: 'A', min: 80, max: 100, remark: 'Excellent'),
        ],
      ),
      staffRoles: [
        StaffRoleDraft(role: 'admin', enabled: true, headcount: 1),
        StaffRoleDraft(role: 'teacher', enabled: true, headcount: 4),
      ],
      feeCategories: [
        FeeCategoryDraft(
          name: 'Tuition',
          defaultAmount: 450,
          billingTerm: 'per_term',
        ),
      ],
      receiptFormat: ReceiptFormatDraft(receiptPrefix: 'RCP'),
      notifications: NotificationSettingsDraft(
        smsEnabled: false,
        paymentReceiptsEnabled: true,
        feeRemindersEnabled: true,
      ),
      deviceRegistration: DeviceRegistrationDraft(
        deviceName: 'Admin Office PC',
        registerOfflineAccess: true,
      ),
    );

    final adminUser = await onboarding.bootstrapSchool(draft);
    expect(adminUser.tenantId, 'tenant-1');
    expect(auth.trustedOfflineToken, 'offline-token-1');

    const scope = LocalDataScope(
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );
    final workspace = await attendanceWorkspace.loadWorkspace(scope);
    expect(workspace.currentAcademicYearId, 'year-1');
    expect(workspace.currentTermId, 'term-1');
    expect(
      workspace.classArms.map((arm) => arm['id']),
      contains('arm-1'),
    );

    await studentEditor.saveStudent(
      db: db,
      user: adminUser,
      input: const StudentEditorInput(
        firstName: 'Ama',
        middleName: '',
        lastName: 'Mensah',
        studentNumber: 'ST-001',
        dateOfBirth: '2014-05-20',
        gender: 'female',
        status: 'active',
        guardianFirstName: '',
        guardianLastName: '',
        guardianPhone: '',
        guardianEmail: '',
        guardianRelationship: 'guardian',
        academicYearId: 'year-1',
        classArmId: 'arm-1',
        guardianId: null,
        currentEnrollmentId: null,
      ),
    );

    final students = await db.getStudents(scope: scope);
    expect(students, hasLength(1));
    const teacherUser = AuthUser(
      id: 'teacher-1',
      email: 'teacher@example.com',
      fullName: 'Teacher User',
      role: 'teacher',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    await attendanceCapture.markAttendance(
      db: db,
      user: teacherUser,
      student: students.single,
      classArmId: 'arm-1',
      academicYearId: 'year-1',
      termId: 'term-1',
      date: DateTime.utc(2026, 9, 3),
      status: 'present',
    );

    final dailyRecords = await db.getAttendanceForClass(
      scope: scope,
      classArmId: 'arm-1',
      date: '2026-09-03',
    );
    final termRecords = await db.getAttendanceForClassTerm(
      scope: scope,
      classArmId: 'arm-1',
      termId: 'term-1',
    );
    expect(dailyRecords, hasLength(1));
    expect(dailyRecords.single.status, 'present');
    expect(termRecords, hasLength(1));

    final pendingQueue = await db.select(db.syncQueue).get();
    expect(pendingQueue, isNotEmpty);

    await _acknowledgeAllPendingQueueItems(db);

    final syncedQueue = await db.select(db.syncQueue).get();
    final syncedStudent = await db.findStudentById(
      scope: scope,
      studentId: students.single.id,
    );
    final syncedAttendance = await db.findAttendanceRecord(
      scope: scope,
      classArmId: 'arm-1',
      studentId: students.single.id,
      date: '2026-09-03',
    );

    expect(
      syncedQueue.every((item) => item.status == 'done'),
      isTrue,
    );
    expect(syncedStudent, isNotNull);
    expect(syncedStudent!.syncStatus, 'synced');
    expect(syncedStudent.serverRevision, greaterThan(0));
    expect(syncedAttendance, isNotNull);
    expect(syncedAttendance!.syncStatus, 'synced');
    expect(syncedAttendance.serverRevision, greaterThan(0));
  });
}
