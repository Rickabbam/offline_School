import 'package:flutter/material.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class Step2CampusSetup extends StatefulWidget {
  const Step2CampusSetup({
    super.key,
    required this.initialValue,
    required this.onNext,
    required this.onBack,
  });

  final CampusSetupDraft initialValue;
  final ValueChanged<CampusSetupDraft> onNext;
  final VoidCallback onBack;

  @override
  State<Step2CampusSetup> createState() => _Step2CampusSetupState();
}

class _Step2CampusSetupState extends State<Step2CampusSetup> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _registrationCodeCtrl;
  late bool _isPrimaryCampus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialValue.name);
    _addressCtrl = TextEditingController(text: widget.initialValue.address);
    _phoneCtrl = TextEditingController(text: widget.initialValue.contactPhone);
    _registrationCodeCtrl =
        TextEditingController(text: widget.initialValue.registrationCode);
    _isPrimaryCampus = widget.initialValue.isPrimaryCampus;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _registrationCodeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onNext(
      CampusSetupDraft(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        registrationCode: _registrationCodeCtrl.text.trim(),
        isPrimaryCampus: _isPrimaryCampus,
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
          Text('Campus Setup',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Register the campus that this installation serves.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Campus Name *',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Campus Address',
              border: OutlineInputBorder(),
            ),
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
                  controller: _registrationCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Registration Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Primary operating campus'),
            value: _isPrimaryCampus,
            onChanged: (value) => setState(() => _isPrimaryCampus = value),
          ),
          const Spacer(),
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
