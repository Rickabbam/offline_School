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

  Map<String, dynamic> toJson() => {
        'name': name,
        'shortName': shortName,
        'schoolType': schoolType,
        'address': address,
        'region': region,
        'district': district,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
      };

  factory SchoolProfileDraft.fromJson(Map<String, dynamic> json) =>
      SchoolProfileDraft(
        name: json['name'] as String? ?? '',
        shortName: json['shortName'] as String? ?? '',
        schoolType: json['schoolType'] as String? ?? 'basic',
        address: json['address'] as String? ?? '',
        region: json['region'] as String? ?? '',
        district: json['district'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        contactEmail: json['contactEmail'] as String? ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'contactPhone': contactPhone,
        'registrationCode': registrationCode,
        'isPrimaryCampus': isPrimaryCampus,
      };

  factory CampusSetupDraft.fromJson(Map<String, dynamic> json) =>
      CampusSetupDraft(
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        registrationCode: json['registrationCode'] as String? ?? '',
        isPrimaryCampus: json['isPrimaryCampus'] as bool? ?? true,
      );
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'termNumber': termNumber,
        'startDate': startDate,
        'endDate': endDate,
        'isCurrent': isCurrent,
      };

  factory AcademicTermDraft.fromJson(Map<String, dynamic> json) =>
      AcademicTermDraft(
        name: json['name'] as String? ?? '',
        termNumber: json['termNumber'] as int? ?? 1,
        startDate: json['startDate'] as String? ?? '',
        endDate: json['endDate'] as String? ?? '',
        isCurrent: json['isCurrent'] as bool? ?? false,
      );
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

  Map<String, dynamic> toJson() => {
        'label': label,
        'startDate': startDate,
        'endDate': endDate,
        'terms': terms.map((term) => term.toJson()).toList(),
      };

  factory AcademicYearDraft.fromJson(Map<String, dynamic> json) =>
      AcademicYearDraft(
        label: json['label'] as String? ?? '',
        startDate: json['startDate'] as String? ?? '',
        endDate: json['endDate'] as String? ?? '',
        terms: (json['terms'] as List<dynamic>? ?? const [])
            .map((item) =>
                AcademicTermDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'sortOrder': sortOrder,
        'arms': arms,
      };

  factory ClassLevelDraft.fromJson(Map<String, dynamic> json) =>
      ClassLevelDraft(
        name: json['name'] as String? ?? '',
        sortOrder: json['sortOrder'] as int? ?? 0,
        arms: (json['arms'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(),
      );
}

class SubjectDraft {
  const SubjectDraft({
    required this.name,
    this.code = '',
  });

  final String name;
  final String code;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
      };

  factory SubjectDraft.fromJson(Map<String, dynamic> json) => SubjectDraft(
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'levels': levels.map((level) => level.toJson()).toList(),
        'subjects': subjects.map((subject) => subject.toJson()).toList(),
      };

  factory ClassSetupDraft.fromJson(Map<String, dynamic> json) =>
      ClassSetupDraft(
        levels: (json['levels'] as List<dynamic>? ?? const [])
            .map((item) =>
                ClassLevelDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
        subjects: (json['subjects'] as List<dynamic>? ?? const [])
            .map((item) => SubjectDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
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

  Map<String, dynamic> toJson() => {
        'grade': grade,
        'min': min,
        'max': max,
        'remark': remark,
      };

  factory GradeBandDraft.fromJson(Map<String, dynamic> json) => GradeBandDraft(
        grade: json['grade'] as String? ?? '',
        min: json['min'] as int? ?? 0,
        max: json['max'] as int? ?? 0,
        remark: json['remark'] as String? ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'bands': bands.map((band) => band.toJson()).toList(),
      };

  factory GradingSchemeDraft.fromJson(Map<String, dynamic> json) =>
      GradingSchemeDraft(
        name: json['name'] as String? ?? '',
        bands: (json['bands'] as List<dynamic>? ?? const [])
            .map(
                (item) => GradeBandDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class StaffRoleDraft {
  const StaffRoleDraft({
    required this.role,
    this.enabled = false,
    this.headcount = 0,
  });

  final String role;
  final bool enabled;
  final int headcount;

  StaffRoleDraft copyWith({
    String? role,
    bool? enabled,
    int? headcount,
  }) {
    return StaffRoleDraft(
      role: role ?? this.role,
      enabled: enabled ?? this.enabled,
      headcount: headcount ?? this.headcount,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'enabled': enabled,
        'headcount': headcount,
      };

  factory StaffRoleDraft.fromJson(Map<String, dynamic> json) => StaffRoleDraft(
        role: json['role'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        headcount: json['headcount'] as int? ?? 0,
      );
}

class FeeCategoryDraft {
  const FeeCategoryDraft({
    required this.name,
    this.defaultAmount = 0,
    this.billingTerm = 'per_term',
  });

  final String name;
  final double defaultAmount;
  final String billingTerm;

  FeeCategoryDraft copyWith({
    String? name,
    double? defaultAmount,
    String? billingTerm,
  }) {
    return FeeCategoryDraft(
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      billingTerm: billingTerm ?? this.billingTerm,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'defaultAmount': defaultAmount,
        'billingTerm': billingTerm,
      };

  factory FeeCategoryDraft.fromJson(Map<String, dynamic> json) =>
      FeeCategoryDraft(
        name: json['name'] as String? ?? '',
        defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 0,
        billingTerm: json['billingTerm'] as String? ?? 'per_term',
      );
}

class ReceiptFormatDraft {
  const ReceiptFormatDraft({
    this.headerLine1 = '',
    this.headerLine2 = '',
    this.footerNote = '',
    this.receiptPrefix = 'RCP',
    this.nextReceiptNumber = 1,
  });

  final String headerLine1;
  final String headerLine2;
  final String footerNote;
  final String receiptPrefix;
  final int nextReceiptNumber;

  ReceiptFormatDraft copyWith({
    String? headerLine1,
    String? headerLine2,
    String? footerNote,
    String? receiptPrefix,
    int? nextReceiptNumber,
  }) {
    return ReceiptFormatDraft(
      headerLine1: headerLine1 ?? this.headerLine1,
      headerLine2: headerLine2 ?? this.headerLine2,
      footerNote: footerNote ?? this.footerNote,
      receiptPrefix: receiptPrefix ?? this.receiptPrefix,
      nextReceiptNumber: nextReceiptNumber ?? this.nextReceiptNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'headerLine1': headerLine1,
        'headerLine2': headerLine2,
        'footerNote': footerNote,
        'receiptPrefix': receiptPrefix,
        'nextReceiptNumber': nextReceiptNumber,
      };

  factory ReceiptFormatDraft.fromJson(Map<String, dynamic> json) =>
      ReceiptFormatDraft(
        headerLine1: json['headerLine1'] as String? ?? '',
        headerLine2: json['headerLine2'] as String? ?? '',
        footerNote: json['footerNote'] as String? ?? '',
        receiptPrefix: json['receiptPrefix'] as String? ?? 'RCP',
        nextReceiptNumber: json['nextReceiptNumber'] as int? ?? 1,
      );
}

class NotificationSettingsDraft {
  const NotificationSettingsDraft({
    this.smsEnabled = false,
    this.paymentReceiptsEnabled = true,
    this.feeRemindersEnabled = true,
    this.senderId = '',
    this.providerName = '',
  });

  final bool smsEnabled;
  final bool paymentReceiptsEnabled;
  final bool feeRemindersEnabled;
  final String senderId;
  final String providerName;

  NotificationSettingsDraft copyWith({
    bool? smsEnabled,
    bool? paymentReceiptsEnabled,
    bool? feeRemindersEnabled,
    String? senderId,
    String? providerName,
  }) {
    return NotificationSettingsDraft(
      smsEnabled: smsEnabled ?? this.smsEnabled,
      paymentReceiptsEnabled:
          paymentReceiptsEnabled ?? this.paymentReceiptsEnabled,
      feeRemindersEnabled: feeRemindersEnabled ?? this.feeRemindersEnabled,
      senderId: senderId ?? this.senderId,
      providerName: providerName ?? this.providerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'smsEnabled': smsEnabled,
        'paymentReceiptsEnabled': paymentReceiptsEnabled,
        'feeRemindersEnabled': feeRemindersEnabled,
        'senderId': senderId,
        'providerName': providerName,
      };

  factory NotificationSettingsDraft.fromJson(Map<String, dynamic> json) =>
      NotificationSettingsDraft(
        smsEnabled: json['smsEnabled'] as bool? ?? false,
        paymentReceiptsEnabled: json['paymentReceiptsEnabled'] as bool? ?? true,
        feeRemindersEnabled: json['feeRemindersEnabled'] as bool? ?? true,
        senderId: json['senderId'] as String? ?? '',
        providerName: json['providerName'] as String? ?? '',
      );
}

class DeviceRegistrationDraft {
  const DeviceRegistrationDraft({
    this.deviceName = '',
    this.registerOfflineAccess = true,
    this.isRegistered = false,
  });

  final String deviceName;
  final bool registerOfflineAccess;
  final bool isRegistered;

  DeviceRegistrationDraft copyWith({
    String? deviceName,
    bool? registerOfflineAccess,
    bool? isRegistered,
  }) {
    return DeviceRegistrationDraft(
      deviceName: deviceName ?? this.deviceName,
      registerOfflineAccess:
          registerOfflineAccess ?? this.registerOfflineAccess,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'registerOfflineAccess': registerOfflineAccess,
        'isRegistered': isRegistered,
      };

  factory DeviceRegistrationDraft.fromJson(Map<String, dynamic> json) =>
      DeviceRegistrationDraft(
        deviceName: json['deviceName'] as String? ?? '',
        registerOfflineAccess: json['registerOfflineAccess'] as bool? ?? true,
        isRegistered: json['isRegistered'] as bool? ?? false,
      );
}

class OnboardingDraft {
  const OnboardingDraft({
    this.school = const SchoolProfileDraft(),
    this.campus = const CampusSetupDraft(),
    this.academicYear = const AcademicYearDraft(),
    this.classSetup = const ClassSetupDraft(),
    this.gradingScheme = const GradingSchemeDraft(),
    this.staffRoles = const [],
    this.feeCategories = const [],
    this.receiptFormat = const ReceiptFormatDraft(),
    this.notifications = const NotificationSettingsDraft(),
    this.deviceRegistration = const DeviceRegistrationDraft(),
  });

  final SchoolProfileDraft school;
  final CampusSetupDraft campus;
  final AcademicYearDraft academicYear;
  final ClassSetupDraft classSetup;
  final GradingSchemeDraft gradingScheme;
  final List<StaffRoleDraft> staffRoles;
  final List<FeeCategoryDraft> feeCategories;
  final ReceiptFormatDraft receiptFormat;
  final NotificationSettingsDraft notifications;
  final DeviceRegistrationDraft deviceRegistration;

  OnboardingDraft copyWith({
    SchoolProfileDraft? school,
    CampusSetupDraft? campus,
    AcademicYearDraft? academicYear,
    ClassSetupDraft? classSetup,
    GradingSchemeDraft? gradingScheme,
    List<StaffRoleDraft>? staffRoles,
    List<FeeCategoryDraft>? feeCategories,
    ReceiptFormatDraft? receiptFormat,
    NotificationSettingsDraft? notifications,
    DeviceRegistrationDraft? deviceRegistration,
  }) {
    return OnboardingDraft(
      school: school ?? this.school,
      campus: campus ?? this.campus,
      academicYear: academicYear ?? this.academicYear,
      classSetup: classSetup ?? this.classSetup,
      gradingScheme: gradingScheme ?? this.gradingScheme,
      staffRoles: staffRoles ?? this.staffRoles,
      feeCategories: feeCategories ?? this.feeCategories,
      receiptFormat: receiptFormat ?? this.receiptFormat,
      notifications: notifications ?? this.notifications,
      deviceRegistration: deviceRegistration ?? this.deviceRegistration,
    );
  }

  Map<String, dynamic> toJson() => {
        'school': school.toJson(),
        'campus': campus.toJson(),
        'academicYear': academicYear.toJson(),
        'classSetup': classSetup.toJson(),
        'gradingScheme': gradingScheme.toJson(),
        'staffRoles': staffRoles.map((role) => role.toJson()).toList(),
        'feeCategories':
            feeCategories.map((category) => category.toJson()).toList(),
        'receiptFormat': receiptFormat.toJson(),
        'notifications': notifications.toJson(),
        'deviceRegistration': deviceRegistration.toJson(),
      };

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) =>
      OnboardingDraft(
        school: SchoolProfileDraft.fromJson(
          json['school'] as Map<String, dynamic>? ?? const {},
        ),
        campus: CampusSetupDraft.fromJson(
          json['campus'] as Map<String, dynamic>? ?? const {},
        ),
        academicYear: AcademicYearDraft.fromJson(
          json['academicYear'] as Map<String, dynamic>? ?? const {},
        ),
        classSetup: ClassSetupDraft.fromJson(
          json['classSetup'] as Map<String, dynamic>? ?? const {},
        ),
        gradingScheme: GradingSchemeDraft.fromJson(
          json['gradingScheme'] as Map<String, dynamic>? ?? const {},
        ),
        staffRoles: (json['staffRoles'] as List<dynamic>? ?? const [])
            .map(
                (item) => StaffRoleDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
        feeCategories: (json['feeCategories'] as List<dynamic>? ?? const [])
            .map((item) =>
                FeeCategoryDraft.fromJson(item as Map<String, dynamic>))
            .toList(),
        receiptFormat: ReceiptFormatDraft.fromJson(
          json['receiptFormat'] as Map<String, dynamic>? ?? const {},
        ),
        notifications: NotificationSettingsDraft.fromJson(
          json['notifications'] as Map<String, dynamic>? ?? const {},
        ),
        deviceRegistration: DeviceRegistrationDraft.fromJson(
          json['deviceRegistration'] as Map<String, dynamic>? ?? const {},
        ),
      );
}
