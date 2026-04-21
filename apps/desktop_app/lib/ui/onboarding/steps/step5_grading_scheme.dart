import 'package:flutter/material.dart';

class Step5GradingScheme extends StatelessWidget {
  const Step5GradingScheme({super.key, required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grading Scheme', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Define the grading bands used for student assessments.'),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note, size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Configure Grading Scheme here.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            FilledButton(onPressed: onNext, child: const Text('Continue')),
          ],
        ),
      ],
    );
  }
}
