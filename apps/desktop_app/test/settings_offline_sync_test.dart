import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/settings/settings_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineAuthService extends AuthService {
  _OfflineAuthService() : super(backendBaseUrl: 'http://localhost:3000');

  @override
  AuthUser? get currentUser => const AuthUser(
        id: 'user-1',
        email: 'admin@example.com',
        fullName: 'Admin User',
        role: 'admin',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      );

  @override
  bool get isOfflineSession => true;

  @override
  Dio createAuthenticatedClient() {
    throw StateError('Offline settings test must not use the network.');
  }
}

class _OnlineAuthService extends AuthService {
  _OnlineAuthService(this._responses)
      : super(backendBaseUrl: 'http://localhost:3000');

  final Map<String, dynamic> _responses;

  @override
  AuthUser? get currentUser => const AuthUser(
        id: 'user-1',
        email: 'admin@example.com',
        fullName: 'Admin User',
        role: 'admin',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      );

  @override
  bool get isOfflineSession => false;

  @override
  Dio createAuthenticatedClient() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          final payload = _responses[path];
          if (payload == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'No stubbed response for $path',
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: payload,
              statusCode: 200,
            ),
          );
        },
      ),
    );
    return dio;
  }
}

void main() {
  late AppDatabase db;
  late SettingsService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    service = SettingsService(_OfflineAuthService(), db);
  });

  tearDown(() async {
    await db.close();
  });

  test('queues offline academic term creation with tenant-scoped payload',
      () async {
    final now = DateTime.now();
    await db.upsertAcademicYear(
      AcademicYearsCacheCompanion.insert(
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        label: '2026/2027',
        startDate: '2026-09-01',
        endDate: '2027-07-31',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final created = await service.createTerm(
      academicYearId: 'year-1',
      name: 'Term 1',
      termNumber: 1,
      startDate: '2026-09-01',
      endDate: '2026-12-18',
      isCurrent: true,
    );

    final term = await (db.select(db.termsCache)
          ..where((row) => row.id.equals('${created['id']}')))
        .getSingle();
    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.entityId.equals(term.id)))
        .getSingle();
    final payload = jsonDecode(queueItem.payloadJson) as Map<String, dynamic>;

    expect(term.tenantId, 'tenant-1');
    expect(term.schoolId, 'school-1');
    expect(term.academicYearId, 'year-1');
    expect(term.serverRevision, 0);
    expect(queueItem.entityType, 'term');
    expect(queueItem.operation, 'create');
    expect(queueItem.status, 'pending');
    expect(payload['tenantId'], 'tenant-1');
    expect(payload['schoolId'], 'school-1');
    expect(payload['academicYearId'], 'year-1');
  });

  test(
      'rejects offline term creation when parent academic year is out of scope',
      () async {
    await expectLater(
      service.createTerm(
        academicYearId: 'missing-year',
        name: 'Term 1',
        termNumber: 1,
        startDate: '2026-09-01',
        endDate: '2026-12-18',
        isCurrent: true,
      ),
      throwsStateError,
    );

    expect(await db.select(db.termsCache).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test(
      'online workspace refresh defers remote academic overwrite when a local term update is pending',
      () async {
    final now = DateTime.parse('2026-04-23T12:00:00.000Z');
    await db.upsertSchoolProfile(
      SchoolProfileCacheCompanion.insert(
        id: 'school-1',
        tenantId: 'tenant-1',
        name: 'Pilot School',
        schoolType: 'basic',
        onboardingDefaultsJson: '{}',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.upsertTenantProfile(
      TenantProfileCacheCompanion.insert(
        id: 'tenant-1',
        name: 'Pilot Tenant',
        status: 'active',
        contactEmail: const Value('pilot@example.com'),
        contactPhone: const Value('0200000000'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.upsertCampusProfile(
      CampusProfileCacheCompanion.insert(
        id: 'campus-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        name: 'Main Campus',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.upsertAcademicYear(
      AcademicYearsCacheCompanion.insert(
        id: 'year-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        label: '2026/2027',
        startDate: '2026-09-01',
        endDate: '2027-07-31',
        serverRevision: const Value(3),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.upsertTerm(
      TermsCacheCompanion.insert(
        id: 'term-1',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        academicYearId: 'year-1',
        name: 'Offline Term Name',
        termNumber: 1,
        startDate: '2026-09-01',
        endDate: '2026-12-18',
        isCurrent: const Value(true),
        serverRevision: const Value(5),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.enqueueSyncChange(
      entityType: 'term',
      entityId: 'term-1',
      operation: 'update',
      payload: {
        'id': 'term-1',
        'tenantId': 'tenant-1',
        'schoolId': 'school-1',
        'academicYearId': 'year-1',
        'name': 'Offline Term Name',
        'termNumber': 1,
        'startDate': '2026-09-01',
        'endDate': '2026-12-18',
        'isCurrent': true,
        'baseServerRevision': 5,
        'baseUpdatedAt': now.toIso8601String(),
      },
    );

    service = SettingsService(
      _OnlineAuthService({
        '/tenants/current': {
          'id': 'tenant-1',
          'name': 'Pilot Tenant',
          'status': 'active',
          'contactEmail': 'pilot@example.com',
          'contactPhone': '0200000000',
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/schools/school-1': {
          'id': 'school-1',
          'tenantId': 'tenant-1',
          'name': 'Pilot School',
          'shortName': 'PS',
          'schoolType': 'basic',
          'address': null,
          'region': null,
          'district': null,
          'contactPhone': null,
          'contactEmail': null,
          'onboardingDefaults': const <String, dynamic>{},
          'serverRevision': 8,
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/campuses/campus-1': {
          'id': 'campus-1',
          'tenantId': 'tenant-1',
          'schoolId': 'school-1',
          'name': 'Main Campus',
          'address': null,
          'contactPhone': null,
          'registrationCode': 'MAIN',
          'serverRevision': 9,
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/academic/years': [
          {
            'id': 'year-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'label': '2026/2027',
            'startDate': '2026-09-01',
            'endDate': '2027-07-31',
            'isCurrent': true,
            'serverRevision': 3,
            'deleted': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
        '/academic/terms': [
          {
            'id': 'term-1',
            'tenantId': 'tenant-1',
            'schoolId': 'school-1',
            'academicYearId': 'year-1',
            'name': 'Remote Term Name',
            'termNumber': 1,
            'startDate': '2026-09-01',
            'endDate': '2026-12-18',
            'isCurrent': true,
            'serverRevision': 6,
            'deleted': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
        '/academic/class-levels': <Map<String, dynamic>>[],
        '/academic/class-arms': <Map<String, dynamic>>[],
        '/academic/subjects': <Map<String, dynamic>>[],
        '/academic/grading-schemes': <Map<String, dynamic>>[],
        '/devices/trusted': <Map<String, dynamic>>[],
        '/audit/logs': <Map<String, dynamic>>[],
      }),
      db,
    );

    final workspace = await service.loadWorkspace();
    final term = await (db.select(db.termsCache)
          ..where((row) => row.id.equals('term-1')))
        .getSingle();
    final conflicts = await db.getOpenSyncConflicts(limit: 10);
    final schoolRevision = await db.getLastRevision('school');
    final campusRevision = await db.getLastRevision('campus');

    expect(term.name, 'Offline Term Name');
    expect(workspace.tenant['name'], 'Pilot Tenant');
    expect(workspace.terms.single['name'], 'Offline Term Name');
    expect(schoolRevision, 8);
    expect(campusRevision, 9);
    expect(conflicts.single.entityType, 'term');
    expect(conflicts.single.entityId, 'term-1');
    expect(conflicts.single.conflictType, 'pull_deferred');
  });

  test('online workspace refresh rejects mismatched remote workspace scope',
      () async {
    final now = DateTime.parse('2026-04-23T12:00:00.000Z');
    service = SettingsService(
      _OnlineAuthService({
        '/tenants/current': {
          'id': 'tenant-1',
          'name': 'Pilot Tenant',
          'status': 'active',
          'contactEmail': 'pilot@example.com',
          'contactPhone': '0200000000',
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/schools/school-1': {
          'id': 'school-1',
          'tenantId': 'tenant-other',
          'name': 'Wrong Tenant School',
          'shortName': 'WTS',
          'schoolType': 'basic',
          'address': null,
          'region': null,
          'district': null,
          'contactPhone': null,
          'contactEmail': null,
          'onboardingDefaults': const <String, dynamic>{},
          'serverRevision': 8,
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/campuses/campus-1': {
          'id': 'campus-1',
          'tenantId': 'tenant-1',
          'schoolId': 'school-1',
          'name': 'Main Campus',
          'address': null,
          'contactPhone': null,
          'registrationCode': 'MAIN',
          'serverRevision': 9,
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        '/academic/years': <Map<String, dynamic>>[],
        '/academic/terms': <Map<String, dynamic>>[],
        '/academic/class-levels': <Map<String, dynamic>>[],
        '/academic/class-arms': <Map<String, dynamic>>[],
        '/academic/subjects': <Map<String, dynamic>>[],
        '/academic/grading-schemes': <Map<String, dynamic>>[],
        '/devices/trusted': <Map<String, dynamic>>[],
        '/audit/logs': <Map<String, dynamic>>[],
      }),
      db,
    );

    await expectLater(service.loadWorkspace(), throwsStateError);
    expect(
      await db.getSchoolProfile(tenantId: 'tenant-other', schoolId: 'school-1'),
      null,
    );
    expect(await db.getLastRevision('school'), 0);
  });
}
