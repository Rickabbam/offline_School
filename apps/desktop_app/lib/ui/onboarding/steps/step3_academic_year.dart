import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step3AcademicYear extends StatefulWidget {
  const Step3AcademicYear({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final AcademicYearDraft initialValue;
  final ValueChanged<AcademicYearDraft> onNext;
  final VoidCallback onBack;

  @override
  State<Step3AcademicYear> createState() => _Step3AcademicYearState();
}

class _Step3AcademicYearState extends State<Step3AcademicYear> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  final _termNameCtrls = <TextEditingController>[];
  final _termStartCtrls = <TextEditingController>[];
  final _termEndCtrls = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    final initialTerms = widget.initialValue.terms.isNotEmpty
        ? widget.initialValue.terms
        : const [
            AcademicTermDraft(
              name: 'Term 1',
              termNumber: 1,
              startDate: '',
              endDate: '',
              isCurrent: true,
            ),
            AcademicTermDraft(
              name: 'Term 2',
              termNumber: 2,
              startDate: '',
              endDate: '',
            ),
            AcademicTermDraft(
              name: 'Term 3',
              termNumber: 3,
              startDate: '',
              endDate: '',
            ),
          ];
    _labelCtrl = TextEditingController(text: widget.initialValue.label);
    _startCtrl = TextEditingController(text: widget.initialValue.startDate);
    _endCtrl = TextEditingController(text: widget.initialValue.endDate);
    for (final term in initialTerms) {
      _termNameCtrls.add(TextEditingController(text: term.name));
      _termStartCtrls.add(TextEditingController(text: term.startDate));
      _termEndCtrls.add(TextEditingController(text: term.endDate));
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    for (final controller in [
      ..._termNameCtrls,
      ..._termStartCtrls,
      ..._termEndCtrls
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final terms = List.generate(
      _termNameCtrls.length,
      (index) => AcademicTermDraft(
        name: _termNameCtrls[index].text.trim(),
        termNumber: index + 1,
        startDate: _termStartCtrls[index].text.trim(),
        endDate: _termEndCtrls[index].text.trim(),
        isCurrent: index == 0,
      ),
    );

    widget.onNext(
      AcademicYearDraft(
        label: _labelCtrl.text.trim(),
        startDate: _startCtrl.text.trim(),
        endDate: _endCtrl.text.trim(),
        terms: terms,
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
          Text('Academic Year & Terms',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Configure the current academic year and its terms.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Academic Year Label *',
              hintText: '2026/2027',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Year Start Date *',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _endCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Year End Date *',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _termNameCtrls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Term ${index + 1}'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _termNameCtrls[index],
                          decoration: const InputDecoration(
                            labelText: 'Term Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _termStartCtrls[index],
                                decoration: const InputDecoration(
                                  labelText: 'Start Date *',
                                  hintText: 'YYYY-MM-DD',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _termEndCtrls[index],
                                decoration: const InputDecoration(
                                  labelText: 'End Date *',
                                  hintText: 'YYYY-MM-DD',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                  onPressed: widget.onBack, child: const Text('Back')),
              FilledButton(onPressed: _submit, child: const Text('Continue')),
            ],
          ),
        ],
      ),
    );
  }
}
