import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class OnboardingTemplate {
  const OnboardingTemplate({
    required this.classSetup,
    required this.gradingScheme,
    required this.staffRoles,
    required this.feeCategories,
    required this.receiptFormat,
    required this.notifications,
  });

  final ClassSetupDraft classSetup;
  final GradingSchemeDraft gradingScheme;
  final List<StaffRoleDraft> staffRoles;
  final List<FeeCategoryDraft> feeCategories;
  final ReceiptFormatDraft receiptFormat;
  final NotificationSettingsDraft notifications;
}

OnboardingDraft applySchoolTypeTemplate(
  OnboardingDraft draft,
  String schoolType,
) {
  final template = _templateForSchoolType(schoolType);
  return draft.copyWith(
    classSetup: _isClassSetupEmpty(draft.classSetup)
        ? template.classSetup
        : draft.classSetup,
    gradingScheme: _isGradingSchemeEmpty(draft.gradingScheme)
        ? template.gradingScheme
        : draft.gradingScheme,
    staffRoles:
        draft.staffRoles.isEmpty ? template.staffRoles : draft.staffRoles,
    feeCategories: draft.feeCategories.isEmpty
        ? template.feeCategories
        : draft.feeCategories,
    receiptFormat: _isReceiptFormatEmpty(draft.receiptFormat)
        ? template.receiptFormat
        : draft.receiptFormat,
    notifications: _isNotificationSettingsEmpty(draft.notifications)
        ? template.notifications
        : draft.notifications,
  );
}

bool _isClassSetupEmpty(ClassSetupDraft draft) =>
    draft.levels.isEmpty && draft.subjects.isEmpty;

bool _isGradingSchemeEmpty(GradingSchemeDraft draft) =>
    draft.name.trim().isEmpty && draft.bands.isEmpty;

bool _isReceiptFormatEmpty(ReceiptFormatDraft draft) =>
    draft.headerLine1.trim().isEmpty &&
    draft.headerLine2.trim().isEmpty &&
    draft.footerNote.trim().isEmpty &&
    draft.receiptPrefix == 'RCP' &&
    draft.nextReceiptNumber == 1;

bool _isNotificationSettingsEmpty(NotificationSettingsDraft draft) =>
    !draft.smsEnabled &&
    draft.paymentReceiptsEnabled &&
    draft.feeRemindersEnabled &&
    draft.senderId.trim().isEmpty &&
    draft.providerName.trim().isEmpty;

OnboardingTemplate _templateForSchoolType(String schoolType) {
  switch (schoolType) {
    case 'jhs':
      return _jhsTemplate;
    case 'shs':
      return _shsTemplate;
    case 'combined':
      return _combinedTemplate;
    case 'basic':
    default:
      return _basicTemplate;
  }
}

const _defaultStaffRoles = [
  StaffRoleDraft(role: 'admin', enabled: true, headcount: 1),
  StaffRoleDraft(role: 'cashier', enabled: true, headcount: 1),
  StaffRoleDraft(role: 'teacher', enabled: true, headcount: 8),
  StaffRoleDraft(role: 'parent', enabled: false, headcount: 0),
  StaffRoleDraft(role: 'student', enabled: false, headcount: 0),
  StaffRoleDraft(role: 'support_technician', enabled: false, headcount: 0),
];

const _defaultReceiptFormat = ReceiptFormatDraft(
  headerLine1: 'Official School Receipt',
  headerLine2: 'Fees Office',
  footerNote: 'Keep this receipt as proof of payment.',
  receiptPrefix: 'RCP',
  nextReceiptNumber: 1,
);

const _defaultNotifications = NotificationSettingsDraft(
  smsEnabled: false,
  paymentReceiptsEnabled: true,
  feeRemindersEnabled: true,
  providerName: 'Arkesel',
  senderId: 'OFFSCHOOL',
);

const _basicTemplate = OnboardingTemplate(
  classSetup: ClassSetupDraft(
    levels: [
      ClassLevelDraft(name: 'Basic 1', sortOrder: 1, arms: ['A', 'B']),
      ClassLevelDraft(name: 'Basic 2', sortOrder: 2, arms: ['A', 'B']),
      ClassLevelDraft(name: 'Basic 3', sortOrder: 3, arms: ['A', 'B']),
      ClassLevelDraft(name: 'Basic 4', sortOrder: 4, arms: ['A', 'B']),
      ClassLevelDraft(name: 'Basic 5', sortOrder: 5, arms: ['A', 'B']),
      ClassLevelDraft(name: 'Basic 6', sortOrder: 6, arms: ['A', 'B']),
    ],
    subjects: [
      SubjectDraft(name: 'English Language', code: 'ENG'),
      SubjectDraft(name: 'Mathematics', code: 'MTH'),
      SubjectDraft(name: 'Science', code: 'SCI'),
      SubjectDraft(name: 'Our World Our People', code: 'OWOP'),
      SubjectDraft(name: 'Creative Arts', code: 'CA'),
      SubjectDraft(name: 'Religious and Moral Education', code: 'RME'),
      SubjectDraft(name: 'Computing', code: 'ICT'),
      SubjectDraft(name: 'Ghanaian Language', code: 'LANG'),
    ],
  ),
  gradingScheme: GradingSchemeDraft(
    name: 'Basic School Default',
    bands: [
      GradeBandDraft(grade: 'A', min: 80, max: 100, remark: 'Excellent'),
      GradeBandDraft(grade: 'B', min: 70, max: 79, remark: 'Very Good'),
      GradeBandDraft(grade: 'C', min: 60, max: 69, remark: 'Good'),
      GradeBandDraft(grade: 'D', min: 50, max: 59, remark: 'Pass'),
      GradeBandDraft(grade: 'E', min: 40, max: 49, remark: 'Needs Improvement'),
      GradeBandDraft(grade: 'F', min: 0, max: 39, remark: 'Fail'),
    ],
  ),
  staffRoles: _defaultStaffRoles,
  feeCategories: [
    FeeCategoryDraft(
        name: 'Tuition', defaultAmount: 450, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'PTA Levy', defaultAmount: 60, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'Books and Worksheets',
        defaultAmount: 80,
        billingTerm: 'per_term'),
  ],
  receiptFormat: _defaultReceiptFormat,
  notifications: _defaultNotifications,
);

const _jhsTemplate = OnboardingTemplate(
  classSetup: ClassSetupDraft(
    levels: [
      ClassLevelDraft(name: 'JHS 1', sortOrder: 1, arms: ['A', 'B']),
      ClassLevelDraft(name: 'JHS 2', sortOrder: 2, arms: ['A', 'B']),
      ClassLevelDraft(name: 'JHS 3', sortOrder: 3, arms: ['A', 'B']),
    ],
    subjects: [
      SubjectDraft(name: 'English Language', code: 'ENG'),
      SubjectDraft(name: 'Mathematics', code: 'MTH'),
      SubjectDraft(name: 'Integrated Science', code: 'INTSCI'),
      SubjectDraft(name: 'Social Studies', code: 'SOC'),
      SubjectDraft(name: 'Computing', code: 'ICT'),
      SubjectDraft(name: 'Career Technology', code: 'CT'),
      SubjectDraft(name: 'Creative Arts and Design', code: 'CAD'),
      SubjectDraft(name: 'Religious and Moral Education', code: 'RME'),
      SubjectDraft(name: 'French', code: 'FRE'),
      SubjectDraft(name: 'Ghanaian Language', code: 'LANG'),
    ],
  ),
  gradingScheme: GradingSchemeDraft(
    name: 'JHS Default',
    bands: [
      GradeBandDraft(grade: '1', min: 90, max: 100, remark: 'Highest'),
      GradeBandDraft(grade: '2', min: 80, max: 89, remark: 'Higher'),
      GradeBandDraft(grade: '3', min: 70, max: 79, remark: 'High'),
      GradeBandDraft(grade: '4', min: 60, max: 69, remark: 'Credit'),
      GradeBandDraft(grade: '5', min: 55, max: 59, remark: 'Credit'),
      GradeBandDraft(grade: '6', min: 50, max: 54, remark: 'Low Credit'),
      GradeBandDraft(grade: '7', min: 40, max: 49, remark: 'Pass'),
      GradeBandDraft(grade: '8', min: 35, max: 39, remark: 'Low Pass'),
      GradeBandDraft(grade: '9', min: 0, max: 34, remark: 'Fail'),
    ],
  ),
  staffRoles: _defaultStaffRoles,
  feeCategories: [
    FeeCategoryDraft(
        name: 'Tuition', defaultAmount: 650, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'PTA Levy', defaultAmount: 75, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'BECE Mock Exams', defaultAmount: 120, billingTerm: 'per_term'),
  ],
  receiptFormat: _defaultReceiptFormat,
  notifications: _defaultNotifications,
);

const _shsTemplate = OnboardingTemplate(
  classSetup: ClassSetupDraft(
    levels: [
      ClassLevelDraft(name: 'SHS 1', sortOrder: 1, arms: ['A', 'B', 'C']),
      ClassLevelDraft(name: 'SHS 2', sortOrder: 2, arms: ['A', 'B', 'C']),
      ClassLevelDraft(name: 'SHS 3', sortOrder: 3, arms: ['A', 'B', 'C']),
    ],
    subjects: [
      SubjectDraft(name: 'Core Mathematics', code: 'CMTH'),
      SubjectDraft(name: 'English Language', code: 'ENG'),
      SubjectDraft(name: 'Integrated Science', code: 'INTSCI'),
      SubjectDraft(name: 'Social Studies', code: 'SOC'),
      SubjectDraft(name: 'Elective Mathematics', code: 'EMTH'),
      SubjectDraft(name: 'Physics', code: 'PHY'),
      SubjectDraft(name: 'Chemistry', code: 'CHEM'),
      SubjectDraft(name: 'Biology', code: 'BIO'),
      SubjectDraft(name: 'Economics', code: 'ECON'),
      SubjectDraft(name: 'Financial Accounting', code: 'ACC'),
      SubjectDraft(name: 'Government', code: 'GOV'),
    ],
  ),
  gradingScheme: GradingSchemeDraft(
    name: 'SHS WASSCE Default',
    bands: [
      GradeBandDraft(grade: 'A1', min: 80, max: 100, remark: 'Excellent'),
      GradeBandDraft(grade: 'B2', min: 70, max: 79, remark: 'Very Good'),
      GradeBandDraft(grade: 'B3', min: 65, max: 69, remark: 'Good'),
      GradeBandDraft(grade: 'C4', min: 60, max: 64, remark: 'Credit'),
      GradeBandDraft(grade: 'C5', min: 55, max: 59, remark: 'Credit'),
      GradeBandDraft(grade: 'C6', min: 50, max: 54, remark: 'Credit'),
      GradeBandDraft(grade: 'D7', min: 45, max: 49, remark: 'Pass'),
      GradeBandDraft(grade: 'E8', min: 40, max: 44, remark: 'Pass'),
      GradeBandDraft(grade: 'F9', min: 0, max: 39, remark: 'Fail'),
    ],
  ),
  staffRoles: [
    StaffRoleDraft(role: 'admin', enabled: true, headcount: 1),
    StaffRoleDraft(role: 'cashier', enabled: true, headcount: 1),
    StaffRoleDraft(role: 'teacher', enabled: true, headcount: 14),
    StaffRoleDraft(role: 'parent', enabled: false, headcount: 0),
    StaffRoleDraft(role: 'student', enabled: false, headcount: 0),
    StaffRoleDraft(role: 'support_technician', enabled: false, headcount: 0),
  ],
  feeCategories: [
    FeeCategoryDraft(
        name: 'Tuition', defaultAmount: 900, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'Boarding', defaultAmount: 1200, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'Science Resource Levy',
        defaultAmount: 180,
        billingTerm: 'per_term'),
  ],
  receiptFormat: _defaultReceiptFormat,
  notifications: _defaultNotifications,
);

const _combinedTemplate = OnboardingTemplate(
  classSetup: ClassSetupDraft(
    levels: [
      ClassLevelDraft(name: 'Basic 1', sortOrder: 1, arms: ['A']),
      ClassLevelDraft(name: 'Basic 2', sortOrder: 2, arms: ['A']),
      ClassLevelDraft(name: 'Basic 3', sortOrder: 3, arms: ['A']),
      ClassLevelDraft(name: 'Basic 4', sortOrder: 4, arms: ['A']),
      ClassLevelDraft(name: 'Basic 5', sortOrder: 5, arms: ['A']),
      ClassLevelDraft(name: 'Basic 6', sortOrder: 6, arms: ['A']),
      ClassLevelDraft(name: 'JHS 1', sortOrder: 7, arms: ['A']),
      ClassLevelDraft(name: 'JHS 2', sortOrder: 8, arms: ['A']),
      ClassLevelDraft(name: 'JHS 3', sortOrder: 9, arms: ['A']),
    ],
    subjects: [
      SubjectDraft(name: 'English Language', code: 'ENG'),
      SubjectDraft(name: 'Mathematics', code: 'MTH'),
      SubjectDraft(name: 'Science', code: 'SCI'),
      SubjectDraft(name: 'Social Studies', code: 'SOC'),
      SubjectDraft(name: 'Computing', code: 'ICT'),
      SubjectDraft(name: 'Religious and Moral Education', code: 'RME'),
      SubjectDraft(name: 'Ghanaian Language', code: 'LANG'),
    ],
  ),
  gradingScheme: GradingSchemeDraft(
    name: 'JHS Default',
    bands: [
      GradeBandDraft(grade: '1', min: 90, max: 100, remark: 'Highest'),
      GradeBandDraft(grade: '2', min: 80, max: 89, remark: 'Higher'),
      GradeBandDraft(grade: '3', min: 70, max: 79, remark: 'High'),
      GradeBandDraft(grade: '4', min: 60, max: 69, remark: 'Credit'),
      GradeBandDraft(grade: '5', min: 55, max: 59, remark: 'Credit'),
      GradeBandDraft(grade: '6', min: 50, max: 54, remark: 'Low Credit'),
      GradeBandDraft(grade: '7', min: 40, max: 49, remark: 'Pass'),
      GradeBandDraft(grade: '8', min: 35, max: 39, remark: 'Low Pass'),
      GradeBandDraft(grade: '9', min: 0, max: 34, remark: 'Fail'),
    ],
  ),
  staffRoles: _defaultStaffRoles,
  feeCategories: [
    FeeCategoryDraft(
        name: 'Tuition', defaultAmount: 550, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'PTA Levy', defaultAmount: 65, billingTerm: 'per_term'),
    FeeCategoryDraft(
        name: 'ICT Levy', defaultAmount: 50, billingTerm: 'per_term'),
  ],
  receiptFormat: _defaultReceiptFormat,
  notifications: _defaultNotifications,
);
