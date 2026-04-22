import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step8ReceiptFormat extends StatelessWidget {
  const Step8ReceiptFormat({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final ReceiptFormatDraft initialValue;
  final ValueChanged<ReceiptFormatDraft> onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final header1 = TextEditingController(
      text: initialValue.headerLine1.isEmpty
          ? 'Official School Receipt'
          : initialValue.headerLine1,
    );
    final header2 = TextEditingController(text: initialValue.headerLine2);
    final footer = TextEditingController(
      text: initialValue.footerNote.isEmpty
          ? 'Thank you for supporting timely fee payment.'
          : initialValue.footerNote,
    );
    final prefix = TextEditingController(text: initialValue.receiptPrefix);
    final nextNumber = TextEditingController(
      text: initialValue.nextReceiptNumber.toString(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt Format',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Set the default header, footer, and numbering sequence.'),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              TextField(
                controller: header1,
                decoration: const InputDecoration(
                  labelText: 'Header line 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: header2,
                decoration: const InputDecoration(
                  labelText: 'Header line 2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: prefix,
                      decoration: const InputDecoration(
                        labelText: 'Receipt prefix',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: nextNumber,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Next receipt number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: footer,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Footer note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            FilledButton(
              onPressed: () {
                onNext(
                  ReceiptFormatDraft(
                    headerLine1: header1.text.trim(),
                    headerLine2: header2.text.trim(),
                    footerNote: footer.text.trim(),
                    receiptPrefix:
                        prefix.text.trim().isEmpty ? 'RCP' : prefix.text.trim(),
                    nextReceiptNumber:
                        int.tryParse(nextNumber.text.trim()) ?? 1,
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
