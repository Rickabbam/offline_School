import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class OnboardingService {
  OnboardingService(this._auth, this._db);

  final AuthService _auth;
  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<AuthUser> bootstrapSchool(OnboardingDraft draft) async {
    final deviceFingerprint = draft.deviceRegistration.registerOfflineAccess
        ? await _auth.ensureDeviceFingerprint()
        : null;
    final dio = _auth.createAuthenticatedClient();
    final response = await dio.post<Map<String, dynamic>>(
      '/onboarding/bootstrap-school',
      data: {
        'school': {
          'name': draft.school.name,
          'shortName': _nullIfBlank(draft.school.shortName),
          'schoolType': draft.school.schoolType,
          'address': _nullIfBlank(draft.school.address),
          'region': _nullIfBlank(draft.school.region),
          'district': _nullIfBlank(draft.school.district),
          'contactPhone': _nullIfBlank(draft.school.contactPhone),
          'contactEmail': _nullIfBlank(draft.school.contactEmail),
        },
        'campus': {
          'name': draft.campus.name,
          'address': _nullIfBlank(draft.campus.address),
          'contactPhone': _nullIfBlank(draft.campus.contactPhone),
          'registrationCode': _nullIfBlank(draft.campus.registrationCode),
        },
        'academicYear': {
          'label': draft.academicYear.label,
          'startDate': draft.academicYear.startDate,
          'endDate': draft.academicYear.endDate,
          'terms': draft.academicYear.terms
              .map(
                (term) => {
                  'name': term.name,
                  'termNumber': term.termNumber,
                  'startDate': term.startDate,
                  'endDate': term.endDate,
                  'isCurrent': term.isCurrent,
                },
              )
              .toList(),
        },
        'classLevels': draft.classSetup.levels
            .map(
              (level) => {
                'name': level.name,
                'sortOrder': level.sortOrder,
                'arms': level.arms.map((arm) => {'arm': arm}).toList(),
              },
            )
            .toList(),
        'subjects': draft.classSetup.subjects
            .map(
              (subject) => {
                'name': subject.name,
                'code': _nullIfBlank(subject.code),
              },
            )
            .toList(),
        'gradingScheme': {
          'name': draft.gradingScheme.name,
          'bands': draft.gradingScheme.bands
              .map(
                (band) => {
                  'grade': band.grade,
                  'min': band.min,
                  'max': band.max,
                  'remark': band.remark,
                },
              )
              .toList(),
        },
        'onboardingDefaults': {
          'staffRoles': draft.staffRoles
              .map(
                (role) => {
                  'role': role.role,
                  'enabled': role.enabled,
                  'headcount': role.headcount,
                },
              )
              .toList(),
          'feeCategories': draft.feeCategories
              .map(
                (category) => {
                  'name': category.name,
                  'defaultAmount': category.defaultAmount,
                  'billingTerm': category.billingTerm,
                },
              )
              .toList(),
          'receiptFormat': {
            'headerLine1': _nullIfBlank(draft.receiptFormat.headerLine1),
            'headerLine2': _nullIfBlank(draft.receiptFormat.headerLine2),
            'footerNote': _nullIfBlank(draft.receiptFormat.footerNote),
            'receiptPrefix': draft.receiptFormat.receiptPrefix,
            'nextReceiptNumber': draft.receiptFormat.nextReceiptNumber,
          },
          'notifications': {
            'smsEnabled': draft.notifications.smsEnabled,
            'paymentReceiptsEnabled':
                draft.notifications.paymentReceiptsEnabled,
            'feeRemindersEnabled': draft.notifications.feeRemindersEnabled,
            'senderId': _nullIfBlank(draft.notifications.senderId),
            'providerName': _nullIfBlank(draft.notifications.providerName),
          },
        },
        'deviceRegistration': {
          'registerOfflineAccess':
              draft.deviceRegistration.registerOfflineAccess,
          'deviceName': _nullIfBlank(
                draft.deviceRegistration.deviceName,
              ) ??
              'Offline School Desktop',
          'deviceFingerprint': deviceFingerprint,
        },
      },
    );

    final userJson = response.data?['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Bootstrap response did not include user context.',
      );
    }

    final user = _auth.updateCurrentUserFromJson(userJson);
    await _syncTrustedDeviceState(response.data ?? const {}, user);
    await _seedBootstrapSnapshot(response.data ?? const {}, user);
    await _seedOnboardingFinanceDefaults(draft, user);
    return user;
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _seedBootstrapSnapshot(
    Map<String, dynamic> responseData,
    AuthUser user,
  ) async {
    final tenantId = user.tenantId;
    final schoolId = user.schoolId;
    if (tenantId == null || schoolId == null) {
      return;
    }

    final scope = LocalDataScope(
      tenantId: tenantId,
      schoolId: schoolId,
      campusId: user.campusId,
    );
    await _db.reconcileLocalScope(scope: scope);

    final snapshot =
        responseData['bootstrapSnapshot'] as Map<String, dynamic>? ?? const {};
    final tenant = responseData['tenant'] as Map<String, dynamic>? ?? const {};
    if (tenant.isNotEmpty) {
      await _db.upsertTenantProfile(
        TenantProfileCacheCompanion(
          id: Value('${tenant['id'] ?? tenantId}'),
          name: Value('${tenant['name']}'),
          status: Value('${tenant['status'] ?? 'trial'}'),
          contactEmail: Value(tenant['contactEmail'] as String?),
          contactPhone: Value(tenant['contactPhone'] as String?),
          deleted: Value(tenant['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${tenant['createdAt']}')),
          updatedAt: Value(DateTime.parse('${tenant['updatedAt']}')),
        ),
      );
    }

    final school = responseData['school'] as Map<String, dynamic>? ?? const {};
    if (school.isNotEmpty) {
      await _db.upsertSchoolProfile(
        SchoolProfileCacheCompanion(
          id: Value('${school['id']}'),
          tenantId: Value('${school['tenantId'] ?? tenantId}'),
          name: Value('${school['name']}'),
          shortName: Value(school['shortName'] as String?),
          schoolType: Value('${school['schoolType']}'),
          address: Value(school['address'] as String?),
          region: Value(school['region'] as String?),
          district: Value(school['district'] as String?),
          contactPhone: Value(school['contactPhone'] as String?),
          contactEmail: Value(school['contactEmail'] as String?),
          onboardingDefaultsJson: Value(
            jsonEncode(school['onboardingDefaults'] ?? const {}),
          ),
          serverRevision: Value(school['serverRevision'] as int? ?? 0),
          deleted: Value(school['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${school['createdAt']}')),
          updatedAt: Value(DateTime.parse('${school['updatedAt']}')),
        ),
      );
      await _db.updateLastRevision(
        'school',
        school['serverRevision'] as int? ?? 0,
      );
    }

    final campus = responseData['campus'] as Map<String, dynamic>? ?? const {};
    if (campus.isNotEmpty) {
      await _db.upsertCampusProfile(
        CampusProfileCacheCompanion(
          id: Value('${campus['id']}'),
          tenantId: Value('${campus['tenantId'] ?? tenantId}'),
          schoolId: Value('${campus['schoolId'] ?? schoolId}'),
          name: Value('${campus['name']}'),
          address: Value(campus['address'] as String?),
          contactPhone: Value(campus['contactPhone'] as String?),
          registrationCode: Value(campus['registrationCode'] as String?),
          serverRevision: Value(campus['serverRevision'] as int? ?? 0),
          deleted: Value(campus['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${campus['createdAt']}')),
          updatedAt: Value(DateTime.parse('${campus['updatedAt']}')),
        ),
      );
      await _db.updateLastRevision(
        'campus',
        campus['serverRevision'] as int? ?? 0,
      );
    }

    final academicYear =
        snapshot['academicYear'] as Map<String, dynamic>? ?? const {};
    if (academicYear.isNotEmpty) {
      await _db.upsertAcademicYear(
        AcademicYearsCacheCompanion(
          id: Value('${academicYear['id']}'),
          tenantId: Value('${academicYear['tenantId']}'),
          schoolId: Value('${academicYear['schoolId']}'),
          label: Value('${academicYear['label']}'),
          startDate: Value('${academicYear['startDate']}'),
          endDate: Value('${academicYear['endDate']}'),
          isCurrent: Value(academicYear['isCurrent'] as bool? ?? false),
          serverRevision: Value(academicYear['serverRevision'] as int? ?? 0),
          deleted: Value(academicYear['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${academicYear['createdAt']}')),
          updatedAt: Value(DateTime.parse('${academicYear['updatedAt']}')),
        ),
      );
      await _db.updateLastRevision(
        'academic_year',
        academicYear['serverRevision'] as int? ?? 0,
      );
    }

    var maxTermRevision = 0;
    for (final item in snapshot['terms'] as List<dynamic>? ?? const []) {
      final term = Map<String, dynamic>.from(item as Map);
      final revision = term['serverRevision'] as int? ?? 0;
      await _db.upsertTerm(
        TermsCacheCompanion(
          id: Value('${term['id']}'),
          tenantId: Value('${term['tenantId']}'),
          schoolId: Value('${term['schoolId']}'),
          academicYearId: Value('${term['academicYearId']}'),
          name: Value('${term['name']}'),
          termNumber: Value(term['termNumber'] as int? ?? 0),
          startDate: Value('${term['startDate']}'),
          endDate: Value('${term['endDate']}'),
          isCurrent: Value(term['isCurrent'] as bool? ?? false),
          serverRevision: Value(revision),
          deleted: Value(term['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${term['createdAt']}')),
          updatedAt: Value(DateTime.parse('${term['updatedAt']}')),
        ),
      );
      if (revision > maxTermRevision) {
        maxTermRevision = revision;
      }
    }
    if (maxTermRevision > 0) {
      await _db.updateLastRevision('term', maxTermRevision);
    }

    var maxClassLevelRevision = 0;
    for (final item in snapshot['classLevels'] as List<dynamic>? ?? const []) {
      final level = Map<String, dynamic>.from(item as Map);
      final revision = level['serverRevision'] as int? ?? 0;
      await _db.upsertClassLevel(
        ClassLevelsCacheCompanion(
          id: Value('${level['id']}'),
          tenantId: Value('${level['tenantId']}'),
          schoolId: Value('${level['schoolId']}'),
          name: Value('${level['name']}'),
          sortOrder: Value(level['sortOrder'] as int? ?? 0),
          serverRevision: Value(revision),
          deleted: Value(level['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${level['createdAt']}')),
          updatedAt: Value(DateTime.parse('${level['updatedAt']}')),
        ),
      );
      if (revision > maxClassLevelRevision) {
        maxClassLevelRevision = revision;
      }
    }
    if (maxClassLevelRevision > 0) {
      await _db.updateLastRevision('class_level', maxClassLevelRevision);
    }

    var maxClassArmRevision = 0;
    for (final item in snapshot['classArms'] as List<dynamic>? ?? const []) {
      final arm = Map<String, dynamic>.from(item as Map);
      final revision = arm['serverRevision'] as int? ?? 0;
      await _db.upsertClassArm(
        ClassArmsCacheCompanion(
          id: Value('${arm['id']}'),
          tenantId: Value('${arm['tenantId']}'),
          schoolId: Value('${arm['schoolId']}'),
          classLevelId: Value('${arm['classLevelId']}'),
          arm: Value('${arm['arm']}'),
          displayName: Value('${arm['displayName']}'),
          serverRevision: Value(revision),
          deleted: Value(arm['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${arm['createdAt']}')),
          updatedAt: Value(DateTime.parse('${arm['updatedAt']}')),
        ),
      );
      if (revision > maxClassArmRevision) {
        maxClassArmRevision = revision;
      }
    }
    if (maxClassArmRevision > 0) {
      await _db.updateLastRevision('class_arm', maxClassArmRevision);
    }

    var maxSubjectRevision = 0;
    for (final item in snapshot['subjects'] as List<dynamic>? ?? const []) {
      final subject = Map<String, dynamic>.from(item as Map);
      final revision = subject['serverRevision'] as int? ?? 0;
      await _db.upsertSubject(
        SubjectsCacheCompanion(
          id: Value('${subject['id']}'),
          tenantId: Value('${subject['tenantId']}'),
          schoolId: Value('${subject['schoolId']}'),
          name: Value('${subject['name']}'),
          code: Value(subject['code'] as String?),
          serverRevision: Value(revision),
          deleted: Value(subject['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${subject['createdAt']}')),
          updatedAt: Value(DateTime.parse('${subject['updatedAt']}')),
        ),
      );
      if (revision > maxSubjectRevision) {
        maxSubjectRevision = revision;
      }
    }
    if (maxSubjectRevision > 0) {
      await _db.updateLastRevision('subject', maxSubjectRevision);
    }

    final gradingScheme =
        snapshot['gradingScheme'] as Map<String, dynamic>? ?? const {};
    if (gradingScheme.isNotEmpty) {
      final revision = gradingScheme['serverRevision'] as int? ?? 0;
      await _db.upsertGradingScheme(
        GradingSchemesCacheCompanion(
          id: Value('${gradingScheme['id']}'),
          tenantId: Value('${gradingScheme['tenantId']}'),
          schoolId: Value('${gradingScheme['schoolId']}'),
          name: Value('${gradingScheme['name']}'),
          bandsJson: Value(jsonEncode(gradingScheme['bands'])),
          isDefault: Value(gradingScheme['isDefault'] as bool? ?? false),
          serverRevision: Value(revision),
          deleted: Value(gradingScheme['deleted'] as bool? ?? false),
          createdAt: Value(DateTime.parse('${gradingScheme['createdAt']}')),
          updatedAt: Value(DateTime.parse('${gradingScheme['updatedAt']}')),
        ),
      );
      await _db.updateLastRevision('grading_scheme', revision);
    }
  }

  Future<void> _syncTrustedDeviceState(
    Map<String, dynamic> responseData,
    AuthUser user,
  ) async {
    final registration =
        responseData['deviceRegistration'] as Map<String, dynamic>? ?? const {};
    final offlineToken = registration['offlineToken'] as String?;

    if (offlineToken == null || offlineToken.isEmpty) {
      await _auth.clearTrustedDeviceAccessCache();
      return;
    }

    await _auth.replaceTrustedDeviceCredentials(
      offlineToken: offlineToken,
      user: user,
    );
  }

  Future<void> _seedOnboardingFinanceDefaults(
    OnboardingDraft draft,
    AuthUser user,
  ) async {
    final tenantId = user.tenantId;
    final schoolId = user.schoolId;
    if (tenantId == null || schoolId == null || draft.feeCategories.isEmpty) {
      return;
    }

    final scope = LocalDataScope(
      tenantId: tenantId,
      schoolId: schoolId,
      campusId: user.campusId,
    );
    final existingCategories = await _db.getFeeCategories(scope: scope);
    if (existingCategories.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    await _db.transaction(() async {
      for (final category in draft.feeCategories) {
        final categoryId = _uuid.v4();
        await _db.upsertFeeCategory(
          FeeCategoriesCompanion(
            id: Value(categoryId),
            tenantId: Value(tenantId),
            schoolId: Value(schoolId),
            name: Value(category.name),
            billingTerm: Value(category.billingTerm),
            isActive: const Value(true),
            serverRevision: const Value(0),
            deleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _db.enqueueSyncChange(
          entityType: 'fee_category',
          entityId: categoryId,
          operation: 'create',
          payload: {
            'id': categoryId,
            'tenantId': tenantId,
            'schoolId': schoolId,
            'name': category.name,
            'billingTerm': category.billingTerm,
            'isActive': true,
          },
        );

        final feeStructureItemId = _uuid.v4();
        await _db.upsertFeeStructureItem(
          FeeStructureItemsCompanion(
            id: Value(feeStructureItemId),
            tenantId: Value(tenantId),
            schoolId: Value(schoolId),
            feeCategoryId: Value(categoryId),
            classLevelId: const Value(null),
            termId: const Value(null),
            amount: Value(category.defaultAmount),
            notes: const Value('Seeded from onboarding wizard'),
            serverRevision: const Value(0),
            deleted: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _db.enqueueSyncChange(
          entityType: 'fee_structure_item',
          entityId: feeStructureItemId,
          operation: 'create',
          payload: {
            'id': feeStructureItemId,
            'tenantId': tenantId,
            'schoolId': schoolId,
            'feeCategoryId': categoryId,
            'classLevelId': null,
            'termId': null,
            'amount': category.defaultAmount,
            'notes': 'Seeded from onboarding wizard',
          },
        );
      }
    });
  }
}
