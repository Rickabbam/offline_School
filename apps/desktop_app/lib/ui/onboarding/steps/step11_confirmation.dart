import 'package:flutter/material.dart';

/// Step 11 — final confirmation before the wizard is dismissed.
class Step11Confirmation extends StatelessWidget {
  const Step11Confirmation({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup Complete!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Your school is now configured and ready to use.'),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'All 11 setup steps are complete.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can now manage students, staff, admissions, and attendance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Dashboard'),
              onPressed: onComplete,
            ),
          ],
        ),
      ],
    );
  }
}
