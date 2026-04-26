import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class SettingsWorkspaceData {
  const SettingsWorkspaceData({
    required this.tenant,
    required this.school,
    required this.campus,
    required this.academicYears,
    required this.terms,
    required this.classLevels,
    required this.classArms,
    required this.subjects,
    required this.gradingSchemes,
    required this.trustedDevices,
    required this.auditEntries,
  });

  final Map<String, dynamic> tenant;
  final Map<String, dynamic> school;
  final Map<String, dynamic> campus;
  final List<Map<String, dynamic>> academicYears;
  final List<Map<String, dynamic>> terms;
  final List<Map<String, dynamic>> classLevels;
  final List<Map<String, dynamic>> classArms;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> gradingSchemes;
  final List<Map<String, dynamic>> trustedDevices;
  final List<Map<String, dynamic>> auditEntries;
}

class SettingsService {
  SettingsService(this._auth, this._db);

  final AuthService _auth;
  final AppDatabase _db;
  final _uuid = const Uuid();

  Dio get _client => _auth.createAuthenticatedClient();

  AuthUser get _user {
    final user = _auth.currentUser;
    if (user == null || user.schoolId == null || user.campusId == null) {
      throw StateError('School workspace is not available for this session.');
    }
    return user;
  }

  Future<SettingsWorkspaceData> loadWorkspace() async {
    if (_auth.isOfflineSession) {
      return _loadOfflineWorkspace();
    }

    final user = _user;
    try {
      final tenantResponse =
          await _client.get<Map<String, dynamic>>('/tenants/current');
      final schoolResponse =
          await _client.get<Map<String, dynamic>>('/schools/${user.schoolId}');
      final campusResponse =
          await _client.get<Map<String, dynamic>>('/campuses/${user.campusId}');
      final yearsResponse = await _client.get<List<dynamic>>('/academic/years');
      final termsResponse = await _client.get<List<dynamic>>('/academic/terms');
      final classLevelsResponse =
          await _client.get<List<dynamic>>('/academic/class-levels');
      final classArmsResponse =
          await _client.get<List<dynamic>>('/academic/class-arms');
      final subjectsResponse =
          await _client.get<List<dynamic>>('/academic/subjects');
      final gradingSchemesResponse =
          await _client.get<List<dynamic>>('/academic/grading-schemes');
      final trustedDevicesResponse =
          await _client.get<List<dynamic>>('/devices/trusted');
      final auditEntriesResponse = await _client.get<List<dynamic>>(
        '/audit/logs',
        queryParameters: {'limit': 20},
      );

      final remoteTenant = Map<String, dynamic>.from(tenantResponse.data!);
      final remoteSchool = Map<String, dynamic>.from(schoolResponse.data!);
      final remoteCampus = Map<String, dynamic>.from(campusResponse.data!);
      _assertRemoteWorkspaceScope(
        user: user,
        tenant: remoteTenant,
        school: remoteSchool,
        campus: remoteCampus,
      );
      final remoteYears = _asListOfMaps(yearsResponse.data);
      final remoteTerms = _asListOfMaps(termsResponse.data);
      final remoteClassLevels = _asListOfMaps(classLevelsResponse.data);
      final remoteClassArms = _asListOfMaps(classArmsResponse.data);
      final remoteSubjects = _asListOfMaps(subjectsResponse.data);
      final remoteGradingSchemes = _asListOfMaps(gradingSchemesResponse.data);
      await _db.transaction(() async {
        for (final year in remoteYears) {
          await _persistRemoteAcademicYear(year);
        }
        for (final term in remoteTerms) {
          await _persistRemoteTerm(term);
        }
        for (final level in remoteClassLevels) {
          await _persistRemoteClassLevel(level);
        }
        for (final arm in remoteClassArms) {
          await _persistRemoteClassArm(arm);
        }
        for (final subject in remoteSubjects) {
          await _persistRemoteSubject(subject);
        }
        for (final scheme in remoteGradingSchemes) {
          await _persistRemoteGradingScheme(scheme);
        }
        await _persistRemoteTenant(remoteTenant);
        await _persistRemoteSchool(remoteSchool);
        await _persistRemoteCampus(remoteCampus);
      });

      return SettingsWorkspaceData(
        tenant: remoteTenant,
        school: remoteSchool,
        campus: remoteCampus,
        academicYears: await _loadLocalAcademicYears(),
        terms: await _loadLocalTerms(),
        classLevels: await _loadLocalClassLevels(),
        classArms: await _loadLocalClassArms(),
        subjects: await _loadLocalSubjects(),
        gradingSchemes: await _loadLocalGradingSchemes(),
        trustedDevices: _asListOfMaps(trustedDevicesResponse.data),
        auditEntries: _asListOfMaps(auditEntriesResponse.data),
      );
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _loadOfflineWorkspace();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listTrustedDevices() async {
    final response = await _client.get<List<dynamic>>('/devices/trusted');
    return _asListOfMaps(response.data);
  }

  Future<Map<String, dynamic>> revokeTrustedDevice(String deviceId) async {
    final response =
        await _client.delete<Map<String, dynamic>>('/devices/$deviceId');
    return Map<String, dynamic>.from(response.data!);
  }

  Future<List<Map<String, dynamic>>> listAuditEntries({int limit = 20}) async {
    final response = await _client.get<List<dynamic>>(
      '/audit/logs',
      queryParameters: {'limit': limit},
    );
    return _asListOfMaps(response.data);
  }

  void _assertRemoteWorkspaceScope({
    required AuthUser user,
    required Map<String, dynamic> tenant,
    required Map<String, dynamic> school,
    required Map<String, dynamic> campus,
  }) {
    if (tenant['id'] != user.tenantId) {
      throw StateError(
        'Remote tenant payload does not match the authenticated workspace.',
      );
    }
    if (school['id'] != user.schoolId || school['tenantId'] != user.tenantId) {
      throw StateError(
        'Remote school payload does not match the authenticated workspace.',
      );
    }
    if (campus['id'] != user.campusId ||
        campus['schoolId'] != user.schoolId ||
        campus['tenantId'] != user.tenantId) {
      throw StateError(
        'Remote campus payload does not match the authenticated workspace.',
      );
    }
  }

  Future<Map<String, dynamic>> updateSchool({
    required String name,
    required String shortName,
    required String address,
    required String region,
    required String district,
    required String contactPhone,
    required String contactEmail,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalSchool(
        name: name,
        shortName: shortName,
        address: address,
        region: region,
        district: district,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );
    }

    final user = _user;
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/schools/${user.schoolId}',
        data: {
          'name': name,
          'shortName': _nullable(shortName),
          'address': _nullable(address),
          'region': _nullable(region),
          'district': _nullable(district),
          'contactPhone': _nullable(contactPhone),
          'contactEmail': _nullable(contactEmail),
        },
      );
      final school = Map<String, dynamic>.from(response.data!);
      await _persistRemoteSchool(school);
      return school;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalSchool(
          name: name,
          shortName: shortName,
          address: address,
          region: region,
          district: district,
          contactPhone: contactPhone,
          contactEmail: contactEmail,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCampus({
    required String name,
    required String address,
    required String contactPhone,
    required String registrationCode,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalCampus(
        name: name,
        address: address,
        contactPhone: contactPhone,
        registrationCode: registrationCode,
      );
    }

    final user = _user;
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/campuses/${user.campusId}',
        data: {
          'name': name,
          'address': _nullable(address),
          'contactPhone': _nullable(contactPhone),
          'registrationCode': _nullable(registrationCode),
        },
      );
      final campus = Map<String, dynamic>.from(response.data!);
      await _persistRemoteCampus(campus);
      return campus;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalCampus(
          name: name,
          address: address,
          contactPhone: contactPhone,
          registrationCode: registrationCode,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createAcademicYear({
    required String label,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalAcademicYear(
        label: label,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/years',
        data: {
          'label': label,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
        },
      );
      final year = Map<String, dynamic>.from(response.data!);
      await _persistRemoteAcademicYear(year);
      return year;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalAcademicYear(
          label: label,
          startDate: startDate,
          endDate: endDate,
          isCurrent: isCurrent,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateAcademicYear({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalAcademicYear(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/years/$id',
        data: data,
      );
      final year = Map<String, dynamic>.from(response.data!);
      await _persistRemoteAcademicYear(year);
      return year;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalAcademicYear(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteAcademicYear(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalAcademicYear(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/years/$id');
      await _deleteLocalAcademicYear(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalAcademicYear(id);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createClassLevel({
    required String name,
    required int sortOrder,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalClassLevel(name: name, sortOrder: sortOrder);
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/class-levels',
        data: {
          'name': name,
          'sortOrder': sortOrder,
        },
      );
      final level = Map<String, dynamic>.from(response.data!);
      await _persistRemoteClassLevel(level);
      return level;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalClassLevel(name: name, sortOrder: sortOrder);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateClassLevel({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalClassLevel(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/class-levels/$id',
        data: data,
      );
      final level = Map<String, dynamic>.from(response.data!);
      await _persistRemoteClassLevel(level);
      return level;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalClassLevel(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteClassLevel(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalClassLevel(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/class-levels/$id');
      await _deleteLocalClassLevel(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalClassLevel(id);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTerm({
    required String academicYearId,
    required String name,
    required int termNumber,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalTerm(
        academicYearId: academicYearId,
        name: name,
        termNumber: termNumber,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/terms',
        data: {
          'academicYearId': academicYearId,
          'name': name,
          'termNumber': termNumber,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
        },
      );
      final term = Map<String, dynamic>.from(response.data!);
      await _persistRemoteTerm(term);
      return term;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalTerm(
          academicYearId: academicYearId,
          name: name,
          termNumber: termNumber,
          startDate: startDate,
          endDate: endDate,
          isCurrent: isCurrent,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTerm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalTerm(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/terms/$id',
        data: data,
      );
      final term = Map<String, dynamic>.from(response.data!);
      await _persistRemoteTerm(term);
      return term;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalTerm(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteTerm(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalTerm(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/terms/$id');
      await _deleteLocalTerm(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalTerm(id);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createClassArm({
    required String classLevelId,
    required String arm,
    required String displayName,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalClassArm(
        classLevelId: classLevelId,
        arm: arm,
        displayName: displayName,
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/class-arms',
        data: {
          'classLevelId': classLevelId,
          'arm': arm,
          'displayName': displayName,
        },
      );
      final classArm = Map<String, dynamic>.from(response.data!);
      await _persistRemoteClassArm(classArm);
      return classArm;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalClassArm(
          classLevelId: classLevelId,
          arm: arm,
          displayName: displayName,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateClassArm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalClassArm(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/class-arms/$id',
        data: data,
      );
      final classArm = Map<String, dynamic>.from(response.data!);
      await _persistRemoteClassArm(classArm);
      return classArm;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalClassArm(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteClassArm(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalClassArm(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/class-arms/$id');
      await _deleteLocalClassArm(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalClassArm(id);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSubject({
    required String name,
    required String code,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalSubject(name: name, code: code);
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/subjects',
        data: {
          'name': name,
          'code': _nullable(code),
        },
      );
      final subject = Map<String, dynamic>.from(response.data!);
      await _persistRemoteSubject(subject);
      return subject;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalSubject(name: name, code: code);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSubject({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalSubject(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/subjects/$id',
        data: data,
      );
      final subject = Map<String, dynamic>.from(response.data!);
      await _persistRemoteSubject(subject);
      return subject;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalSubject(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteSubject(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalSubject(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/subjects/$id');
      await _deleteLocalSubject(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalSubject(id);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createGradingScheme({
    required String name,
    required List<Map<String, dynamic>> bands,
    required bool isDefault,
  }) async {
    if (_auth.isOfflineSession) {
      return _createLocalGradingScheme(
        name: name,
        bands: bands,
        isDefault: isDefault,
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/academic/grading-schemes',
        data: {
          'name': name,
          'bands': bands,
          'isDefault': isDefault,
        },
      );
      final scheme = Map<String, dynamic>.from(response.data!);
      await _persistRemoteGradingScheme(scheme);
      return scheme;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _createLocalGradingScheme(
          name: name,
          bands: bands,
          isDefault: isDefault,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateGradingScheme({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (_auth.isOfflineSession) {
      return _updateLocalGradingScheme(id: id, data: data);
    }

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/academic/grading-schemes/$id',
        data: data,
      );
      final scheme = Map<String, dynamic>.from(response.data!);
      await _persistRemoteGradingScheme(scheme);
      return scheme;
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        return _updateLocalGradingScheme(id: id, data: data);
      }
      rethrow;
    }
  }

  Future<void> deleteGradingScheme(String id) async {
    if (_auth.isOfflineSession) {
      await _deleteLocalGradingScheme(id);
      return;
    }

    try {
      await _client.delete<void>('/academic/grading-schemes/$id');
      await _deleteLocalGradingScheme(id, enqueueDelete: false);
    } on DioException catch (error) {
      if (_isConnectivityFailure(error)) {
        await _deleteLocalGradingScheme(id);
        return;
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _asListOfMaps(List<dynamic>? raw) {
    return (raw ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  LocalDataScope get _scope => LocalDataScope(
        tenantId: _user.tenantId!,
        schoolId: _user.schoolId!,
        campusId: _user.campusId,
      );

  Future<List<Map<String, dynamic>>> _loadLocalGradingSchemes() async {
    final rows = await _db.getGradingSchemes(scope: _scope);
    return rows.map(_gradingSchemeRowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadLocalAcademicYears() async {
    final rows = await _db.getAcademicYears(scope: _scope);
    return rows.map(_academicYearRowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadLocalTerms() async {
    final rows = await _db.getTerms(scope: _scope);
    return rows.map(_termRowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadLocalClassLevels() async {
    final rows = await _db.getClassLevels(scope: _scope);
    return rows.map(_classLevelRowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadLocalClassArms() async {
    final rows = await _db.getClassArms(scope: _scope);
    return rows.map(_classArmRowToMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadLocalSubjects() async {
    final rows = await _db.getSubjects(scope: _scope);
    return rows.map(_subjectRowToMap).toList(growable: false);
  }

  Future<SettingsWorkspaceData> _loadOfflineWorkspace() async {
    final scope = _scope;
    final tenant = await _db.getTenantProfile(tenantId: scope.tenantId);
    final school = await _db.getSchoolProfile(
      tenantId: scope.tenantId,
      schoolId: scope.schoolId,
    );
    final campus = await _db.getCampusProfile(scope: scope);
    final years = await _db.getAcademicYears(scope: scope);
    final terms = await _db.getTerms(scope: scope);
    final classLevels = await _db.getClassLevels(scope: scope);
    final classArms = await _db.getClassArms(scope: scope);
    final subjects = await _db.getSubjects(scope: scope);

    return SettingsWorkspaceData(
      tenant: {
        'id': tenant?.id ?? scope.tenantId,
        'name': tenant?.name ?? '',
        'status': tenant?.status ?? 'trial',
        'contactEmail': tenant?.contactEmail ?? '',
        'contactPhone': tenant?.contactPhone ?? '',
      },
      school: {
        'id': school?.id ?? scope.schoolId,
        'tenantId': school?.tenantId ?? scope.tenantId,
        'name': school?.name ?? '',
        'shortName': school?.shortName ?? '',
        'schoolType': school?.schoolType ?? 'basic',
        'address': school?.address ?? '',
        'region': school?.region ?? '',
        'district': school?.district ?? '',
        'contactPhone': school?.contactPhone ?? '',
        'contactEmail': school?.contactEmail ?? '',
        'onboardingDefaults': school == null
            ? const <String, dynamic>{}
            : jsonDecode(school.onboardingDefaultsJson) as Map<String, dynamic>,
        'serverRevision': school?.serverRevision ?? 0,
      },
      campus: {
        'id': campus?.id ?? scope.campusId,
        'tenantId': campus?.tenantId ?? scope.tenantId,
        'schoolId': campus?.schoolId ?? scope.schoolId,
        'name': campus?.name ?? '',
        'address': campus?.address ?? '',
        'contactPhone': campus?.contactPhone ?? '',
        'registrationCode': campus?.registrationCode ?? '',
        'serverRevision': campus?.serverRevision ?? 0,
      },
      academicYears: years
          .map(
            (row) => {
              'id': row.id,
              'tenantId': row.tenantId,
              'schoolId': row.schoolId,
              'label': row.label,
              'startDate': row.startDate,
              'endDate': row.endDate,
              'isCurrent': row.isCurrent,
              'serverRevision': row.serverRevision,
              'deleted': row.deleted,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      terms: terms
          .map(
            (row) => {
              'id': row.id,
              'tenantId': row.tenantId,
              'schoolId': row.schoolId,
              'academicYearId': row.academicYearId,
              'name': row.name,
              'termNumber': row.termNumber,
              'startDate': row.startDate,
              'endDate': row.endDate,
              'isCurrent': row.isCurrent,
              'serverRevision': row.serverRevision,
              'deleted': row.deleted,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      classLevels: classLevels
          .map(
            (row) => {
              'id': row.id,
              'tenantId': row.tenantId,
              'schoolId': row.schoolId,
              'name': row.name,
              'sortOrder': row.sortOrder,
              'serverRevision': row.serverRevision,
              'deleted': row.deleted,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      classArms: classArms
          .map(
            (row) => {
              'id': row.id,
              'tenantId': row.tenantId,
              'schoolId': row.schoolId,
              'classLevelId': row.classLevelId,
              'arm': row.arm,
              'displayName': row.displayName,
              'serverRevision': row.serverRevision,
              'deleted': row.deleted,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      subjects: subjects
          .map(
            (row) => {
              'id': row.id,
              'tenantId': row.tenantId,
              'schoolId': row.schoolId,
              'name': row.name,
              'code': row.code,
              'serverRevision': row.serverRevision,
              'deleted': row.deleted,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      gradingSchemes: await _loadLocalGradingSchemes(),
      trustedDevices: const [],
      auditEntries: const [],
    );
  }

  Map<String, dynamic> _gradingSchemeRowToMap(GradingSchemesCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'name': row.name,
      'bands': jsonDecode(row.bandsJson) as List<dynamic>,
      'isDefault': row.isDefault,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _academicYearRowToMap(AcademicYearsCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'label': row.label,
      'startDate': row.startDate,
      'endDate': row.endDate,
      'isCurrent': row.isCurrent,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _termRowToMap(TermsCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'academicYearId': row.academicYearId,
      'name': row.name,
      'termNumber': row.termNumber,
      'startDate': row.startDate,
      'endDate': row.endDate,
      'isCurrent': row.isCurrent,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _classLevelRowToMap(ClassLevelsCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'name': row.name,
      'sortOrder': row.sortOrder,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _classArmRowToMap(ClassArmsCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'classLevelId': row.classLevelId,
      'arm': row.arm,
      'displayName': row.displayName,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _subjectRowToMap(SubjectsCacheData row) {
    return {
      'id': row.id,
      'tenantId': row.tenantId,
      'schoolId': row.schoolId,
      'name': row.name,
      'code': row.code,
      'serverRevision': row.serverRevision,
      'deleted': row.deleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Future<AcademicYearsCacheData?> _findAcademicYear(String id) async {
    for (final row in await _db.getAcademicYears(scope: _scope)) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<TermsCacheData?> _findTerm(String id) async {
    for (final row in await _db.getTerms(scope: _scope)) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<ClassLevelsCacheData?> _findClassLevel(String id) async {
    for (final row in await _db.getClassLevels(scope: _scope)) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<ClassArmsCacheData?> _findClassArm(String id) async {
    for (final row in await _db.getClassArms(scope: _scope)) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<SubjectsCacheData?> _findSubject(String id) async {
    for (final row in await _db.getSubjects(scope: _scope)) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<void> _requireAcademicYear(String id) async {
    final row = await _findAcademicYear(id);
    if (row == null || row.deleted) {
      throw StateError('Academic year not found in the active local scope.');
    }
  }

  Future<void> _requireClassLevel(String id) async {
    final row = await _findClassLevel(id);
    if (row == null || row.deleted) {
      throw StateError('Class level not found in the active local scope.');
    }
  }

  Map<String, dynamic> _deletePayload(
    String id,
    int serverRevision,
    String updatedAt,
  ) {
    final user = _user;
    return {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'baseServerRevision': serverRevision,
      'baseUpdatedAt': updatedAt,
    };
  }

  Future<void> _persistRemoteAcademicYear(Map<String, dynamic> year) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'academic_year',
      record: year,
    )) {
      return;
    }
    await _db.upsertAcademicYear(
      AcademicYearsCacheCompanion(
        id: Value('${year['id']}'),
        tenantId: Value('${year['tenantId']}'),
        schoolId: Value('${year['schoolId']}'),
        label: Value('${year['label']}'),
        startDate: Value('${year['startDate']}'),
        endDate: Value('${year['endDate']}'),
        isCurrent: Value(year['isCurrent'] as bool? ?? false),
        serverRevision: Value(year['serverRevision'] as int? ?? 0),
        deleted: Value(year['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${year['createdAt']}')),
        updatedAt: Value(DateTime.parse('${year['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteTerm(Map<String, dynamic> term) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'term',
      record: term,
    )) {
      return;
    }
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
        serverRevision: Value(term['serverRevision'] as int? ?? 0),
        deleted: Value(term['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${term['createdAt']}')),
        updatedAt: Value(DateTime.parse('${term['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteClassLevel(Map<String, dynamic> level) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'class_level',
      record: level,
    )) {
      return;
    }
    await _db.upsertClassLevel(
      ClassLevelsCacheCompanion(
        id: Value('${level['id']}'),
        tenantId: Value('${level['tenantId']}'),
        schoolId: Value('${level['schoolId']}'),
        name: Value('${level['name']}'),
        sortOrder: Value(level['sortOrder'] as int? ?? 0),
        serverRevision: Value(level['serverRevision'] as int? ?? 0),
        deleted: Value(level['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${level['createdAt']}')),
        updatedAt: Value(DateTime.parse('${level['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteClassArm(Map<String, dynamic> arm) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'class_arm',
      record: arm,
    )) {
      return;
    }
    await _db.upsertClassArm(
      ClassArmsCacheCompanion(
        id: Value('${arm['id']}'),
        tenantId: Value('${arm['tenantId']}'),
        schoolId: Value('${arm['schoolId']}'),
        classLevelId: Value('${arm['classLevelId']}'),
        arm: Value('${arm['arm']}'),
        displayName: Value('${arm['displayName']}'),
        serverRevision: Value(arm['serverRevision'] as int? ?? 0),
        deleted: Value(arm['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${arm['createdAt']}')),
        updatedAt: Value(DateTime.parse('${arm['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteSubject(Map<String, dynamic> subject) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'subject',
      record: subject,
    )) {
      return;
    }
    await _db.upsertSubject(
      SubjectsCacheCompanion(
        id: Value('${subject['id']}'),
        tenantId: Value('${subject['tenantId']}'),
        schoolId: Value('${subject['schoolId']}'),
        name: Value('${subject['name']}'),
        code: Value(subject['code'] as String?),
        serverRevision: Value(subject['serverRevision'] as int? ?? 0),
        deleted: Value(subject['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${subject['createdAt']}')),
        updatedAt: Value(DateTime.parse('${subject['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteGradingScheme(Map<String, dynamic> scheme) async {
    if (await _shouldDeferRemoteAcademicRecord(
      entityType: 'grading_scheme',
      record: scheme,
    )) {
      return;
    }
    await _db.upsertGradingScheme(
      GradingSchemesCacheCompanion(
        id: Value('${scheme['id']}'),
        tenantId: Value('${scheme['tenantId']}'),
        schoolId: Value('${scheme['schoolId']}'),
        name: Value('${scheme['name']}'),
        bandsJson: Value(jsonEncode(scheme['bands'])),
        isDefault: Value(scheme['isDefault'] as bool? ?? false),
        serverRevision: Value(scheme['serverRevision'] as int? ?? 0),
        deleted: Value(scheme['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${scheme['createdAt']}')),
        updatedAt: Value(DateTime.parse('${scheme['updatedAt']}')),
      ),
    );
  }

  Future<bool> _shouldDeferRemoteAcademicRecord({
    required String entityType,
    required Map<String, dynamic> record,
  }) async {
    final entityId = '${record['id']}';
    final hasBlockingState = await _db.hasBlockingSyncStateForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    if (!hasBlockingState) {
      await _db.resolveOpenSyncConflictForEntity(
        tenantId: '${record['tenantId']}',
        schoolId: '${record['schoolId']}',
        campusId: record['campusId'] as String?,
        entityType: entityType,
        entityId: entityId,
        conflictType: 'pull_deferred',
      );
      return false;
    }

    await _db.recordSyncConflict(
      queueItemId: null,
      tenantId: '${record['tenantId']}',
      schoolId: '${record['schoolId']}',
      campusId: record['campusId'] as String?,
      entityType: entityType,
      entityId: entityId,
      operation: 'pull',
      conflictType: 'pull_deferred',
      payload: record,
      serverMessage:
          'Inbound academic sync was deferred because local unsynced work or an open conflict exists.',
      response: {
        'serverRevision': record['serverRevision'],
        'reason': 'blocking_local_sync_state',
      },
    );
    return true;
  }

  Future<void> _persistRemoteTenant(Map<String, dynamic> tenant) async {
    await _db.upsertTenantProfile(
      TenantProfileCacheCompanion(
        id: Value('${tenant['id']}'),
        name: Value('${tenant['name']}'),
        status: Value('${tenant['status']}'),
        contactEmail: Value(tenant['contactEmail'] as String?),
        contactPhone: Value(tenant['contactPhone'] as String?),
        deleted: Value(tenant['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${tenant['createdAt']}')),
        updatedAt: Value(DateTime.parse('${tenant['updatedAt']}')),
      ),
    );
  }

  Future<void> _persistRemoteSchool(Map<String, dynamic> school) async {
    final serverRevision = (school['serverRevision'] as num?)?.toInt() ?? 0;
    await _db.upsertSchoolProfile(
      SchoolProfileCacheCompanion(
        id: Value('${school['id']}'),
        tenantId: Value('${school['tenantId']}'),
        name: Value('${school['name']}'),
        shortName: Value(school['shortName'] as String?),
        schoolType: Value('${school['schoolType']}'),
        address: Value(school['address'] as String?),
        region: Value(school['region'] as String?),
        district: Value(school['district'] as String?),
        contactPhone: Value(school['contactPhone'] as String?),
        contactEmail: Value(school['contactEmail'] as String?),
        onboardingDefaultsJson:
            Value(jsonEncode(school['onboardingDefaults'] ?? const {})),
        serverRevision: Value(serverRevision),
        deleted: Value(school['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${school['createdAt']}')),
        updatedAt: Value(DateTime.parse('${school['updatedAt']}')),
      ),
    );
    if (serverRevision > 0) {
      await _db.updateLastRevision('school', serverRevision);
    }
  }

  Future<void> _persistRemoteCampus(Map<String, dynamic> campus) async {
    final serverRevision = (campus['serverRevision'] as num?)?.toInt() ?? 0;
    await _db.upsertCampusProfile(
      CampusProfileCacheCompanion(
        id: Value('${campus['id']}'),
        tenantId: Value('${campus['tenantId']}'),
        schoolId: Value('${campus['schoolId']}'),
        name: Value('${campus['name']}'),
        address: Value(campus['address'] as String?),
        contactPhone: Value(campus['contactPhone'] as String?),
        registrationCode: Value(campus['registrationCode'] as String?),
        serverRevision: Value(serverRevision),
        deleted: Value(campus['deleted'] as bool? ?? false),
        createdAt: Value(DateTime.parse('${campus['createdAt']}')),
        updatedAt: Value(DateTime.parse('${campus['updatedAt']}')),
      ),
    );
    if (serverRevision > 0) {
      await _db.updateLastRevision('campus', serverRevision);
    }
  }

  Future<Map<String, dynamic>> _updateLocalSchool({
    required String name,
    required String shortName,
    required String address,
    required String region,
    required String district,
    required String contactPhone,
    required String contactEmail,
  }) async {
    final user = _user;
    final existing = await _db.getSchoolProfile(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
    );
    if (existing == null) {
      throw StateError('School profile is not cached for offline update.');
    }

    final now = DateTime.now();
    await _db.upsertSchoolProfile(
      SchoolProfileCacheCompanion(
        id: Value(existing.id),
        tenantId: Value(existing.tenantId),
        name: Value(name),
        shortName: Value(_nullable(shortName)),
        schoolType: Value(existing.schoolType),
        address: Value(_nullable(address)),
        region: Value(_nullable(region)),
        district: Value(_nullable(district)),
        contactPhone: Value(_nullable(contactPhone)),
        contactEmail: Value(_nullable(contactEmail)),
        onboardingDefaultsJson: Value(existing.onboardingDefaultsJson),
        serverRevision: Value(existing.serverRevision),
        deleted: const Value(false),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
    await _db.enqueueSyncChange(
      entityType: 'school',
      entityId: existing.id,
      operation: 'update',
      payload: {
        'id': existing.id,
        'tenantId': existing.tenantId,
        'name': name,
        'shortName': _nullable(shortName),
        'schoolType': existing.schoolType,
        'address': _nullable(address),
        'region': _nullable(region),
        'district': _nullable(district),
        'contactPhone': _nullable(contactPhone),
        'contactEmail': _nullable(contactEmail),
        'onboardingDefaults':
            jsonDecode(existing.onboardingDefaultsJson) as Map<String, dynamic>,
        'baseServerRevision': existing.serverRevision,
        'baseUpdatedAt': existing.updatedAt.toIso8601String(),
      },
    );
    return {
      'id': existing.id,
      'tenantId': existing.tenantId,
      'name': name,
      'shortName': _nullable(shortName),
      'schoolType': existing.schoolType,
      'address': _nullable(address),
      'region': _nullable(region),
      'district': _nullable(district),
      'contactPhone': _nullable(contactPhone),
      'contactEmail': _nullable(contactEmail),
      'onboardingDefaults':
          jsonDecode(existing.onboardingDefaultsJson) as Map<String, dynamic>,
    };
  }

  Future<Map<String, dynamic>> _updateLocalCampus({
    required String name,
    required String address,
    required String contactPhone,
    required String registrationCode,
  }) async {
    final existing = await _db.getCampusProfile(scope: _scope);
    if (existing == null) {
      throw StateError('Campus profile is not cached for offline update.');
    }

    final now = DateTime.now();
    await _db.upsertCampusProfile(
      CampusProfileCacheCompanion(
        id: Value(existing.id),
        tenantId: Value(existing.tenantId),
        schoolId: Value(existing.schoolId),
        name: Value(name),
        address: Value(_nullable(address)),
        contactPhone: Value(_nullable(contactPhone)),
        registrationCode: Value(_nullable(registrationCode)),
        serverRevision: Value(existing.serverRevision),
        deleted: const Value(false),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
    await _db.enqueueSyncChange(
      entityType: 'campus',
      entityId: existing.id,
      operation: 'update',
      payload: {
        'id': existing.id,
        'tenantId': existing.tenantId,
        'schoolId': existing.schoolId,
        'name': name,
        'address': _nullable(address),
        'contactPhone': _nullable(contactPhone),
        'registrationCode': _nullable(registrationCode),
        'baseServerRevision': existing.serverRevision,
        'baseUpdatedAt': existing.updatedAt.toIso8601String(),
      },
    );
    return {
      'id': existing.id,
      'tenantId': existing.tenantId,
      'schoolId': existing.schoolId,
      'name': name,
      'address': _nullable(address),
      'contactPhone': _nullable(contactPhone),
      'registrationCode': _nullable(registrationCode),
    };
  }

  Future<Map<String, dynamic>> _createLocalAcademicYear({
    required String label,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'label': label,
      'startDate': startDate,
      'endDate': endDate,
      'isCurrent': isCurrent,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.transaction(() async {
      await _db.upsertAcademicYear(
        AcademicYearsCacheCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          label: Value(label),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'academic_year',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'label': label,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
        },
      );
    });
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalAcademicYear({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findAcademicYear(id);
    if (existing == null || existing.deleted) {
      throw StateError('Academic year not found in the active local scope.');
    }

    final now = DateTime.now();
    final label = '${data['label'] ?? existing.label}';
    final startDate = '${data['startDate'] ?? existing.startDate}';
    final endDate = '${data['endDate'] ?? existing.endDate}';
    final isCurrent = data['isCurrent'] as bool? ?? existing.isCurrent;
    await _db.transaction(() async {
      await _db.upsertAcademicYear(
        AcademicYearsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          label: Value(label),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'academic_year',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'label': label,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });
    return _academicYearRowToMap(existing).cast<String, dynamic>()
      ..addAll({
        'label': label,
        'startDate': startDate,
        'endDate': endDate,
        'isCurrent': isCurrent,
        'updatedAt': now.toIso8601String(),
      });
  }

  Future<void> _deleteLocalAcademicYear(
    String id, {
    bool enqueueDelete = true,
  }) async {
    final existing = await _findAcademicYear(id);
    if (existing == null || existing.deleted) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertAcademicYear(
        AcademicYearsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          label: Value(existing.label),
          startDate: Value(existing.startDate),
          endDate: Value(existing.endDate),
          isCurrent: Value(existing.isCurrent),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      if (enqueueDelete) {
        await _db.enqueueSyncChange(
          entityType: 'academic_year',
          entityId: existing.id,
          operation: 'delete',
          payload: _deletePayload(existing.id, existing.serverRevision,
              existing.updatedAt.toIso8601String()),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _createLocalTerm({
    required String academicYearId,
    required String name,
    required int termNumber,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
    await _requireAcademicYear(academicYearId);
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'academicYearId': academicYearId,
      'name': name,
      'termNumber': termNumber,
      'startDate': startDate,
      'endDate': endDate,
      'isCurrent': isCurrent,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.transaction(() async {
      await _db.upsertTerm(
        TermsCacheCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          academicYearId: Value(academicYearId),
          name: Value(name),
          termNumber: Value(termNumber),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'term',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'academicYearId': academicYearId,
          'name': name,
          'termNumber': termNumber,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
        },
      );
    });
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalTerm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findTerm(id);
    if (existing == null || existing.deleted) {
      throw StateError('Term not found in the active local scope.');
    }

    final academicYearId =
        '${data['academicYearId'] ?? existing.academicYearId}';
    await _requireAcademicYear(academicYearId);
    final now = DateTime.now();
    final name = '${data['name'] ?? existing.name}';
    final termNumber = data['termNumber'] as int? ?? existing.termNumber;
    final startDate = '${data['startDate'] ?? existing.startDate}';
    final endDate = '${data['endDate'] ?? existing.endDate}';
    final isCurrent = data['isCurrent'] as bool? ?? existing.isCurrent;
    await _db.transaction(() async {
      await _db.upsertTerm(
        TermsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          academicYearId: Value(academicYearId),
          name: Value(name),
          termNumber: Value(termNumber),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'term',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'academicYearId': academicYearId,
          'name': name,
          'termNumber': termNumber,
          'startDate': startDate,
          'endDate': endDate,
          'isCurrent': isCurrent,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });
    return _termRowToMap(existing).cast<String, dynamic>()
      ..addAll({
        'academicYearId': academicYearId,
        'name': name,
        'termNumber': termNumber,
        'startDate': startDate,
        'endDate': endDate,
        'isCurrent': isCurrent,
        'updatedAt': now.toIso8601String(),
      });
  }

  Future<void> _deleteLocalTerm(String id, {bool enqueueDelete = true}) async {
    final existing = await _findTerm(id);
    if (existing == null || existing.deleted) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertTerm(
        TermsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          academicYearId: Value(existing.academicYearId),
          name: Value(existing.name),
          termNumber: Value(existing.termNumber),
          startDate: Value(existing.startDate),
          endDate: Value(existing.endDate),
          isCurrent: Value(existing.isCurrent),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      if (enqueueDelete) {
        await _db.enqueueSyncChange(
          entityType: 'term',
          entityId: existing.id,
          operation: 'delete',
          payload: _deletePayload(existing.id, existing.serverRevision,
              existing.updatedAt.toIso8601String()),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _createLocalClassLevel({
    required String name,
    required int sortOrder,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'name': name,
      'sortOrder': sortOrder,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.transaction(() async {
      await _db.upsertClassLevel(
        ClassLevelsCacheCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          name: Value(name),
          sortOrder: Value(sortOrder),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'class_level',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'name': name,
          'sortOrder': sortOrder,
        },
      );
    });
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalClassLevel({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findClassLevel(id);
    if (existing == null || existing.deleted) {
      throw StateError('Class level not found in the active local scope.');
    }

    final now = DateTime.now();
    final name = '${data['name'] ?? existing.name}';
    final sortOrder = data['sortOrder'] as int? ?? existing.sortOrder;
    await _db.transaction(() async {
      await _db.upsertClassLevel(
        ClassLevelsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          name: Value(name),
          sortOrder: Value(sortOrder),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'class_level',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'name': name,
          'sortOrder': sortOrder,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });
    return _classLevelRowToMap(existing).cast<String, dynamic>()
      ..addAll({
        'name': name,
        'sortOrder': sortOrder,
        'updatedAt': now.toIso8601String(),
      });
  }

  Future<void> _deleteLocalClassLevel(
    String id, {
    bool enqueueDelete = true,
  }) async {
    final existing = await _findClassLevel(id);
    if (existing == null || existing.deleted) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertClassLevel(
        ClassLevelsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          name: Value(existing.name),
          sortOrder: Value(existing.sortOrder),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      if (enqueueDelete) {
        await _db.enqueueSyncChange(
          entityType: 'class_level',
          entityId: existing.id,
          operation: 'delete',
          payload: _deletePayload(existing.id, existing.serverRevision,
              existing.updatedAt.toIso8601String()),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _createLocalClassArm({
    required String classLevelId,
    required String arm,
    required String displayName,
  }) async {
    await _requireClassLevel(classLevelId);
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'classLevelId': classLevelId,
      'arm': arm,
      'displayName': displayName,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.transaction(() async {
      await _db.upsertClassArm(
        ClassArmsCacheCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          classLevelId: Value(classLevelId),
          arm: Value(arm),
          displayName: Value(displayName),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'class_arm',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'classLevelId': classLevelId,
          'arm': arm,
          'displayName': displayName,
        },
      );
    });
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalClassArm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findClassArm(id);
    if (existing == null || existing.deleted) {
      throw StateError('Class arm not found in the active local scope.');
    }

    final classLevelId = '${data['classLevelId'] ?? existing.classLevelId}';
    await _requireClassLevel(classLevelId);
    final now = DateTime.now();
    final arm = '${data['arm'] ?? existing.arm}';
    final displayName = '${data['displayName'] ?? existing.displayName}';
    await _db.transaction(() async {
      await _db.upsertClassArm(
        ClassArmsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          classLevelId: Value(classLevelId),
          arm: Value(arm),
          displayName: Value(displayName),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'class_arm',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'classLevelId': classLevelId,
          'arm': arm,
          'displayName': displayName,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });
    return _classArmRowToMap(existing).cast<String, dynamic>()
      ..addAll({
        'classLevelId': classLevelId,
        'arm': arm,
        'displayName': displayName,
        'updatedAt': now.toIso8601String(),
      });
  }

  Future<void> _deleteLocalClassArm(
    String id, {
    bool enqueueDelete = true,
  }) async {
    final existing = await _findClassArm(id);
    if (existing == null || existing.deleted) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertClassArm(
        ClassArmsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          classLevelId: Value(existing.classLevelId),
          arm: Value(existing.arm),
          displayName: Value(existing.displayName),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      if (enqueueDelete) {
        await _db.enqueueSyncChange(
          entityType: 'class_arm',
          entityId: existing.id,
          operation: 'delete',
          payload: _deletePayload(existing.id, existing.serverRevision,
              existing.updatedAt.toIso8601String()),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _createLocalSubject({
    required String name,
    required String code,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final normalizedCode = _nullable(code);
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'name': name,
      'code': normalizedCode,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.transaction(() async {
      await _db.upsertSubject(
        SubjectsCacheCompanion(
          id: Value(id),
          tenantId: Value(user.tenantId!),
          schoolId: Value(user.schoolId!),
          name: Value(name),
          code: Value(normalizedCode),
          serverRevision: const Value(0),
          deleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'subject',
        entityId: id,
        operation: 'create',
        payload: {
          'id': id,
          'tenantId': user.tenantId,
          'schoolId': user.schoolId,
          'name': name,
          'code': normalizedCode,
        },
      );
    });
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalSubject({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findSubject(id);
    if (existing == null || existing.deleted) {
      throw StateError('Subject not found in the active local scope.');
    }

    final now = DateTime.now();
    final name = '${data['name'] ?? existing.name}';
    final code =
        data.containsKey('code') ? data['code'] as String? : existing.code;
    await _db.transaction(() async {
      await _db.upsertSubject(
        SubjectsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          name: Value(name),
          code: Value(code),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(false),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      await _db.enqueueSyncChange(
        entityType: 'subject',
        entityId: existing.id,
        operation: 'update',
        payload: {
          'id': existing.id,
          'tenantId': existing.tenantId,
          'schoolId': existing.schoolId,
          'name': name,
          'code': code,
          'baseServerRevision': existing.serverRevision,
          'baseUpdatedAt': existing.updatedAt.toIso8601String(),
        },
      );
    });
    return _subjectRowToMap(existing).cast<String, dynamic>()
      ..addAll({
        'name': name,
        'code': code,
        'updatedAt': now.toIso8601String(),
      });
  }

  Future<void> _deleteLocalSubject(
    String id, {
    bool enqueueDelete = true,
  }) async {
    final existing = await _findSubject(id);
    if (existing == null || existing.deleted) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.upsertSubject(
        SubjectsCacheCompanion(
          id: Value(existing.id),
          tenantId: Value(existing.tenantId),
          schoolId: Value(existing.schoolId),
          name: Value(existing.name),
          code: Value(existing.code),
          serverRevision: Value(existing.serverRevision),
          deleted: const Value(true),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      if (enqueueDelete) {
        await _db.enqueueSyncChange(
          entityType: 'subject',
          entityId: existing.id,
          operation: 'delete',
          payload: _deletePayload(existing.id, existing.serverRevision,
              existing.updatedAt.toIso8601String()),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _createLocalGradingScheme({
    required String name,
    required List<Map<String, dynamic>> bands,
    required bool isDefault,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final user = _user;
    final record = {
      'id': id,
      'tenantId': user.tenantId,
      'schoolId': user.schoolId,
      'name': name,
      'bands': bands,
      'isDefault': isDefault,
      'serverRevision': 0,
      'deleted': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _db.upsertGradingScheme(
      GradingSchemesCacheCompanion(
        id: Value(id),
        tenantId: Value(user.tenantId!),
        schoolId: Value(user.schoolId!),
        name: Value(name),
        bandsJson: Value(jsonEncode(bands)),
        isDefault: Value(isDefault),
        serverRevision: const Value(0),
        deleted: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _db.enqueueSyncChange(
      entityType: 'grading_scheme',
      entityId: id,
      operation: 'create',
      payload: {
        'id': id,
        'tenantId': user.tenantId,
        'schoolId': user.schoolId,
        'name': name,
        'bands': bands,
        'isDefault': isDefault,
      },
    );
    return record;
  }

  Future<Map<String, dynamic>> _updateLocalGradingScheme({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _db.findGradingSchemeById(
      scope: _scope,
      gradingSchemeId: id,
    );
    if (existing == null || existing.deleted) {
      throw StateError('Grading scheme not found in the active local scope.');
    }

    final now = DateTime.now();
    final updatedName = '${data['name'] ?? existing.name}';
    final updatedBands = (data['bands'] as List<dynamic>? ??
        jsonDecode(
          existing.bandsJson,
        ) as List<dynamic>);
    final updatedIsDefault = data['isDefault'] as bool? ?? existing.isDefault;
    await _db.upsertGradingScheme(
      GradingSchemesCacheCompanion(
        id: Value(existing.id),
        tenantId: Value(existing.tenantId),
        schoolId: Value(existing.schoolId),
        name: Value(updatedName),
        bandsJson: Value(jsonEncode(updatedBands)),
        isDefault: Value(updatedIsDefault),
        serverRevision: Value(existing.serverRevision),
        deleted: const Value(false),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
    await _db.enqueueSyncChange(
      entityType: 'grading_scheme',
      entityId: existing.id,
      operation: 'update',
      payload: {
        'id': existing.id,
        'tenantId': existing.tenantId,
        'schoolId': existing.schoolId,
        'name': updatedName,
        'bands': updatedBands,
        'isDefault': updatedIsDefault,
        'baseServerRevision': existing.serverRevision,
        'baseUpdatedAt': existing.updatedAt.toIso8601String(),
      },
    );

    return {
      'id': existing.id,
      'tenantId': existing.tenantId,
      'schoolId': existing.schoolId,
      'name': updatedName,
      'bands': updatedBands,
      'isDefault': updatedIsDefault,
      'serverRevision': existing.serverRevision,
      'deleted': false,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
  }

  Future<void> _deleteLocalGradingScheme(
    String id, {
    bool enqueueDelete = true,
  }) async {
    final existing = await _db.findGradingSchemeById(
      scope: _scope,
      gradingSchemeId: id,
    );
    if (existing == null || existing.deleted) {
      return;
    }

    final now = DateTime.now();
    await _db.upsertGradingScheme(
      GradingSchemesCacheCompanion(
        id: Value(existing.id),
        tenantId: Value(existing.tenantId),
        schoolId: Value(existing.schoolId),
        name: Value(existing.name),
        bandsJson: Value(existing.bandsJson),
        isDefault: Value(existing.isDefault),
        serverRevision: Value(existing.serverRevision),
        deleted: const Value(true),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    if (!enqueueDelete) {
      return;
    }

    await _db.enqueueSyncChange(
      entityType: 'grading_scheme',
      entityId: existing.id,
      operation: 'delete',
      payload: {
        'id': existing.id,
        'tenantId': existing.tenantId,
        'schoolId': existing.schoolId,
        'baseServerRevision': existing.serverRevision,
        'baseUpdatedAt': existing.updatedAt.toIso8601String(),
      },
    );
  }

  bool _isConnectivityFailure(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }
}
