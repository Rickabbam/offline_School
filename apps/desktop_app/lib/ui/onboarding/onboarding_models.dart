class SchoolProfileDraft {
  const SchoolProfileDraft({
    this.name = '',
    this.shortName = '',
    this.schoolType = 'basic',
    this.address = '',
    this.region = '',
    this.district = '',
    this.contactPhone = '',
    this.contactEmail = '',
  });

  final String name;
  final String shortName;
  final String schoolType;
  final String address;
  final String region;
  final String district;
  final String contactPhone;
  final String contactEmail;

  SchoolProfileDraft copyWith({
    String? name,
    String? shortName,
    String? schoolType,
    String? address,
    String? region,
    String? district,
    String? contactPhone,
    String? contactEmail,
  }) {
    return SchoolProfileDraft(
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      schoolType: schoolType ?? this.schoolType,
      address: address ?? this.address,
      region: region ?? this.region,
      district: district ?? this.district,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
    );
  }
}

class CampusSetupDraft {
  const CampusSetupDraft({
    this.name = '',
    this.address = '',
    this.contactPhone = '',
    this.registrationCode = '',
    this.isPrimaryCampus = true,
  });

  final String name;
  final String address;
  final String contactPhone;
  final String registrationCode;
  final bool isPrimaryCampus;

  CampusSetupDraft copyWith({
    String? name,
    String? address,
    String? contactPhone,
    String? registrationCode,
    bool? isPrimaryCampus,
  }) {
    return CampusSetupDraft(
      name: name ?? this.name,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      registrationCode: registrationCode ?? this.registrationCode,
      isPrimaryCampus: isPrimaryCampus ?? this.isPrimaryCampus,
    );
  }
}

class AcademicTermDraft {
  const AcademicTermDraft({
    required this.name,
    required this.termNumber,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
  });

  final String name;
  final int termNumber;
  final String startDate;
  final String endDate;
  final bool isCurrent;

  AcademicTermDraft copyWith({
    String? name,
    int? termNumber,
    String? startDate,
    String? endDate,
    bool? isCurrent,
  }) {
    return AcademicTermDraft(
      name: name ?? this.name,
      termNumber: termNumber ?? this.termNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class AcademicYearDraft {
  const AcademicYearDraft({
    this.label = '',
    this.startDate = '',
    this.endDate = '',
    this.terms = const [],
  });

  final String label;
  final String startDate;
  final String endDate;
  final List<AcademicTermDraft> terms;

  AcademicYearDraft copyWith({
    String? label,
    String? startDate,
    String? endDate,
    List<AcademicTermDraft>? terms,
  }) {
    return AcademicYearDraft(
      label: label ?? this.label,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      terms: terms ?? this.terms,
    );
  }
}

class ClassLevelDraft {
  const ClassLevelDraft({
    required this.name,
    required this.sortOrder,
    required this.arms,
  });

  final String name;
  final int sortOrder;
  final List<String> arms;
}

class SubjectDraft {
  const SubjectDraft({
    required this.name,
    this.code = '',
  });

  final String name;
  final String code;
}

class ClassSetupDraft {
  const ClassSetupDraft({
    this.levels = const [],
    this.subjects = const [],
  });

  final List<ClassLevelDraft> levels;
  final List<SubjectDraft> subjects;

  ClassSetupDraft copyWith({
    List<ClassLevelDraft>? levels,
    List<SubjectDraft>? subjects,
  }) {
    return ClassSetupDraft(
      levels: levels ?? this.levels,
      subjects: subjects ?? this.subjects,
    );
  }
}

class GradeBandDraft {
  const GradeBandDraft({
    required this.grade,
    required this.min,
    required this.max,
    required this.remark,
  });

  final String grade;
  final int min;
  final int max;
  final String remark;
}

class GradingSchemeDraft {
  const GradingSchemeDraft({
    this.name = '',
    this.bands = const [],
  });

  final String name;
  final List<GradeBandDraft> bands;

  GradingSchemeDraft copyWith({
    String? name,
    List<GradeBandDraft>? bands,
  }) {
    return GradingSchemeDraft(
      name: name ?? this.name,
      bands: bands ?? this.bands,
    );
  }
}

class OnboardingDraft {
  const OnboardingDraft({
    this.school = const SchoolProfileDraft(),
    this.campus = const CampusSetupDraft(),
    this.academicYear = const AcademicYearDraft(),
    this.classSetup = const ClassSetupDraft(),
    this.gradingScheme = const GradingSchemeDraft(),
  });

  final SchoolProfileDraft school;
  final CampusSetupDraft campus;
  final AcademicYearDraft academicYear;
  final ClassSetupDraft classSetup;
  final GradingSchemeDraft gradingScheme;

  OnboardingDraft copyWith({
    SchoolProfileDraft? school,
    CampusSetupDraft? campus,
    AcademicYearDraft? academicYear,
    ClassSetupDraft? classSetup,
    GradingSchemeDraft? gradingScheme,
  }) {
    return OnboardingDraft(
      school: school ?? this.school,
      campus: campus ?? this.campus,
      academicYear: academicYear ?? this.academicYear,
      classSetup: classSetup ?? this.classSetup,
      gradingScheme: gradingScheme ?? this.gradingScheme,
    );
  }
}
