import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/ui/onboarding/onboarding_draft_storage.dart';
import 'package:desktop_app/ui/onboarding/onboarding_models.dart';
import 'package:desktop_app/ui/onboarding/onboarding_service.dart';
import 'package:desktop_app/ui/onboarding/onboarding_templates.dart';
import 'package:desktop_app/ui/onboarding/steps/step1_school_profile.dart';
import 'package:desktop_app/ui/onboarding/steps/step2_campus_setup.dart';
import 'package:desktop_app/ui/onboarding/steps/step3_academic_year.dart';
import 'package:desktop_app/ui/onboarding/steps/step4_classes_subjects.dart';
import 'package:desktop_app/ui/onboarding/steps/step5_grading_scheme.dart';
import 'package:desktop_app/ui/onboarding/steps/step6_staff_roles.dart';
import 'package:desktop_app/ui/onboarding/steps/step7_fee_categories.dart';
import 'package:desktop_app/ui/onboarding/steps/step8_receipt_format.dart';
import 'package:desktop_app/ui/onboarding/steps/step9_notifications.dart';
import 'package:desktop_app/ui/onboarding/steps/step10_device_registration.dart';
import 'package:desktop_app/ui/onboarding/steps/step11_confirmation.dart';

/// First-run guided onboarding wizard.
/// 11 steps — can be completed in 30–45 minutes.
/// Once all steps are done [onCompleted] is called so main.dart
/// can persist the completion flag and show the main shell.
class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final _draftStorage = OnboardingDraftStorage();
  int _currentStep = 0;
  OnboardingDraft _draft = const OnboardingDraft();
  bool _loadingSavedProgress = true;

  static const _stepTitles = [
    '1. School Profile',
    '2. Campus Setup',
    '3. Academic Year & Terms',
    '4. Classes, Arms & Subjects',
    '5. Grading Scheme',
    '6. Staff Roles',
    '7. Fee Categories & Structures',
    '8. Receipt Format',
    '9. Notification Settings',
    '10. Device Registration',
    '11. Confirmation',
  ];

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => _loadingSavedProgress = false);
      }
      return;
    }

    final saved = await _draftStorage.load(userId);
    if (!mounted) return;

    setState(() {
      _currentStep = saved?.currentStep ?? 0;
      _draft = saved?.draft ?? const OnboardingDraft();
      _loadingSavedProgress = false;
    });
  }

  void _next() {
    if (_currentStep < _stepTitles.length - 1) {
      final nextStep = _currentStep + 1;
      setState(() => _currentStep = nextStep);
      _persistProgress();
    } else {
      widget.onCompleted();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      final nextStep = _currentStep - 1;
      setState(() => _currentStep = nextStep);
      _persistProgress();
    }
  }

  void _setDraft(OnboardingDraft draft) {
    setState(() => _draft = draft);
    _persistProgress();
  }

  Future<void> _persistProgress() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;

    await _draftStorage.save(
      userId: userId,
      currentStep: _currentStep,
      draft: _draft,
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return Step1SchoolProfile(
          initialValue: _draft.school,
          onNext: (value) {
            _setDraft(
              applySchoolTypeTemplate(
                _draft.copyWith(school: value),
                value.schoolType,
              ),
            );
            _next();
          },
        );
      case 1:
        return Step2CampusSetup(
          initialValue: _draft.campus,
          onNext: (value) {
            _setDraft(_draft.copyWith(campus: value));
            _next();
          },
          onBack: _back,
        );
      case 2:
        return Step3AcademicYear(
          initialValue: _draft.academicYear,
          onNext: (value) {
            _setDraft(_draft.copyWith(academicYear: value));
            _next();
          },
          onBack: _back,
        );
      case 3:
        return Step4ClassesSubjects(
          initialValue: _draft.classSetup,
          onNext: (value) {
            _setDraft(_draft.copyWith(classSetup: value));
            _next();
          },
          onBack: _back,
        );
      case 4:
        return Step5GradingScheme(
          initialValue: _draft.gradingScheme,
          onNext: (value) {
            _setDraft(_draft.copyWith(gradingScheme: value));
            _next();
          },
          onBack: _back,
        );
      case 5:
        return Step6StaffRoles(
          initialValue: _draft.staffRoles,
          onNext: (value) {
            _setDraft(_draft.copyWith(staffRoles: value));
            _next();
          },
          onBack: _back,
        );
      case 6:
        return Step7FeeCategories(
          initialValue: _draft.feeCategories,
          onNext: (value) {
            _setDraft(_draft.copyWith(feeCategories: value));
            _next();
          },
          onBack: _back,
        );
      case 7:
        return Step8ReceiptFormat(
          initialValue: _draft.receiptFormat,
          onNext: (value) {
            _setDraft(_draft.copyWith(receiptFormat: value));
            _next();
          },
          onBack: _back,
        );
      case 8:
        return Step9Notifications(
          initialValue: _draft.notifications,
          onNext: (value) {
            _setDraft(_draft.copyWith(notifications: value));
            _next();
          },
          onBack: _back,
        );
      case 9:
        return Step10DeviceRegistration(
          initialValue: _draft.deviceRegistration,
          onNext: (value) {
            _setDraft(_draft.copyWith(deviceRegistration: value));
            _next();
          },
          onBack: _back,
        );
      case 10:
        return Step11Confirmation(
          draft: _draft,
          onComplete: _submitSetup,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitSetup() async {
    final auth = context.read<AuthService>();
    final service = OnboardingService(auth);
    await service.bootstrapSchool(_draft);
    final userId = auth.currentUser?.id;
    if (userId != null) {
      await _draftStorage.clear(userId);
    }
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSavedProgress) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // ── Left: step list ─────────────────────────────────────────────────
          Container(
            width: 260,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  color: Theme.of(context).colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'School Setup',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Complete all steps to get started.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _stepTitles.length,
                    itemBuilder: (ctx, i) {
                      final isActive = i == _currentStep;
                      final isDone = i < _currentStep;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isDone
                              ? Colors.green
                              : isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        title: Text(
                          _stepTitles[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        selected: isActive,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Right: current step ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    );
  }
}
