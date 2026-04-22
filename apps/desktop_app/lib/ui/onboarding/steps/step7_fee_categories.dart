import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step7FeeCategories extends StatelessWidget {
  const Step7FeeCategories({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final List<FeeCategoryDraft> initialValue;
  final ValueChanged<List<FeeCategoryDraft>> onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: initialValue.isEmpty
          ? 'Tuition:450.00:per_term\nPTA Levy:60.00:per_term\nExam Fees:45.00:per_term'
          : initialValue
              .map(
                (item) =>
                    '${item.name}:${item.defaultAmount.toStringAsFixed(2)}:${item.billingTerm}',
              )
              .join('\n'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fee Categories & Structures',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter one category per line using "Name:DefaultAmount:per_term|one_time".',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              labelText: 'Fee categories',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            FilledButton(
              onPressed: () {
                final parsed = controller.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .map((line) {
                  final parts = line.split(':');
                  return FeeCategoryDraft(
                    name: parts[0].trim(),
                    defaultAmount: parts.length > 1
                        ? double.tryParse(parts[1].trim()) ?? 0
                        : 0,
                    billingTerm:
                        parts.length > 2 ? parts[2].trim() : 'per_term',
                  );
                }).toList(growable: false);
                onNext(parsed);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
