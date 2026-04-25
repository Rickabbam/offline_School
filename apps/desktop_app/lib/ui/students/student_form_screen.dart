import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/students/student_editor_service.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.existing});

  final Student? existing;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _editor = StudentEditorService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _guardianFirstNameCtrl = TextEditingController();
  final _guardianLastNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _guardianEmailCtrl = TextEditingController();

  String? _gender;
  String _status = 'active';
  String _guardianRelationship = 'guardian';
  String? _academicYearId;
  String? _classArmId;
  bool _saving = false;
  bool _loadingMetadata = true;

  String? _guardianId;
  String? _currentEnrollmentId;
  List<AcademicYearsCacheData> _academicYears = const [];
  List<ClassArmsCacheData> _classArms = const [];

  @override
  void initState() {
    super.initState();
    final student = widget.existing;
    if (student != null) {
      _firstNameCtrl.text = student.firstName;
      _middleNameCtrl.text = student.middleName ?? '';
      _lastNameCtrl.text = student.lastName;
      _studentNumberCtrl.text = student.studentNumber ?? '';
      _dobCtrl.text = student.dateOfBirth ?? '';
      _gender = student.gender;
      _status = student.status;
    }
    _loadMetadata();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _studentNumberCtrl,
      _dobCtrl,
      _guardianFirstNameCtrl,
      _guardianLastNameCtrl,
      _guardianPhoneCtrl,
      _guardianEmailCtrl,
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
    final years = await db.getAcademicYears(scope: scope);
    final classArms = await db.getClassArms(scope: scope);

    String? guardianId;
    String? academicYearId;
    String? classArmId;
    String? currentEnrollmentId;

    final student = widget.existing;
    if (student != null) {
      final guardians = await db.getGuardiansForStudent(
        student.id,
        scope: scope,
      );
      if (guardians.isNotEmpty) {
        final guardian = guardians.first;
        guardianId = guardian.id;
        _guardianFirstNameCtrl.text = guardian.firstName;
        _guardianLastNameCtrl.text = guardian.lastName;
        _guardianPhoneCtrl.text = guardian.phone ?? '';
        _guardianEmailCtrl.text = guardian.email ?? '';
        _guardianRelationship = guardian.relationship;
      }

      final enrollments = await db.getEnrollmentsForStudent(
        student.id,
        scope: scope,
      );
      if (enrollments.isNotEmpty) {
        final enrollment = enrollments.first;
        currentEnrollmentId = enrollment.id;
        academicYearId = enrollment.academicYearId;
        classArmId = enrollment.classArmId;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _academicYears = years;
      _classArms = classArms;
      _guardianId = guardianId;
      _currentEnrollmentId = currentEnrollmentId;
      _academicYearId = academicYearId ??
          (years.where((item) => item.isCurrent).firstOrNull?.id);
      _classArmId = classArmId;
      _loadingMetadata = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }

    setState(() => _saving = true);

    final db = context.read<AppDatabase>();
    final isNew = widget.existing == null;

    try {
      await _editor.saveStudent(
        db: db,
        user: user!,
        existing: widget.existing,
        input: StudentEditorInput(
          firstName: _firstNameCtrl.text,
          middleName: _middleNameCtrl.text,
          lastName: _lastNameCtrl.text,
          studentNumber: _studentNumberCtrl.text,
          dateOfBirth: _dobCtrl.text,
          gender: _gender,
          status: _status,
          guardianFirstName: _guardianFirstNameCtrl.text,
          guardianLastName: _guardianLastNameCtrl.text,
          guardianPhone: _guardianPhoneCtrl.text,
          guardianEmail: _guardianEmailCtrl.text,
          guardianRelationship: _guardianRelationship,
          academicYearId: _academicYearId,
          classArmId: _classArmId,
          guardianId: _guardianId,
          currentEnrollmentId: _currentEnrollmentId,
        ),
      );
    } on StudentEditorValidationException catch (error) {
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
      SnackBar(
        content: Text(isNew ? 'Student added.' : 'Student updated.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteStudent() async {
    final existing = widget.existing;
    if (existing == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text(
          'This removes the student from the active workspace and queues the delete for sync. Guardian and enrollment links will also be retired.',
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
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = context.read<AppDatabase>();
    try {
      await _editor.deleteStudent(
        db: db,
        user: user!,
        existing: existing,
      );
    } on StudentEditorValidationException catch (error) {
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
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Student deleted.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    if (_loadingMetadata) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              Text('Student Profile',
                  style: Theme.of(context).textTheme.titleLarge),
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
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'First name is required.'
                          : null,
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
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Last name is required.'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _studentNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Student Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dobCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                          value: 'withdrawn',
                          child: Text('Withdrawn'),
                        ),
                        DropdownMenuItem(
                          value: 'graduated',
                          child: Text('Graduated'),
                        ),
                        DropdownMenuItem(
                          value: 'transferred',
                          child: Text('Transferred'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Guardian Link',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guardianFirstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guardian First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianLastNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _guardianRelationship,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'father', child: Text('Father')),
                        DropdownMenuItem(
                            value: 'mother', child: Text('Mother')),
                        DropdownMenuItem(
                          value: 'guardian',
                          child: Text('Guardian'),
                        ),
                        DropdownMenuItem(
                          value: 'sibling',
                          child: Text('Sibling'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setState(() => _guardianRelationship = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guardianPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Enrollment', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _academicYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Not assigned'),
                        ),
                        ..._academicYears.map(
                          (year) => DropdownMenuItem(
                            value: year.id,
                            child: Text(year.label),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _academicYearId = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _classArmId,
                      decoration: const InputDecoration(
                        labelText: 'Class Arm',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Not assigned'),
                        ),
                        ..._classArms.map(
                          (arm) => DropdownMenuItem(
                            value: arm.id,
                            child: Text(arm.displayName),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _classArmId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isNew) ...[
                    TextButton(
                      onPressed: _saving ? null : _deleteStudent,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete Student'),
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
