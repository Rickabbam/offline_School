import 'package:flutter/material.dart';

class Step7FeeCategories extends StatelessWidget {
  const Step7FeeCategories({super.key, required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fee Categories & Structures', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Configure fee categories and term fee structures.'),
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
                  'Configure Fee Categories & Structures here.',
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
