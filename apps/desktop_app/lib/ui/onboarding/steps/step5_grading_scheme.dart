import 'package:flutter/material.dart';

import '../onboarding_models.dart';

class Step5GradingScheme extends StatefulWidget {
  const Step5GradingScheme({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final GradingSchemeDraft initialValue;
  final ValueChanged<GradingSchemeDraft> onNext;
  final VoidCallback onBack;

  @override
  State<Step5GradingScheme> createState() => _Step5GradingSchemeState();
}

class _Step5GradingSchemeState extends State<Step5GradingScheme> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bandsCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.initialValue.name.isEmpty
          ? 'Ghana Default'
          : widget.initialValue.name,
    );
    _bandsCtrl = TextEditingController(
      text: widget.initialValue.bands.isEmpty
          ? 'A1:80:100:Excellent\nB2:70:79:Very Good\nC4:60:69:Good\nD7:50:59:Pass\nF9:0:49:Fail'
          : widget.initialValue.bands
              .map((band) => '${band.grade}:${band.min}:${band.max}:${band.remark}')
              .join('\n'),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bandsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bands = _bandsCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(':');
          return GradeBandDraft(
            grade: parts[0].trim(),
            min: int.parse(parts[1].trim()),
            max: int.parse(parts[2].trim()),
            remark: parts[3].trim(),
          );
        })
        .toList();
    widget.onNext(
      GradingSchemeDraft(
        name: _nameCtrl.text.trim(),
        bands: bands,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grading Scheme', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Enter one grade band per line using "Grade:Min:Max:Remark".'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Scheme Name *',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextFormField(
              controller: _bandsCtrl,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                labelText: 'Grade Bands *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: widget.onBack, child: const Text('Back')),
              FilledButton(onPressed: _submit, child: const Text('Continue')),
            ],
          ),
        ],
      ),
    );
  }
}
