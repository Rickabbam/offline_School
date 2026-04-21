import 'package:flutter/material.dart';

class Step1SchoolProfile extends StatefulWidget {
  const Step1SchoolProfile({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  State<Step1SchoolProfile> createState() => _Step1SchoolProfileState();
}

class _Step1SchoolProfileState extends State<Step1SchoolProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  String _schoolType = 'basic';
  final _addressCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_nameCtrl, _shortNameCtrl, _addressCtrl, _regionCtrl,
        _districtCtrl, _phoneCtrl, _emailCtrl]) {
      c.dispose();
    }
    super.dispose();
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
          Row(children: [
            Expanded(child: TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'School Name *', border: OutlineInputBorder()),
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            )),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(
              controller: _shortNameCtrl,
              decoration: const InputDecoration(labelText: 'Short Name', border: OutlineInputBorder()),
            )),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _schoolType,
            decoration: const InputDecoration(labelText: 'School Type *', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'basic', child: Text('Basic School')),
              DropdownMenuItem(value: 'jhs', child: Text('Junior High School (JHS)')),
              DropdownMenuItem(value: 'shs', child: Text('Senior High School (SHS)')),
              DropdownMenuItem(value: 'combined', child: Text('Combined School')),
            ],
            onChanged: (v) => setState(() => _schoolType = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
            )),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(
              controller: _districtCtrl,
              decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
            )),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Contact Email', border: OutlineInputBorder()),
            )),
          ]),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) widget.onNext();
              },
              child: const Text('Continue'),
            ),
          ]),
        ],
      ),
    );
  }
}
