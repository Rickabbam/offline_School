import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step11Confirmation extends StatefulWidget {
  const Step11Confirmation({
    super.key,
    required this.draft,
    required this.onComplete,
  });

  final OnboardingDraft draft;
  final Future<void> Function() onComplete;

  @override
  State<Step11Confirmation> createState() => _Step11ConfirmationState();
}

class _Step11ConfirmationState extends State<Step11Confirmation> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Setup submission failed. $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup Complete!',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Review the setup summary, then submit to activate the school workspace.',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              _SummaryCard(
                title: 'School Setup',
                lines: [
                  widget.draft.school.name,
                  '${widget.draft.campus.name} campus',
                  widget.draft.academicYear.label,
                  '${widget.draft.classSetup.levels.length} class levels',
                  '${widget.draft.classSetup.subjects.length} subjects',
                ],
              ),
              _SummaryCard(
                title: 'Operations Defaults',
                lines: [
                  '${widget.draft.staffRoles.where((role) => role.enabled).length} active staff roles',
                  '${widget.draft.feeCategories.length} fee categories',
                  'Receipt prefix: ${widget.draft.receiptFormat.receiptPrefix}',
                  widget.draft.notifications.smsEnabled
                      ? 'SMS notifications enabled'
                      : 'SMS notifications disabled',
                  widget.draft.deviceRegistration.registerOfflineAccess
                      ? widget.draft.deviceRegistration.isRegistered
                          ? 'Trusted device registered'
                          : 'Trusted device still pending registration'
                      : 'Trusted device registration skipped',
                ],
              ),
              _SummaryCard(
                title: 'First Admin',
                lines: [
                  user?.fullName ?? 'Unknown user',
                  user?.email ?? 'No email available',
                  'Role: ${user?.role ?? 'unknown'}',
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This submission will persist school, campus, academic year, classes, subjects, and grading scheme now. Finance and notification defaults remain in the desktop setup draft until the corresponding backend modules are added.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Finish Setup'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines) ...[
              Text(line),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
