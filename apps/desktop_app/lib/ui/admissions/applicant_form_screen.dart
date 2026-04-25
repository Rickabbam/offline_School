import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';

class ApplicantFormScreen extends StatefulWidget {
  const ApplicantFormScreen({
    super.key,
    this.applicant,
  });

  final Applicant? applicant;

  @override
  State<ApplicantFormScreen> createState() => _ApplicantFormScreenState();
}

class _ApplicantFormScreenState extends State<ApplicantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _guardianNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _guardianEmailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _gender;
  String? _academicYearId;
  String? _classLevelId;
  bool _saving = false;
  bool _loadingMetadata = true;
  List<AcademicYearsCacheData> _academicYears = const [];
  List<ClassLevelsCacheData> _classLevels = const [];

  @override
  void initState() {
    super.initState();
    _seedExistingApplicant();
    _loadMetadata();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _dobCtrl,
      _guardianNameCtrl,
      _guardianPhoneCtrl,
      _guardianEmailCtrl,
      _notesCtrl,
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
    final levels = await db.getClassLevels(scope: scope);

    if (!mounted) {
      return;
    }

    final currentYearId = years.where((item) => item.isCurrent).isNotEmpty
        ? years.firstWhere((item) => item.isCurrent).id
        : null;

    setState(() {
      _academicYears = years;
      _classLevels = levels;
      _academicYearId = currentYearId;
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

    final db = context.read<AppDatabase>();
    final tenantId = user!.tenantId!;
    final schoolId = user.schoolId!;
    final campusId = user.campusId;
    final existingApplicant = widget.applicant;
    if (existingApplicant == null) {
      final id = const Uuid().v4();
      await db.transaction(() async {
        await db.upsertApplicant(
          ApplicantsCompanion(
            id: Value(id),
            tenantId: Value(tenantId),
            schoolId: Value(schoolId),
            campusId: Value(campusId),
            firstName: Value(_firstNameCtrl.text.trim()),
            middleName: Value(_nullIfBlank(_middleNameCtrl.text)),
            lastName: Value(_lastNameCtrl.text.trim()),
            dateOfBirth: Value(_nullIfBlank(_dobCtrl.text)),
            gender: Value(_gender),
            classLevelId: Value(_classLevelId),
            academicYearId: Value(_academicYearId),
            guardianName: Value(_nullIfBlank(_guardianNameCtrl.text)),
            guardianPhone: Value(_nullIfBlank(_guardianPhoneCtrl.text)),
            guardianEmail: Value(_nullIfBlank(_guardianEmailCtrl.text)),
            documentNotes: Value(_nullIfBlank(_notesCtrl.text)),
            status: const Value('applied'),
            syncStatus: const Value('local'),
          ),
        );

        await db.enqueueSyncChange(
          entityType: 'applicant',
          entityId: id,
          operation: 'create',
          payload: {
            'id': id,
            'tenantId': tenantId,
            'schoolId': schoolId,
            'campusId': campusId,
            'firstName': _firstNameCtrl.text.trim(),
            'middleName': _nullIfBlank(_middleNameCtrl.text),
            'lastName': _lastNameCtrl.text.trim(),
            'dateOfBirth': _nullIfBlank(_dobCtrl.text),
            'gender': _gender,
            'classLevelId': _classLevelId,
            'academicYearId': _academicYearId,
            'guardianName': _nullIfBlank(_guardianNameCtrl.text),
            'guardianPhone': _nullIfBlank(_guardianPhoneCtrl.text),
            'guardianEmail': _nullIfBlank(_guardianEmailCtrl.text),
            'documentNotes': _nullIfBlank(_notesCtrl.text),
            'status': 'applied',
          },
        );
      });
    } else {
      try {
        await db.updateApplicantLocally(
          scope: LocalDataScope(
            tenantId: tenantId,
            schoolId: schoolId,
            campusId: campusId,
          ),
          applicantId: existingApplicant.id,
          firstName: _firstNameCtrl.text.trim(),
          middleName: _nullIfBlank(_middleNameCtrl.text),
          lastName: _lastNameCtrl.text.trim(),
          dateOfBirth: _nullIfBlank(_dobCtrl.text),
          gender: _gender,
          classLevelId: _classLevelId,
          academicYearId: _academicYearId,
          guardianName: _nullIfBlank(_guardianNameCtrl.text),
          guardianPhone: _nullIfBlank(_guardianPhoneCtrl.text),
          guardianEmail: _nullIfBlank(_guardianEmailCtrl.text),
          documentNotes: _nullIfBlank(_notesCtrl.text),
        );
      } on StateError catch (error) {
        if (!mounted) {
          return;
        }
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existingApplicant == null
              ? 'Applicant registered.'
              : 'Applicant updated.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _seedExistingApplicant() {
    final applicant = widget.applicant;
    if (applicant == null) {
      return;
    }

    _firstNameCtrl.text = applicant.firstName;
    _middleNameCtrl.text = applicant.middleName ?? '';
    _lastNameCtrl.text = applicant.lastName;
    _dobCtrl.text = applicant.dateOfBirth ?? '';
    _guardianNameCtrl.text = applicant.guardianName ?? '';
    _guardianPhoneCtrl.text = applicant.guardianPhone ?? '';
    _guardianEmailCtrl.text = applicant.guardianEmail ?? '';
    _notesCtrl.text = applicant.documentNotes ?? '';
    _gender = applicant.gender;
    _academicYearId = applicant.academicYearId;
    _classLevelId = applicant.classLevelId;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMetadata) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.applicant == null ? 'New Applicant' : 'Edit Applicant'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
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
                      initialValue: _academicYearId,
                      decoration: const InputDecoration(
                        labelText: 'Target Academic Year',
                        border: OutlineInputBorder(),
                      ),
                      items: _academicYears
                          .map(
                            (year) => DropdownMenuItem(
                              value: year.id,
                              child: Text(year.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _academicYearId = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _classLevelId,
                      decoration: const InputDecoration(
                        labelText: 'Target Class Level',
                        border: OutlineInputBorder(),
                      ),
                      items: _classLevels
                          .map(
                            (level) => DropdownMenuItem(
                              value: level.id,
                              child: Text(level.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _classLevelId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guardianNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guardian/Parent Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Document Notes',
                  hintText: 'List physical documents received...',
                  border: OutlineInputBorder(),
                ),
              ),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.applicant == null
                                ? 'Register Applicant'
                                : 'Save Applicant',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
