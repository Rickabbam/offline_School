import 'package:flutter/material.dart';

class Step3AcademicYear extends StatelessWidget {
  const Step3AcademicYear({super.key, required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Academic Year & Terms', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Configure the current academic year and its terms.'),
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
                  'Configure Academic Year & Terms here.',
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
