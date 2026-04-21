import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';

class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, this.existing});
  final StaffData? existing;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _role = 'teacher';
  String _employmentType = 'permanent';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _firstNameCtrl.text = s.firstName;
      _lastNameCtrl.text = s.lastName;
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
      _role = s.systemRole;
      _employmentType = s.employmentType;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = context.read<AppDatabase>();
    final id = widget.existing?.id ?? const Uuid().v4();

    await db.upsertStaff(StaffCompanion(
      id: Value(id),
      tenantId: const Value('local'),
      schoolId: const Value('local'),
      firstName: Value(_firstNameCtrl.text.trim()),
      lastName: Value(_lastNameCtrl.text.trim()),
      phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
      email: Value(_emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim()),
      systemRole: Value(_role),
      employmentType: Value(_employmentType),
      syncStatus: const Value('local'),
    ));

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff member saved.'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Staff' : 'Edit Staff')),
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
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                )),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'System Role *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                )),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _employmentType,
                  decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                    DropdownMenuItem(value: 'contract', child: Text('Contract')),
                    DropdownMenuItem(value: 'volunteer', child: Text('Volunteer')),
                  ],
                  onChanged: (v) => setState(() => _employmentType = v!),
                )),
              ]),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
