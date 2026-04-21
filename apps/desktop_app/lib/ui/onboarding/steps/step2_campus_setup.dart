import 'package:flutter/material.dart';

class Step2CampusSetup extends StatefulWidget {
  const Step2CampusSetup({super.key, required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<Step2CampusSetup> createState() => _Step2CampusSetupState();
}

class _Step2CampusSetupState extends State<Step2CampusSetup> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Campus Setup', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Register the campus that this installation serves.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Campus Name *', border: OutlineInputBorder()),
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Campus Address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: widget.onBack, child: const Text('Back')),
              FilledButton(
                onPressed: () { if (_formKey.currentState!.validate()) widget.onNext(); },
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
