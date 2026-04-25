import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/staff/staff_editor_service.dart';

class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, this.existing});

  final StaffData? existing;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _editor = StaffEditorService();
  final _formKey = GlobalKey<FormState>();
  final _staffNumberCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _dateJoinedCtrl = TextEditingController();

  String? _gender;
  String _role = 'teacher';
  String _employmentType = 'permanent';
  bool _isActive = true;
  bool _saving = false;
  bool _loadingMetadata = true;

  String? _classTeacherClassArmId;
  final Set<String> _subjectIds = <String>{};
  List<ClassArmsCacheData> _classArms = const [];
  List<SubjectsCacheData> _subjects = const [];

  @override
  void initState() {
    super.initState();
    final staff = widget.existing;
    if (staff != null) {
      _staffNumberCtrl.text = staff.staffNumber ?? '';
      _firstNameCtrl.text = staff.firstName;
      _middleNameCtrl.text = staff.middleName ?? '';
      _lastNameCtrl.text = staff.lastName;
      _phoneCtrl.text = staff.phone ?? '';
      _emailCtrl.text = staff.email ?? '';
      _departmentCtrl.text = staff.department ?? '';
      _dateJoinedCtrl.text = staff.dateJoined ?? '';
      _gender = staff.gender;
      _role = staff.systemRole;
      _employmentType = staff.employmentType;
      _isActive = staff.isActive;
    }
    _loadMetadata();
  }

  @override
  void dispose() {
    for (final controller in [
      _staffNumberCtrl,
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _departmentCtrl,
      _dateJoinedCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final db = context.read<AppDatabase>();
    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingMetadata = false);
      return;
    }
    final scope = LocalDataScope(
      tenantId: user!.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final classArms = await db.getClassArms(scope: scope);
    final subjects = await db.getSubjects(scope: scope);

    List<StaffTeachingAssignment> assignments = const [];
    if (widget.existing != null) {
      assignments = await db.getStaffAssignments(
        widget.existing!.id,
        scope: scope,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _classArms = classArms;
      _subjects = subjects;
      for (final assignment in assignments) {
        if (assignment.assignmentType == 'class_teacher') {
          _classTeacherClassArmId = assignment.classArmId;
        } else if (assignment.assignmentType == 'subject_teacher' &&
            assignment.subjectId != null) {
          _subjectIds.add(assignment.subjectId!);
        }
      }
      _loadingMetadata = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _editor.saveStaff(
        db: context.read<AppDatabase>(),
        user: user!,
        existing: widget.existing,
        input: StaffEditorInput(
          staffNumber: _staffNumberCtrl.text,
          firstName: _firstNameCtrl.text,
          middleName: _middleNameCtrl.text,
          lastName: _lastNameCtrl.text,
          gender: _gender,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          department: _departmentCtrl.text,
          systemRole: _role,
          employmentType: _employmentType,
          dateJoined: _dateJoinedCtrl.text,
          isActive: _isActive,
          classTeacherClassArmId: _classTeacherClassArmId,
          subjectIds: _subjectIds,
        ),
      );
    } on StaffEditorValidationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff member saved.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteStaff() async {
    final existing = widget.existing;
    if (existing == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: const Text(
          'This removes the staff member from the active workspace and retires their teaching assignments in the sync queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _editor.deleteStaff(
        db: context.read<AppDatabase>(),
        user: user!,
        existing: existing,
      );
    } on StaffEditorValidationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff member deleted.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMetadata) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Staff' : 'Edit Staff'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staff Profile',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _staffNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Staff Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _departmentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dateJoinedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date Joined (YYYY-MM-DD)',
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
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _middleNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Middle Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'System Role *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                            value: 'cashier', child: Text('Cashier')),
                        DropdownMenuItem(
                            value: 'teacher', child: Text('Teacher')),
                      ],
                      onChanged: (value) => setState(() => _role = value!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _employmentType,
                      decoration: const InputDecoration(
                        labelText: 'Employment Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'permanent',
                          child: Text('Permanent'),
                        ),
                        DropdownMenuItem(
                          value: 'contract',
                          child: Text('Contract'),
                        ),
                        DropdownMenuItem(
                          value: 'volunteer',
                          child: Text('Volunteer'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _employmentType = value!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Teaching Assignments',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _classTeacherClassArmId,
                decoration: const InputDecoration(
                  labelText: 'Class Teacher Of',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No class teacher assignment'),
                  ),
                  ..._classArms.map(
                    (arm) => DropdownMenuItem<String?>(
                      value: arm.id,
                      child: Text(arm.displayName),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _classTeacherClassArmId = value),
              ),
              const SizedBox(height: 16),
              Text(
                'Subject Teacher Assignments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _subjects
                    .map(
                      (subject) => FilterChip(
                        label: Text(subject.name),
                        selected: _subjectIds.contains(subject.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _subjectIds.add(subject.id);
                            } else {
                              _subjectIds.remove(subject.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existing != null) ...[
                    TextButton(
                      onPressed: _saving ? null : _deleteStaff,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete Staff'),
                    ),
                    const SizedBox(width: 16),
                  ],
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
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
