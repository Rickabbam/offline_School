import 'package:dio/dio.dart';

import 'package:desktop_app/auth/auth_service.dart';

class AttendanceWorkspaceData {
  const AttendanceWorkspaceData({
    required this.classArms,
    required this.currentAcademicYearId,
    required this.currentAcademicYearLabel,
    required this.currentTermId,
    required this.currentTermLabel,
  });

  final List<Map<String, dynamic>> classArms;
  final String? currentAcademicYearId;
  final String? currentAcademicYearLabel;
  final String? currentTermId;
  final String? currentTermLabel;
}

class AttendanceWorkspaceService {
  AttendanceWorkspaceService(this._auth);

  final AuthService _auth;

  Dio get _client => _auth.createAuthenticatedClient();

  Future<AttendanceWorkspaceData> loadWorkspace() async {
    final yearsResponse = await _client.get<List<dynamic>>('/academic/years');
    final termsResponse = await _client.get<List<dynamic>>('/academic/terms');
    final classArmsResponse =
        await _client.get<List<dynamic>>('/academic/class-arms');

    final years = _asListOfMaps(yearsResponse.data);
    final terms = _asListOfMaps(termsResponse.data);
    final classArms = _asListOfMaps(classArmsResponse.data)
      ..sort((a, b) => _labelForClassArm(a).compareTo(_labelForClassArm(b)));

    final currentYear = _findCurrent(years);
    final currentYearId = currentYear == null ? null : '${currentYear['id']}';
    final currentTerm = _findCurrent(
      terms.where((term) {
        if (currentYearId == null) {
          return true;
        }
        return '${term['academicYearId']}' == currentYearId;
      }).toList(growable: false),
    );

    return AttendanceWorkspaceData(
      classArms: classArms,
      currentAcademicYearId: currentYearId,
      currentAcademicYearLabel:
          currentYear == null ? null : '${currentYear['label']}',
      currentTermId: currentTerm == null ? null : '${currentTerm['id']}',
      currentTermLabel: currentTerm == null ? null : '${currentTerm['name']}',
    );
  }

  List<Map<String, dynamic>> _asListOfMaps(List<dynamic>? raw) {
    return (raw ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Map<String, dynamic>? _findCurrent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item['isCurrent'] == true) {
        return item;
      }
    }
    return items.first;
  }

  static String labelForClassArm(Map<String, dynamic> item) =>
      _labelForClassArm(item);

  static String _labelForClassArm(Map<String, dynamic> item) {
    final displayName = '${item['displayName'] ?? ''}'.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return '${item['arm'] ?? item['id'] ?? 'Class'}';
  }
}
