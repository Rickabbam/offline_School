import 'package:desktop_app/database/app_database.dart';

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
  AttendanceWorkspaceService(this._db);

  final AppDatabase _db;

  Future<AttendanceWorkspaceData> loadWorkspace(LocalDataScope scope) async {
    final years = (await _db.getAcademicYears(scope: scope))
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'label': item.label,
            'isCurrent': item.isCurrent,
          },
        )
        .toList(growable: false);
    final currentYear = _findCurrent(years);
    final currentYearId = currentYear == null ? null : '${currentYear['id']}';
    final terms = (await _db.getTerms(scope: scope, academicYearId: currentYearId))
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'academicYearId': item.academicYearId,
            'name': item.name,
            'termNumber': item.termNumber,
            'isCurrent': item.isCurrent,
          },
        )
        .toList(growable: false);
    final classArms = (await _db.getClassArms(scope: scope))
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'classLevelId': item.classLevelId,
            'arm': item.arm,
            'displayName': item.displayName,
          },
        )
        .toList(growable: false)
      ..sort((a, b) => _labelForClassArm(a).compareTo(_labelForClassArm(b)));
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
