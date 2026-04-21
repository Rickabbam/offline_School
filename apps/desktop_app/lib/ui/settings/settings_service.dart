import 'package:dio/dio.dart';

import '../../auth/auth_service.dart';

class SettingsWorkspaceData {
  const SettingsWorkspaceData({
    required this.school,
    required this.campus,
    required this.academicYears,
    required this.terms,
    required this.classLevels,
    required this.classArms,
    required this.subjects,
    required this.gradingSchemes,
  });

  final Map<String, dynamic> school;
  final Map<String, dynamic> campus;
  final List<Map<String, dynamic>> academicYears;
  final List<Map<String, dynamic>> terms;
  final List<Map<String, dynamic>> classLevels;
  final List<Map<String, dynamic>> classArms;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> gradingSchemes;
}

class SettingsService {
  SettingsService(this._auth);

  final AuthService _auth;

  Dio get _client => _auth.createAuthenticatedClient();

  AuthUser get _user {
    final user = _auth.currentUser;
    if (user == null || user.schoolId == null || user.campusId == null) {
      throw StateError('School workspace is not available for this session.');
    }
    return user;
  }

  Future<SettingsWorkspaceData> loadWorkspace() async {
    final user = _user;
    final schoolResponse = await _client.get<Map<String, dynamic>>('/schools/${user.schoolId}');
    final campusResponse = await _client.get<Map<String, dynamic>>('/campuses/${user.campusId}');
    final yearsResponse = await _client.get<List<dynamic>>('/academic/years');
    final termsResponse = await _client.get<List<dynamic>>('/academic/terms');
    final classLevelsResponse = await _client.get<List<dynamic>>('/academic/class-levels');
    final classArmsResponse = await _client.get<List<dynamic>>('/academic/class-arms');
    final subjectsResponse = await _client.get<List<dynamic>>('/academic/subjects');
    final gradingSchemesResponse = await _client.get<List<dynamic>>('/academic/grading-schemes');

    return SettingsWorkspaceData(
      school: Map<String, dynamic>.from(schoolResponse.data!),
      campus: Map<String, dynamic>.from(campusResponse.data!),
      academicYears: _asListOfMaps(yearsResponse.data),
      terms: _asListOfMaps(termsResponse.data),
      classLevels: _asListOfMaps(classLevelsResponse.data),
      classArms: _asListOfMaps(classArmsResponse.data),
      subjects: _asListOfMaps(subjectsResponse.data),
      gradingSchemes: _asListOfMaps(gradingSchemesResponse.data),
    );
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
    final user = _user;
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
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateCampus({
    required String name,
    required String address,
    required String contactPhone,
    required String registrationCode,
  }) async {
    final user = _user;
    final response = await _client.patch<Map<String, dynamic>>(
      '/campuses/${user.campusId}',
      data: {
        'name': name,
        'address': _nullable(address),
        'contactPhone': _nullable(contactPhone),
        'registrationCode': _nullable(registrationCode),
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> createAcademicYear({
    required String label,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/academic/years',
      data: {
        'label': label,
        'startDate': startDate,
        'endDate': endDate,
        'isCurrent': isCurrent,
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateAcademicYear({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/years/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteAcademicYear(String id) async {
    await _client.delete<void>('/academic/years/$id');
  }

  Future<Map<String, dynamic>> createClassLevel({
    required String name,
    required int sortOrder,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/academic/class-levels',
      data: {
        'name': name,
        'sortOrder': sortOrder,
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateClassLevel({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/class-levels/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteClassLevel(String id) async {
    await _client.delete<void>('/academic/class-levels/$id');
  }

  Future<Map<String, dynamic>> createTerm({
    required String academicYearId,
    required String name,
    required int termNumber,
    required String startDate,
    required String endDate,
    required bool isCurrent,
  }) async {
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
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateTerm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/terms/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteTerm(String id) async {
    await _client.delete<void>('/academic/terms/$id');
  }

  Future<Map<String, dynamic>> createClassArm({
    required String classLevelId,
    required String arm,
    required String displayName,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/academic/class-arms',
      data: {
        'classLevelId': classLevelId,
        'arm': arm,
        'displayName': displayName,
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateClassArm({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/class-arms/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteClassArm(String id) async {
    await _client.delete<void>('/academic/class-arms/$id');
  }

  Future<Map<String, dynamic>> createSubject({
    required String name,
    required String code,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/academic/subjects',
      data: {
        'name': name,
        'code': _nullable(code),
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateSubject({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/subjects/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteSubject(String id) async {
    await _client.delete<void>('/academic/subjects/$id');
  }

  Future<Map<String, dynamic>> createGradingScheme({
    required String name,
    required List<Map<String, dynamic>> bands,
    required bool isDefault,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/academic/grading-schemes',
      data: {
        'name': name,
        'bands': bands,
        'isDefault': isDefault,
      },
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> updateGradingScheme({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/academic/grading-schemes/$id',
      data: data,
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> deleteGradingScheme(String id) async {
    await _client.delete<void>('/academic/grading-schemes/$id');
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
}
