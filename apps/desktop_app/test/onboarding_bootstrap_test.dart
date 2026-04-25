import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/onboarding/onboarding_models.dart';
import 'package:desktop_app/ui/onboarding/onboarding_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnboardingAuthService extends AuthService {
  _OnboardingAuthService(this._responseData)
      : super(backendBaseUrl: 'http://localhost:3000');

  final Map<String, dynamic> _responseData;
  AuthUser? _currentUser = const AuthUser(
    id: 'user-1',
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
  Future<String> ensureDeviceFingerprint() async => 'device-fingerprint-1';

  @override
  Dio createAuthenticatedClient() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: _responseData,
              statusCode: 200,
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
      'bootstrap seeds fee categories and default fee structures into local offline state and sync queue',
      () async {
    final responseData = {
      'user': {
        'id': 'user-1',
        'email': 'admin@example.com',
        'fullName': 'Admin User',
        'role': 'admin',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'campusId': 'campus-1',
      },
      'tenant': {
        'id': 'tenant-1',
        'name': 'Pilot Tenant',
        'status': 'trial',
        'contactEmail': 'pilot@example.com',
        'contactPhone': '0200000000',
        'deleted': false,
        'createdAt': '2026-04-23T12:00:00.000Z',
        'updatedAt': '2026-04-23T12:00:00.000Z',
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
        'terms': <Map<String, dynamic>>[],
        'classLevels': <Map<String, dynamic>>[],
        'classArms': <Map<String, dynamic>>[],
        'subjects': <Map<String, dynamic>>[],
        'gradingScheme': {
          'id': 'scheme-1',
          'tenantId': 'tenant-1',
          'schoolId': 'school-1',
          'name': 'Default',
          'bands': [
            {'grade': 'A', 'min': 80, 'max': 100, 'remark': 'Excellent'},
          ],
          'isDefault': true,
          'serverRevision': 13,
          'deleted': false,
          'createdAt': '2026-04-23T12:00:00.000Z',
          'updatedAt': '2026-04-23T12:00:00.000Z',
        },
      },
      'deviceRegistration': {
        'offlineToken': 'offline-token-1',
      },
    };
    final auth = _OnboardingAuthService(responseData);
    final service = OnboardingService(auth, db);
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
      ),
      gradingScheme: GradingSchemeDraft(
        name: 'Default',
        bands: [
          GradeBandDraft(grade: 'A', min: 80, max: 100, remark: 'Excellent'),
        ],
      ),
      feeCategories: [
        FeeCategoryDraft(
          name: 'Tuition',
          defaultAmount: 450,
          billingTerm: 'per_term',
        ),
        FeeCategoryDraft(
          name: 'PTA Levy',
          defaultAmount: 60,
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

    final user = await service.bootstrapSchool(draft);

    expect(user.tenantId, 'tenant-1');
    expect(auth.trustedOfflineToken, 'offline-token-1');

    const scope = LocalDataScope(
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );
    final categories = await db.getFeeCategories(scope: scope);
    final items = await db.getFeeStructureItems(scope: scope);
    final queueItems = await (db.select(db.syncQueue)
          ..where((row) => row.entityType.isIn(['fee_category', 'fee_structure_item'])))
        .get();
    final school = await (db.select(db.schoolProfileCache)
          ..where((row) => row.id.equals('school-1')))
        .getSingle();
    final tenant = await (db.select(db.tenantProfileCache)
          ..where((row) => row.id.equals('tenant-1')))
        .getSingle();

    expect(categories, hasLength(2));
    expect(items, hasLength(2));
    expect(queueItems, hasLength(4));
    expect(tenant.name, 'Pilot Tenant');
    expect(tenant.status, 'trial');

    final queuedCategoryPayloads = queueItems
        .where((row) => row.entityType == 'fee_category')
        .map((row) => jsonDecode(row.payloadJson) as Map<String, dynamic>)
        .toList(growable: false);
    final queuedStructurePayloads = queueItems
        .where((row) => row.entityType == 'fee_structure_item')
        .map((row) => jsonDecode(row.payloadJson) as Map<String, dynamic>)
        .toList(growable: false);

    expect(
      queuedCategoryPayloads.map((payload) => payload['name']),
      containsAll(['Tuition', 'PTA Levy']),
    );
    expect(
      queuedStructurePayloads.map((payload) => payload['amount']),
      containsAll([450.0, 60.0]),
    );

    final onboardingDefaults =
        jsonDecode(school.onboardingDefaultsJson) as Map<String, dynamic>;
    expect(
      onboardingDefaults['receiptFormat'],
      isA<Map<String, dynamic>>(),
    );
    expect(
      (onboardingDefaults['feeCategories'] as List<dynamic>).length,
      1,
    );
  });
}
