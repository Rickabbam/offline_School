import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/database/app_database.dart';

class ApplicantFormScreen extends StatefulWidget {
  const ApplicantFormScreen({super.key});

  @override
  State<ApplicantFormScreen> createState() => _ApplicantFormScreenState();
}

class _ApplicantFormScreenState extends State<ApplicantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _guardianNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _gender;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _guardianNameCtrl,
        _guardianPhoneCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    await db.upsertApplicant(ApplicantsCompanion(
      id: Value(const Uuid().v4()),
      tenantId: const Value('local'),
      schoolId: const Value('local'),
      firstName: Value(_firstNameCtrl.text.trim()),
      lastName: Value(_lastNameCtrl.text.trim()),
      gender: Value(_gender),
      guardianName: Value(_guardianNameCtrl.text.trim().isEmpty
          ? null : _guardianNameCtrl.text.trim()),
      guardianPhone: Value(_guardianPhoneCtrl.text.trim().isEmpty
          ? null : _guardianPhoneCtrl.text.trim()),
      documentNotes: Value(_notesCtrl.text.trim().isEmpty
          ? null : _notesCtrl.text.trim()),
      status: const Value('applied'),
      syncStatus: const Value('local'),
    ));
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applicant registered.'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Applicant')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First Name *', border: OutlineInputBorder()),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last Name *', border: OutlineInputBorder()),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                )),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                )),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _guardianNameCtrl,
                  decoration: const InputDecoration(labelText: 'Guardian/Parent Name', border: OutlineInputBorder()),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _guardianPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Guardian Phone', border: OutlineInputBorder()),
                )),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Document Notes',
                    hintText: 'List physical documents received…',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Register Applicant'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
