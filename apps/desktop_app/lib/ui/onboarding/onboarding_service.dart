import 'package:dio/dio.dart';

import '../../auth/auth_service.dart';
import 'onboarding_models.dart';

class OnboardingService {
  OnboardingService(this._auth);

  final AuthService _auth;

  Future<AuthUser> bootstrapSchool(OnboardingDraft draft) async {
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
                'arms': level.arms
                    .map((arm) => {'arm': arm})
                    .toList(),
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
      },
    );

    final userJson = response.data?['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Bootstrap response did not include user context.',
      );
    }

    return _auth.updateCurrentUserFromJson(userJson);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
