import 'package:dio/dio.dart';

import '../../auth/auth_service.dart';

class ReportsWorkspaceData {
  const ReportsWorkspaceData({
    required this.summaryCounts,
    required this.admissionStatusCounts,
    required this.currentAcademicYears,
    required this.availableSections,
  });

  final Map<String, int> summaryCounts;
  final Map<String, int> admissionStatusCounts;
  final List<String> currentAcademicYears;
  final List<String> availableSections;
}

class ReportsService {
  ReportsService(this._auth);

  final AuthService _auth;

  Dio get _client => _auth.createAuthenticatedClient();

  AuthUser get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user available.');
    }
    return user;
  }

  Future<ReportsWorkspaceData> loadWorkspace() async {
    final user = _user;
    final summaryCounts = <String, int>{};
    final admissionStatusCounts = <String, int>{};
    final currentAcademicYears = <String>[];
    final availableSections = <String>[];

    if (_canViewStudentData(user)) {
      final students = await _client.get<List<dynamic>>('/students');
      final admissions = await _client.get<List<dynamic>>('/admissions');
      final academicYears = await _client.get<List<dynamic>>('/academic/years');

      summaryCounts['Students'] = (students.data ?? const []).length;
      summaryCounts['Applicants'] = (admissions.data ?? const []).length;
      currentAcademicYears.addAll(
        (academicYears.data ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['isCurrent'] == true)
            .map((item) => '${item['label']}')
            .toList(growable: false),
      );

      for (final status in const [
        'applied',
        'screened',
        'admitted',
        'enrolled',
        'rejected',
        'withdrawn',
      ]) {
        final response = await _client.get<List<dynamic>>(
          '/admissions',
          queryParameters: {'status': status},
        );
        admissionStatusCounts[_titleCase(status)] = (response.data ?? const []).length;
      }

      availableSections.addAll(['Students', 'Admissions', 'Academic Years']);
    }

    if (user.role == 'admin') {
      final staff = await _client.get<List<dynamic>>('/staff');
      summaryCounts['Staff'] = (staff.data ?? const []).length;
      availableSections.add('Staff');
    }

    if (user.role == 'support_admin') {
      final schools = await _client.get<List<dynamic>>('/schools');
      final campuses = await _client.get<List<dynamic>>('/campuses');
      summaryCounts['Schools'] = (schools.data ?? const []).length;
      summaryCounts['Campuses'] = (campuses.data ?? const []).length;
      availableSections.addAll(['Schools', 'Campuses']);
    }

    return ReportsWorkspaceData(
      summaryCounts: summaryCounts,
      admissionStatusCounts: admissionStatusCounts,
      currentAcademicYears: currentAcademicYears,
      availableSections: availableSections,
    );
  }

  bool _canViewStudentData(AuthUser user) {
    return switch (user.role) {
      'admin' || 'teacher' => true,
      _ => false,
    };
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
