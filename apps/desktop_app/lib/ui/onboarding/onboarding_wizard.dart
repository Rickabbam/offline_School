import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import 'onboarding_models.dart';
import 'onboarding_service.dart';
import 'steps/step1_school_profile.dart';
import 'steps/step2_campus_setup.dart';
import 'steps/step3_academic_year.dart';
import 'steps/step4_classes_subjects.dart';
import 'steps/step5_grading_scheme.dart';
import 'steps/step6_staff_roles.dart';
import 'steps/step7_fee_categories.dart';
import 'steps/step8_receipt_format.dart';
import 'steps/step9_notifications.dart';
import 'steps/step10_device_registration.dart';
import 'steps/step11_confirmation.dart';

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
  int _currentStep = 0;
  OnboardingDraft _draft = const OnboardingDraft();

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

  void _next() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onCompleted();
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return Step1SchoolProfile(
          initialValue: _draft.school,
          onNext: (value) {
            setState(() => _draft = _draft.copyWith(school: value));
            _next();
          },
        );
      case 1:
        return Step2CampusSetup(
          initialValue: _draft.campus,
          onNext: (value) {
            setState(() => _draft = _draft.copyWith(campus: value));
            _next();
          },
          onBack: _back,
        );
      case 2:
        return Step3AcademicYear(
          initialValue: _draft.academicYear,
          onNext: (value) {
            setState(() => _draft = _draft.copyWith(academicYear: value));
            _next();
          },
          onBack: _back,
        );
      case 3:
        return Step4ClassesSubjects(
          initialValue: _draft.classSetup,
          onNext: (value) {
            setState(() => _draft = _draft.copyWith(classSetup: value));
            _next();
          },
          onBack: _back,
        );
      case 4:
        return Step5GradingScheme(
          initialValue: _draft.gradingScheme,
          onNext: (value) {
            setState(() => _draft = _draft.copyWith(gradingScheme: value));
            _next();
          },
          onBack: _back,
        );
      case 5:
        return Step6StaffRoles(onNext: _next, onBack: _back);
      case 6:
        return Step7FeeCategories(onNext: _next, onBack: _back);
      case 7:
        return Step8ReceiptFormat(onNext: _next, onBack: _back);
      case 8:
        return Step9Notifications(onNext: _next, onBack: _back);
      case 9:
        return Step10DeviceRegistration(onNext: _next, onBack: _back);
      case 10:
        return Step11Confirmation(onComplete: _submitSetup);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitSetup() async {
    final auth = context.read<AuthService>();
    final service = OnboardingService(auth);
    await service.bootstrapSchool(_draft);
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 28),
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
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
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
