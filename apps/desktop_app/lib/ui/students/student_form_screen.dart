import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';

/// Form to create or edit a student record.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.existing});

  /// Pass an existing record to edit; null = create new.
  final Student? existing;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _firstNameCtrl.text = s.firstName;
      _middleNameCtrl.text = s.middleName ?? '';
      _lastNameCtrl.text = s.lastName;
      _studentNumberCtrl.text = s.studentNumber ?? '';
      _dobCtrl.text = s.dateOfBirth ?? '';
      _gender = s.gender;
    }
  }

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _middleNameCtrl, _lastNameCtrl,
        _studentNumberCtrl, _dobCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = context.read<AppDatabase>();
    final isNew = widget.existing == null;
    final id = isNew ? const Uuid().v4() : widget.existing!.id;

    final companion = StudentsCompanion(
      id: Value(id),
      tenantId: const Value('local'),
      schoolId: const Value('local'),
      firstName: Value(_firstNameCtrl.text.trim()),
      middleName: Value(_middleNameCtrl.text.trim().isEmpty
          ? null
          : _middleNameCtrl.text.trim()),
      lastName: Value(_lastNameCtrl.text.trim()),
      studentNumber: Value(_studentNumberCtrl.text.trim().isEmpty
          ? null
          : _studentNumberCtrl.text.trim()),
      dateOfBirth:
          Value(_dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim()),
      gender: Value(_gender),
      syncStatus: const Value('local'),
    );

    await db.upsertStudent(companion);

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew ? 'Student added.' : 'Student updated.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add Student' : 'Edit Student'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'First name is required.' : null,
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _middleNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Middle Name',
                      border: OutlineInputBorder()),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Last name is required.' : null,
                )),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _studentNumberCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Student Number',
                      border: OutlineInputBorder()),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      border: OutlineInputBorder()),
                )),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                )),
              ]),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isNew ? 'Add Student' : 'Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
