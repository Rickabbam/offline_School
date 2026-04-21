import 'package:flutter/material.dart';

import '../onboarding_models.dart';

class Step1SchoolProfile extends StatefulWidget {
  const Step1SchoolProfile({
    super.key,
    required this.initialValue,
    required this.onNext,
  });

  final SchoolProfileDraft initialValue;
  final ValueChanged<SchoolProfileDraft> onNext;

  @override
  State<Step1SchoolProfile> createState() => _Step1SchoolProfileState();
}

class _Step1SchoolProfileState extends State<Step1SchoolProfile> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _shortNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late String _schoolType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialValue.name);
    _shortNameCtrl = TextEditingController(text: widget.initialValue.shortName);
    _addressCtrl = TextEditingController(text: widget.initialValue.address);
    _regionCtrl = TextEditingController(text: widget.initialValue.region);
    _districtCtrl = TextEditingController(text: widget.initialValue.district);
    _phoneCtrl = TextEditingController(text: widget.initialValue.contactPhone);
    _emailCtrl = TextEditingController(text: widget.initialValue.contactEmail);
    _schoolType = widget.initialValue.schoolType;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _shortNameCtrl,
      _addressCtrl,
      _regionCtrl,
      _districtCtrl,
      _phoneCtrl,
      _emailCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onNext(
      SchoolProfileDraft(
        name: _nameCtrl.text.trim(),
        shortName: _shortNameCtrl.text.trim(),
        schoolType: _schoolType,
        address: _addressCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
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
          Text('School Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Enter your school\'s basic information.'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _shortNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _schoolType,
            decoration: const InputDecoration(
              labelText: 'School Type *',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'basic', child: Text('Basic School')),
              DropdownMenuItem(value: 'jhs', child: Text('Junior High School (JHS)')),
              DropdownMenuItem(value: 'shs', child: Text('Senior High School (SHS)')),
              DropdownMenuItem(value: 'combined', child: Text('Combined School')),
            ],
            onChanged: (v) => setState(() => _schoolType = v ?? 'basic'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _districtCtrl,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contact Email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _submit,
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
