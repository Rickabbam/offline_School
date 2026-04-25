import 'package:flutter/material.dart';

import 'package:desktop_app/ui/settings/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.service});

  final SettingsService service;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _schoolFormKey = GlobalKey<FormState>();
  final _campusFormKey = GlobalKey<FormState>();
  final _yearFormKey = GlobalKey<FormState>();
  final _termFormKey = GlobalKey<FormState>();
  final _classLevelFormKey = GlobalKey<FormState>();
  final _classArmFormKey = GlobalKey<FormState>();
  final _subjectFormKey = GlobalKey<FormState>();
  final _gradingSchemeFormKey = GlobalKey<FormState>();

  late final TextEditingController _schoolNameCtrl;
  late final TextEditingController _shortNameCtrl;
  late final TextEditingController _schoolAddressCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _schoolPhoneCtrl;
  late final TextEditingController _schoolEmailCtrl;
  late final TextEditingController _campusNameCtrl;
  late final TextEditingController _campusAddressCtrl;
  late final TextEditingController _campusPhoneCtrl;
  late final TextEditingController _registrationCodeCtrl;
  late final TextEditingController _yearLabelCtrl;
  late final TextEditingController _yearStartCtrl;
  late final TextEditingController _yearEndCtrl;
  late final TextEditingController _termNameCtrl;
  late final TextEditingController _termNumberCtrl;
  late final TextEditingController _termStartCtrl;
  late final TextEditingController _termEndCtrl;
  late final TextEditingController _classLevelNameCtrl;
  late final TextEditingController _classLevelSortOrderCtrl;
  late final TextEditingController _classArmCtrl;
  late final TextEditingController _subjectNameCtrl;
  late final TextEditingController _subjectCodeCtrl;
  late final TextEditingController _gradingSchemeNameCtrl;
  late final TextEditingController _gradingBandsCtrl;

  SettingsWorkspaceData? _data;
  bool _loading = true;
  bool _savingSchool = false;
  bool _savingCampus = false;
  bool _creatingYear = false;
  bool _creatingTerm = false;
  bool _creatingClassLevel = false;
  bool _creatingClassArm = false;
  bool _creatingSubject = false;
  bool _creatingGradingScheme = false;
  bool _yearIsCurrent = false;
  bool _termIsCurrent = false;
  bool _gradingSchemeIsDefault = true;
  String? _selectedYearId;
  String? _selectedClassLevelId;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _schoolNameCtrl = TextEditingController();
    _shortNameCtrl = TextEditingController();
    _schoolAddressCtrl = TextEditingController();
    _regionCtrl = TextEditingController();
    _districtCtrl = TextEditingController();
    _schoolPhoneCtrl = TextEditingController();
    _schoolEmailCtrl = TextEditingController();
    _campusNameCtrl = TextEditingController();
    _campusAddressCtrl = TextEditingController();
    _campusPhoneCtrl = TextEditingController();
    _registrationCodeCtrl = TextEditingController();
    _yearLabelCtrl = TextEditingController();
    _yearStartCtrl = TextEditingController();
    _yearEndCtrl = TextEditingController();
    _termNameCtrl = TextEditingController();
    _termNumberCtrl = TextEditingController(text: '1');
    _termStartCtrl = TextEditingController();
    _termEndCtrl = TextEditingController();
    _classLevelNameCtrl = TextEditingController();
    _classLevelSortOrderCtrl = TextEditingController(text: '0');
    _classArmCtrl = TextEditingController();
    _subjectNameCtrl = TextEditingController();
    _subjectCodeCtrl = TextEditingController();
    _gradingSchemeNameCtrl = TextEditingController(text: 'Default');
    _gradingBandsCtrl =
        TextEditingController(text: 'A,80,100,Excellent\nB,70,79,Very Good');
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _schoolNameCtrl,
      _shortNameCtrl,
      _schoolAddressCtrl,
      _regionCtrl,
      _districtCtrl,
      _schoolPhoneCtrl,
      _schoolEmailCtrl,
      _campusNameCtrl,
      _campusAddressCtrl,
      _campusPhoneCtrl,
      _registrationCodeCtrl,
      _yearLabelCtrl,
      _yearStartCtrl,
      _yearEndCtrl,
      _termNameCtrl,
      _termNumberCtrl,
      _termStartCtrl,
      _termEndCtrl,
      _classLevelNameCtrl,
      _classLevelSortOrderCtrl,
      _classArmCtrl,
      _subjectNameCtrl,
      _subjectCodeCtrl,
      _gradingSchemeNameCtrl,
      _gradingBandsCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.loadWorkspace();
      if (!mounted) return;
      _applyData(data);
      setState(() {
        _data = data;
        _selectedYearId = data.academicYears.isNotEmpty
            ? '${data.academicYears.first['id']}'
            : null;
        _selectedClassLevelId = data.classLevels.isNotEmpty
            ? '${data.classLevels.first['id']}'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load settings workspace: $e';
        _loading = false;
      });
    }
  }

  void _applyData(SettingsWorkspaceData data) {
    _schoolNameCtrl.text = '${data.school['name'] ?? ''}';
    _shortNameCtrl.text = '${data.school['shortName'] ?? ''}';
    _schoolAddressCtrl.text = '${data.school['address'] ?? ''}';
    _regionCtrl.text = '${data.school['region'] ?? ''}';
    _districtCtrl.text = '${data.school['district'] ?? ''}';
    _schoolPhoneCtrl.text = '${data.school['contactPhone'] ?? ''}';
    _schoolEmailCtrl.text = '${data.school['contactEmail'] ?? ''}';
    _campusNameCtrl.text = '${data.campus['name'] ?? ''}';
    _campusAddressCtrl.text = '${data.campus['address'] ?? ''}';
    _campusPhoneCtrl.text = '${data.campus['contactPhone'] ?? ''}';
    _registrationCodeCtrl.text = '${data.campus['registrationCode'] ?? ''}';
  }

  SettingsWorkspaceData _copyData({
    Map<String, dynamic>? tenant,
    Map<String, dynamic>? school,
    Map<String, dynamic>? campus,
    List<Map<String, dynamic>>? academicYears,
    List<Map<String, dynamic>>? terms,
    List<Map<String, dynamic>>? classLevels,
    List<Map<String, dynamic>>? classArms,
    List<Map<String, dynamic>>? subjects,
    List<Map<String, dynamic>>? gradingSchemes,
    List<Map<String, dynamic>>? trustedDevices,
    List<Map<String, dynamic>>? auditEntries,
  }) {
    final data = _data!;
    return SettingsWorkspaceData(
      tenant: tenant ?? data.tenant,
      school: school ?? data.school,
      campus: campus ?? data.campus,
      academicYears: academicYears ?? data.academicYears,
      terms: terms ?? data.terms,
      classLevels: classLevels ?? data.classLevels,
      classArms: classArms ?? data.classArms,
      subjects: subjects ?? data.subjects,
      gradingSchemes: gradingSchemes ?? data.gradingSchemes,
      trustedDevices: trustedDevices ?? data.trustedDevices,
      auditEntries: auditEntries ?? data.auditEntries,
    );
  }

  Future<void> _saveSchool() async {
    if (!_schoolFormKey.currentState!.validate()) return;
    setState(() {
      _savingSchool = true;
      _status = null;
      _error = null;
    });

    try {
      final school = await widget.service.updateSchool(
        name: _schoolNameCtrl.text.trim(),
        shortName: _shortNameCtrl.text,
        address: _schoolAddressCtrl.text,
        region: _regionCtrl.text,
        district: _districtCtrl.text,
        contactPhone: _schoolPhoneCtrl.text,
        contactEmail: _schoolEmailCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _data = _copyData(school: school);
        _savingSchool = false;
        _status = 'School profile updated.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingSchool = false;
        _error = 'Failed to update school profile: $e';
      });
    }
  }

  Future<void> _saveCampus() async {
    if (!_campusFormKey.currentState!.validate()) return;
    setState(() {
      _savingCampus = true;
      _status = null;
      _error = null;
    });

    try {
      final campus = await widget.service.updateCampus(
        name: _campusNameCtrl.text.trim(),
        address: _campusAddressCtrl.text,
        contactPhone: _campusPhoneCtrl.text,
        registrationCode: _registrationCodeCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _data = _copyData(campus: campus);
        _savingCampus = false;
        _status = 'Campus profile updated.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingCampus = false;
        _error = 'Failed to update campus profile: $e';
      });
    }
  }

  Future<void> _createAcademicYear() async {
    if (!_yearFormKey.currentState!.validate()) return;
    setState(() {
      _creatingYear = true;
      _status = null;
      _error = null;
    });

    try {
      final year = await widget.service.createAcademicYear(
        label: _yearLabelCtrl.text.trim(),
        startDate: _yearStartCtrl.text.trim(),
        endDate: _yearEndCtrl.text.trim(),
        isCurrent: _yearIsCurrent,
      );
      if (!mounted) return;
      _yearLabelCtrl.clear();
      _yearStartCtrl.clear();
      _yearEndCtrl.clear();
      setState(() {
        _selectedYearId ??= '${year['id']}';
        _yearIsCurrent = false;
        _creatingYear = false;
        _data = _copyData(academicYears: [..._data!.academicYears, year]);
        _status = 'Academic year created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingYear = false;
        _error = 'Failed to create academic year: $e';
      });
    }
  }

  Future<void> _createTerm() async {
    if (!_termFormKey.currentState!.validate() || _selectedYearId == null) {
      return;
    }
    setState(() {
      _creatingTerm = true;
      _status = null;
      _error = null;
    });

    try {
      final term = await widget.service.createTerm(
        academicYearId: _selectedYearId!,
        name: _termNameCtrl.text.trim(),
        termNumber: int.parse(_termNumberCtrl.text.trim()),
        startDate: _termStartCtrl.text.trim(),
        endDate: _termEndCtrl.text.trim(),
        isCurrent: _termIsCurrent,
      );
      if (!mounted) return;
      _termNameCtrl.clear();
      _termNumberCtrl.text = '1';
      _termStartCtrl.clear();
      _termEndCtrl.clear();
      setState(() {
        _termIsCurrent = false;
        _creatingTerm = false;
        _data = _copyData(terms: [..._data!.terms, term]);
        _status = 'Term created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingTerm = false;
        _error = 'Failed to create term: $e';
      });
    }
  }

  Future<void> _createClassLevel() async {
    if (!_classLevelFormKey.currentState!.validate()) return;
    setState(() {
      _creatingClassLevel = true;
      _status = null;
      _error = null;
    });

    try {
      final classLevel = await widget.service.createClassLevel(
        name: _classLevelNameCtrl.text.trim(),
        sortOrder: int.parse(_classLevelSortOrderCtrl.text.trim()),
      );
      if (!mounted) return;
      _classLevelNameCtrl.clear();
      _classLevelSortOrderCtrl.text = '0';
      setState(() {
        _selectedClassLevelId ??= '${classLevel['id']}';
        _creatingClassLevel = false;
        _data = _copyData(
          classLevels: [..._data!.classLevels, classLevel]..sort((a, b) =>
              ((a['sortOrder'] as num?) ?? 0)
                  .compareTo((b['sortOrder'] as num?) ?? 0)),
        );
        _status = 'Class level created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingClassLevel = false;
        _error = 'Failed to create class level: $e';
      });
    }
  }

  Future<void> _createClassArm() async {
    if (!_classArmFormKey.currentState!.validate() ||
        _selectedClassLevelId == null) {
      return;
    }
    final level = _data!.classLevels
        .firstWhere((item) => '${item['id']}' == _selectedClassLevelId);
    final arm = _classArmCtrl.text.trim();
    setState(() {
      _creatingClassArm = true;
      _status = null;
      _error = null;
    });

    try {
      final classArm = await widget.service.createClassArm(
        classLevelId: _selectedClassLevelId!,
        arm: arm,
        displayName: '${level['name']} $arm',
      );
      if (!mounted) return;
      _classArmCtrl.clear();
      setState(() {
        _creatingClassArm = false;
        _data = _copyData(classArms: [..._data!.classArms, classArm]);
        _status = 'Class arm created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingClassArm = false;
        _error = 'Failed to create class arm: $e';
      });
    }
  }

  Future<void> _createSubject() async {
    if (!_subjectFormKey.currentState!.validate()) return;
    setState(() {
      _creatingSubject = true;
      _status = null;
      _error = null;
    });

    try {
      final subject = await widget.service.createSubject(
        name: _subjectNameCtrl.text.trim(),
        code: _subjectCodeCtrl.text,
      );
      if (!mounted) return;
      _subjectNameCtrl.clear();
      _subjectCodeCtrl.clear();
      setState(() {
        _creatingSubject = false;
        _data = _copyData(subjects: [..._data!.subjects, subject]);
        _status = 'Subject created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingSubject = false;
        _error = 'Failed to create subject: $e';
      });
    }
  }

  Future<void> _createGradingScheme() async {
    if (!_gradingSchemeFormKey.currentState!.validate()) return;
    setState(() {
      _creatingGradingScheme = true;
      _status = null;
      _error = null;
    });

    try {
      final scheme = await widget.service.createGradingScheme(
        name: _gradingSchemeNameCtrl.text.trim(),
        bands: _parseBands(_gradingBandsCtrl.text),
        isDefault: _gradingSchemeIsDefault,
      );
      if (!mounted) return;
      setState(() {
        _creatingGradingScheme = false;
        _data = _copyData(gradingSchemes: [..._data!.gradingSchemes, scheme]);
        _status = 'Grading scheme created.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingGradingScheme = false;
        _error = 'Failed to create grading scheme: $e';
      });
    }
  }

  Future<void> _deleteRecord({
    required String label,
    required String id,
    required Future<void> Function(String id) deleteAction,
    required SettingsWorkspaceData Function() nextData,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete $label'),
            content:
                Text('Remove this $label from the current school workspace?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() {
      _status = null;
      _error = null;
    });

    try {
      await deleteAction(id);
      if (!mounted) return;
      setState(() {
        _data = nextData();
        _status = '$label deleted.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to delete $label: $e';
      });
    }
  }

  Future<void> _editAcademicYear(Map<String, dynamic> item) async {
    final labelCtrl = TextEditingController(text: '${item['label'] ?? ''}');
    final startCtrl = TextEditingController(text: '${item['startDate'] ?? ''}');
    final endCtrl = TextEditingController(text: '${item['endDate'] ?? ''}');
    var isCurrent = item['isCurrent'] == true;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Academic Year'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Start Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(
                      labelText: 'End Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isCurrent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as current'),
                    onChanged: (value) =>
                        setDialogState(() => isCurrent = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'label': labelCtrl.text.trim(),
                'startDate': startCtrl.text.trim(),
                'endDate': endCtrl.text.trim(),
                'isCurrent': isCurrent,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    labelCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'academic year',
      save: () =>
          widget.service.updateAcademicYear(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        academicYears: _replaceRecord(_data!.academicYears, updated),
      ),
    );
  }

  Future<void> _editTerm(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: '${item['name'] ?? ''}');
    final numberCtrl =
        TextEditingController(text: '${item['termNumber'] ?? ''}');
    final startCtrl = TextEditingController(text: '${item['startDate'] ?? ''}');
    final endCtrl = TextEditingController(text: '${item['endDate'] ?? ''}');
    var isCurrent = item['isCurrent'] == true;
    var academicYearId = '${item['academicYearId'] ?? _selectedYearId ?? ''}';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Term'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue:
                        academicYearId.isEmpty ? null : academicYearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _data!.academicYears
                        .map(
                          (year) => DropdownMenuItem<String>(
                            value: '${year['id']}',
                            child: Text('${year['label']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                        () => academicYearId = value ?? academicYearId),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: numberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Term Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Start Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(
                      labelText: 'End Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isCurrent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as current'),
                    onChanged: (value) =>
                        setDialogState(() => isCurrent = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'academicYearId': academicYearId,
                'name': nameCtrl.text.trim(),
                'termNumber':
                    int.tryParse(numberCtrl.text.trim()) ?? item['termNumber'],
                'startDate': startCtrl.text.trim(),
                'endDate': endCtrl.text.trim(),
                'isCurrent': isCurrent,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    numberCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'term',
      save: () => widget.service.updateTerm(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        terms: _replaceRecord(_data!.terms, updated),
      ),
    );
  }

  Future<void> _editClassLevel(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: '${item['name'] ?? ''}');
    final sortCtrl = TextEditingController(text: '${item['sortOrder'] ?? ''}');

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Class Level'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sort Order',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameCtrl.text.trim(),
              'sortOrder':
                  int.tryParse(sortCtrl.text.trim()) ?? item['sortOrder'],
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    sortCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'class level',
      save: () =>
          widget.service.updateClassLevel(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        classLevels: _replaceRecord(
          _data!.classLevels,
          updated,
          sort: (a, b) => ((a['sortOrder'] as num?) ?? 0)
              .compareTo((b['sortOrder'] as num?) ?? 0),
        ),
      ),
    );
  }

  Future<void> _editClassArm(Map<String, dynamic> item) async {
    final armCtrl = TextEditingController(text: '${item['arm'] ?? ''}');
    var classLevelId = '${item['classLevelId'] ?? _selectedClassLevelId ?? ''}';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Class Arm'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: classLevelId.isEmpty ? null : classLevelId,
                  decoration: const InputDecoration(
                    labelText: 'Class Level',
                    border: OutlineInputBorder(),
                  ),
                  items: _data!.classLevels
                      .map(
                        (level) => DropdownMenuItem<String>(
                          value: '${level['id']}',
                          child: Text('${level['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(
                      () => classLevelId = value ?? classLevelId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: armCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Arm',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final level = _data!.classLevels.firstWhere(
                  (entry) => '${entry['id']}' == classLevelId,
                  orElse: () => item,
                );
                Navigator.of(context).pop({
                  'classLevelId': classLevelId,
                  'arm': armCtrl.text.trim(),
                  'displayName': '${level['name']} ${armCtrl.text.trim()}',
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    armCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'class arm',
      save: () =>
          widget.service.updateClassArm(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        classArms: _replaceRecord(_data!.classArms, updated),
      ),
    );
  }

  Future<void> _editSubject(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: '${item['name'] ?? ''}');
    final codeCtrl = TextEditingController(text: '${item['code'] ?? ''}');

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subject'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameCtrl.text.trim(),
              'code':
                  codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'subject',
      save: () =>
          widget.service.updateSubject(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        subjects: _replaceRecord(_data!.subjects, updated),
      ),
    );
  }

  Future<void> _editGradingScheme(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: '${item['name'] ?? ''}');
    final bandsCtrl = TextEditingController(text: _formatBands(item['bands']));
    var isDefault = item['isDefault'] == true;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Grading Scheme'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Scheme Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bandsCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Bands: grade,min,max,remark per line',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isDefault,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as default'),
                    onChanged: (value) =>
                        setDialogState(() => isDefault = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'name': nameCtrl.text.trim(),
                'bands': _parseBands(bandsCtrl.text),
                'isDefault': isDefault,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    bandsCtrl.dispose();
    if (payload == null) return;

    await _runRecordUpdate(
      label: 'grading scheme',
      save: () => widget.service
          .updateGradingScheme(id: '${item['id']}', data: payload),
      apply: (updated) => _copyData(
        gradingSchemes: _replaceRecord(_data!.gradingSchemes, updated),
      ),
    );
  }

  Future<void> _runRecordUpdate({
    required String label,
    required Future<Map<String, dynamic>> Function() save,
    required SettingsWorkspaceData Function(Map<String, dynamic> updated) apply,
  }) async {
    setState(() {
      _status = null;
      _error = null;
    });

    try {
      final updated = await save();
      if (!mounted) return;
      setState(() {
        _data = apply(updated);
        _status = '$label updated.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to update $label: $e';
      });
    }
  }

  List<Map<String, dynamic>> _replaceRecord(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> updated, {
    int Function(Map<String, dynamic> a, Map<String, dynamic> b)? sort,
  }) {
    final next = items
        .map(
            (entry) => '${entry['id']}' == '${updated['id']}' ? updated : entry)
        .toList(growable: false);
    if (sort == null) {
      return next;
    }
    return [...next]..sort(sort);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = _data!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings Workspace',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Manage the active school, campus, and academic structure for this workspace.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (_status != null || _error != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(
                message: _status ?? _error!, isError: _error != null),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              SizedBox(width: 520, child: _buildSchoolCard(context)),
              SizedBox(width: 420, child: _buildCampusCard(context)),
            ],
          ),
          const SizedBox(height: 24),
          _buildAcademicManagement(context),
          const SizedBox(height: 24),
          _buildAcademicSnapshot(context, data),
          const SizedBox(height: 24),
          _buildControlPlaneSnapshot(context, data),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _schoolFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School Profile',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'School Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shortNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Short Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schoolAddressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regionCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Region', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _districtCtrl,
                      decoration: const InputDecoration(
                          labelText: 'District', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _schoolPhoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Contact Phone',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _schoolEmailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Contact Email',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _savingSchool ? null : _saveSchool,
                  child: Text(_savingSchool ? 'Saving...' : 'Save School'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _campusFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Campus Profile',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _campusNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Campus Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _campusAddressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _campusPhoneCtrl,
                decoration: const InputDecoration(
                    labelText: 'Contact Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registrationCodeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Registration Code',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _savingCampus ? null : _saveCampus,
                  child: Text(_savingCampus ? 'Saving...' : 'Save Campus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicManagement(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        SizedBox(width: 320, child: _buildAcademicYearCard(context)),
        SizedBox(width: 320, child: _buildTermCard(context)),
        SizedBox(width: 320, child: _buildClassLevelCard(context)),
        SizedBox(width: 320, child: _buildClassArmCard(context)),
        SizedBox(width: 320, child: _buildSubjectCard(context)),
        SizedBox(width: 360, child: _buildGradingSchemeCard(context)),
      ],
    );
  }

  Widget _buildAcademicYearCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _yearFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Academic Year',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearLabelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Label', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearStartCtrl,
                decoration: const InputDecoration(
                    labelText: 'Start Date (YYYY-MM-DD)',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearEndCtrl,
                decoration: const InputDecoration(
                    labelText: 'End Date (YYYY-MM-DD)',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as current'),
                value: _yearIsCurrent,
                onChanged: (value) =>
                    setState(() => _yearIsCurrent = value ?? false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _creatingYear ? null : _createAcademicYear,
                  child: Text(_creatingYear ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _termFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Term', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedYearId,
                decoration: const InputDecoration(
                    labelText: 'Academic Year', border: OutlineInputBorder()),
                items: _data!.academicYears
                    .map((year) => DropdownMenuItem<String>(
                          value: '${year['id']}',
                          child: Text('${year['label']}'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedYearId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Term Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Term Number', border: OutlineInputBorder()),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termStartCtrl,
                decoration: const InputDecoration(
                    labelText: 'Start Date (YYYY-MM-DD)',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termEndCtrl,
                decoration: const InputDecoration(
                    labelText: 'End Date (YYYY-MM-DD)',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as current'),
                value: _termIsCurrent,
                onChanged: (value) =>
                    setState(() => _termIsCurrent = value ?? false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _creatingTerm ? null : _createTerm,
                  child: Text(_creatingTerm ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassLevelCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _classLevelFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Class Level',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _classLevelNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classLevelSortOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sort Order', border: OutlineInputBorder()),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _creatingClassLevel ? null : _createClassLevel,
                  child: Text(_creatingClassLevel ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassArmCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _classArmFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Class Arm',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedClassLevelId,
                decoration: const InputDecoration(
                    labelText: 'Class Level', border: OutlineInputBorder()),
                items: _data!.classLevels
                    .map((level) => DropdownMenuItem<String>(
                          value: '${level['id']}',
                          child: Text('${level['name']}'),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedClassLevelId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classArmCtrl,
                decoration: const InputDecoration(
                    labelText: 'Arm', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _creatingClassArm ? null : _createClassArm,
                  child: Text(_creatingClassArm ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _subjectFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Subject',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subject Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCodeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _creatingSubject ? null : _createSubject,
                  child: Text(_creatingSubject ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradingSchemeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _gradingSchemeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Grading Scheme',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gradingSchemeNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Scheme Name', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gradingBandsCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Bands: grade,min,max,remark per line',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as default'),
                value: _gradingSchemeIsDefault,
                onChanged: (value) =>
                    setState(() => _gradingSchemeIsDefault = value ?? true),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed:
                      _creatingGradingScheme ? null : _createGradingScheme,
                  child:
                      Text(_creatingGradingScheme ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicSnapshot(
      BuildContext context, SettingsWorkspaceData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Academic Snapshot',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                    label: 'Academic Years',
                    value: '${data.academicYears.length}'),
                _MetricCard(label: 'Terms', value: '${data.terms.length}'),
                _MetricCard(
                    label: 'Class Levels', value: '${data.classLevels.length}'),
                _MetricCard(
                    label: 'Class Arms', value: '${data.classArms.length}'),
                _MetricCard(
                    label: 'Subjects', value: '${data.subjects.length}'),
                _MetricCard(
                    label: 'Grading Schemes',
                    value: '${data.gradingSchemes.length}'),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _SummaryList(
                  title: 'Academic Years',
                  items: data.academicYears
                      .map((item) => '${item['label']}')
                      .toList(),
                  emptyState: 'No academic years found.',
                ),
                _SummaryList(
                  title: 'Terms',
                  items: data.terms.map((item) => '${item['name']}').toList(),
                  emptyState: 'No terms found.',
                ),
                _SummaryList(
                  title: 'Class Levels',
                  items: data.classLevels
                      .map((item) => '${item['name']}')
                      .toList(),
                  emptyState: 'No class levels found.',
                ),
                _SummaryList(
                  title: 'Class Arms',
                  items: data.classArms
                      .map((item) => '${item['displayName']}')
                      .toList(),
                  emptyState: 'No class arms found.',
                ),
                _SummaryList(
                  title: 'Subjects',
                  items:
                      data.subjects.map((item) => '${item['name']}').toList(),
                  emptyState: 'No subjects found.',
                ),
                _SummaryList(
                  title: 'Grading Schemes',
                  items: data.gradingSchemes
                      .map((item) => '${item['name']}')
                      .toList(),
                  emptyState: 'No grading schemes found.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Manage Records',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ManageList(
                  title: 'Academic Years',
                  items: data.academicYears,
                  labelBuilder: (item) => '${item['label']}',
                  onEdit: _editAcademicYear,
                  onDelete: (item) => _deleteRecord(
                    label: 'academic year',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteAcademicYear,
                    nextData: () => _copyData(
                      academicYears: data.academicYears
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
                _ManageList(
                  title: 'Terms',
                  items: data.terms,
                  labelBuilder: (item) => '${item['name']}',
                  onEdit: _editTerm,
                  onDelete: (item) => _deleteRecord(
                    label: 'term',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteTerm,
                    nextData: () => _copyData(
                      terms: data.terms
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
                _ManageList(
                  title: 'Class Levels',
                  items: data.classLevels,
                  labelBuilder: (item) => '${item['name']}',
                  onEdit: _editClassLevel,
                  onDelete: (item) => _deleteRecord(
                    label: 'class level',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteClassLevel,
                    nextData: () => _copyData(
                      classLevels: data.classLevels
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
                _ManageList(
                  title: 'Class Arms',
                  items: data.classArms,
                  labelBuilder: (item) => '${item['displayName']}',
                  onEdit: _editClassArm,
                  onDelete: (item) => _deleteRecord(
                    label: 'class arm',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteClassArm,
                    nextData: () => _copyData(
                      classArms: data.classArms
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
                _ManageList(
                  title: 'Subjects',
                  items: data.subjects,
                  labelBuilder: (item) => '${item['name']}',
                  onEdit: _editSubject,
                  onDelete: (item) => _deleteRecord(
                    label: 'subject',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteSubject,
                    nextData: () => _copyData(
                      subjects: data.subjects
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
                _ManageList(
                  title: 'Grading Schemes',
                  items: data.gradingSchemes,
                  labelBuilder: (item) => '${item['name']}',
                  onEdit: _editGradingScheme,
                  onDelete: (item) => _deleteRecord(
                    label: 'grading scheme',
                    id: '${item['id']}',
                    deleteAction: widget.service.deleteGradingScheme,
                    nextData: () => _copyData(
                      gradingSchemes: data.gradingSchemes
                          .where((entry) => '${entry['id']}' != '${item['id']}')
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPlaneSnapshot(
      BuildContext context, SettingsWorkspaceData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Control Plane Activity',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Recent trusted-device and workflow changes for the active scope.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Trusted Devices',
                  value: '${data.trustedDevices.length}',
                ),
                _MetricCard(
                  label: 'Recent Audit Events',
                  value: '${data.auditEntries.length}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _AuditEntryList(entries: data.auditEntries),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseBands(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw const FormatException('Enter at least one grading band.');
    }
    return lines.map((line) {
      final parts = line.split(',').map((part) => part.trim()).toList();
      if (parts.length != 4) {
        throw FormatException('Invalid grading band line: $line');
      }
      final min = int.tryParse(parts[1]);
      final max = int.tryParse(parts[2]);
      if (min == null || max == null) {
        throw FormatException('Invalid grading range in line: $line');
      }
      return {'grade': parts[0], 'min': min, 'max': max, 'remark': parts[3]};
    }).toList(growable: false);
  }

  String _formatBands(dynamic raw) {
    if (raw is! List) {
      return '';
    }
    return raw
        .whereType<Map>()
        .map(
          (band) =>
              '${band['grade'] ?? ''},${band['min'] ?? ''},${band['max'] ?? ''},${band['remark'] ?? ''}',
        )
        .join('\n');
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _SummaryList extends StatelessWidget {
  const _SummaryList({
    required this.title,
    required this.items,
    required this.emptyState,
  });

  final String title;
  final List<String> items;
  final String emptyState;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyState, style: Theme.of(context).textTheme.bodyMedium)
          else
            ...items.take(8).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(item,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ManageList extends StatelessWidget {
  const _ManageList({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) labelBuilder;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text('No records yet.',
                    style: Theme.of(context).textTheme.bodyMedium)
              else
                ...items.take(8).map(
                      (item) => Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                labelBuilder(item),
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => onEdit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => onDelete(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? colorScheme.onErrorContainer
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _AuditEntryList extends StatelessWidget {
  const _AuditEntryList({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'No recent audit activity in this scope.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: entries.take(8).map((entry) {
        final eventType = '${entry['eventType'] ?? 'unknown_event'}';
        final entityLabel =
            '${entry['entityType'] ?? 'record'}/${entry['entityId'] ?? 'unknown'}';
        final createdAt = '${entry['createdAt'] ?? ''}';
        final metadata = entry['metadata'];
        final metadataSummary = metadata is Map && metadata.isNotEmpty
            ? metadata.entries
                .take(2)
                .map((item) => '${item.key}: ${item.value}')
                .join(' • ')
            : null;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eventType, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(entityLabel,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(createdAt, style: Theme.of(context).textTheme.bodySmall),
              if (metadataSummary != null) ...[
                const SizedBox(height: 6),
                Text(
                  metadataSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
