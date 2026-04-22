import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step4ClassesSubjects extends StatefulWidget {
  const Step4ClassesSubjects({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final ClassSetupDraft initialValue;
  final ValueChanged<ClassSetupDraft> onNext;
  final VoidCallback onBack;

  @override
  State<Step4ClassesSubjects> createState() => _Step4ClassesSubjectsState();
}

class _Step4ClassesSubjectsState extends State<Step4ClassesSubjects> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _levelsCtrl;
  late final TextEditingController _subjectsCtrl;

  @override
  void initState() {
    super.initState();
    _levelsCtrl = TextEditingController(
      text: widget.initialValue.levels.isEmpty
          ? 'Basic 1:A,B\nBasic 2:A,B\nBasic 3:A,B'
          : widget.initialValue.levels
              .map((level) => '${level.name}:${level.arms.join(',')}')
              .join('\n'),
    );
    _subjectsCtrl = TextEditingController(
      text: widget.initialValue.subjects.isEmpty
          ? 'English:ENG\nMathematics:MTH\nScience:SCI'
          : widget.initialValue.subjects
              .map((subject) => '${subject.name}:${subject.code}')
              .join('\n'),
    );
  }

  @override
  void dispose() {
    _levelsCtrl.dispose();
    _subjectsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final levels = _levelsCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final subjects = _subjectsCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    widget.onNext(
      ClassSetupDraft(
        levels: levels.asMap().entries.map((entry) {
          final parts = entry.value.split(':');
          final name = parts.first.trim();
          final arms = parts.length > 1
              ? parts[1]
                  .split(',')
                  .map((arm) => arm.trim())
                  .where((arm) => arm.isNotEmpty)
                  .toList()
              : <String>['A'];
          return ClassLevelDraft(
            name: name,
            sortOrder: entry.key + 1,
            arms: arms,
          );
        }).toList(),
        subjects: subjects.map((line) {
          final parts = line.split(':');
          return SubjectDraft(
            name: parts.first.trim(),
            code: parts.length > 1 ? parts[1].trim() : '',
          );
        }).toList(),
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
          Text('Classes, Arms & Subjects',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
              'Enter one class level per line using "Level:Arm,Arm". Enter one subject per line using "Subject:Code".'),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _levelsCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Class Levels & Arms *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _subjectsCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Subjects *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
