import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/admissions/applicant_form_screen.dart';

class ApplicantListScreen extends StatefulWidget {
  const ApplicantListScreen({super.key});

  @override
  State<ApplicantListScreen> createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends State<ApplicantListScreen> {
  String? _filterStatus;

  static const _statuses = [
    'applied',
    'screened',
    'admitted',
    'enrolled',
    'rejected',
  ];

  LocalDataScope? _currentScope() {
    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      return null;
    }
    return LocalDataScope(
      tenantId: user!.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
  }

  Future<void> _setApplicantStatus(
    AppDatabase db,
    Applicant applicant,
    String status, {
    DateTime? admittedAt,
    String? studentId,
  }) async {
    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }

    await db.transaction(() async {
      await db.upsertApplicant(
        ApplicantsCompanion(
          id: Value(applicant.id),
          tenantId: Value(applicant.tenantId),
          schoolId: Value(applicant.schoolId),
          campusId: Value(applicant.campusId),
          firstName: Value(applicant.firstName),
          middleName: Value(applicant.middleName),
          lastName: Value(applicant.lastName),
          dateOfBirth: Value(applicant.dateOfBirth),
          gender: Value(applicant.gender),
          classLevelId: Value(applicant.classLevelId),
          academicYearId: Value(applicant.academicYearId),
          status: Value(status),
          guardianName: Value(applicant.guardianName),
          guardianPhone: Value(applicant.guardianPhone),
          guardianEmail: Value(applicant.guardianEmail),
          documentNotes: Value(applicant.documentNotes),
          studentId: Value(studentId ?? applicant.studentId),
          admittedAt: Value(admittedAt ?? applicant.admittedAt),
          syncStatus: const Value('local'),
          deleted: Value(applicant.deleted),
          createdAt: Value(applicant.createdAt),
        ),
      );

      await db.enqueueSyncChange(
        entityType: 'applicant',
        entityId: applicant.id,
        operation: 'update',
        payload: {
          'id': applicant.id,
          'tenantId': applicant.tenantId,
          'schoolId': applicant.schoolId,
          'campusId': applicant.campusId,
          'firstName': applicant.firstName,
          'middleName': applicant.middleName,
          'lastName': applicant.lastName,
          'dateOfBirth': applicant.dateOfBirth,
          'gender': applicant.gender,
          'classLevelId': applicant.classLevelId,
          'academicYearId': applicant.academicYearId,
          'guardianName': applicant.guardianName,
          'guardianPhone': applicant.guardianPhone,
          'guardianEmail': applicant.guardianEmail,
          'documentNotes': applicant.documentNotes,
          'status': status,
          'studentId': studentId ?? applicant.studentId,
          'admittedAt': (admittedAt ?? applicant.admittedAt)?.toIso8601String(),
          'baseServerRevision': applicant.serverRevision,
          'baseUpdatedAt': applicant.updatedAt.toIso8601String(),
        },
      );
    });
  }

  Future<void> _enrollApplicant(AppDatabase db, Applicant applicant) async {
    final user = context.read<AuthService>().currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }
    if (applicant.status != 'admitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applicant must be admitted first.')),
      );
      return;
    }

    final scope = _currentScope();
    if (scope == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tenant or school scope.')),
      );
      return;
    }
    final years = await db.getAcademicYears(scope: scope);
    final classArms = await db.getClassArms(
      scope: scope,
      classLevelId: applicant.classLevelId,
    );
    if (!mounted) {
      return;
    }

    final selection = await showDialog<_EnrollmentSelection>(
      context: context,
      builder: (context) {
        String? selectedYearId = applicant.academicYearId ??
            (years.where((item) => item.isCurrent).isNotEmpty
                ? years.firstWhere((item) => item.isCurrent).id
                : null);
        String? selectedClassArmId =
            classArms.isNotEmpty ? classArms.first.id : null;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enroll Applicant'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        border: OutlineInputBorder(),
                      ),
                      items: years
                          .map(
                            (year) => DropdownMenuItem(
                              value: year.id,
                              child: Text(year.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedYearId = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedClassArmId,
                      decoration: const InputDecoration(
                        labelText: 'Class Arm',
                        border: OutlineInputBorder(),
                      ),
                      items: classArms
                          .map(
                            (arm) => DropdownMenuItem(
                              value: arm.id,
                              child: Text(arm.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedClassArmId = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      selectedYearId == null || selectedClassArmId == null
                          ? null
                          : () => Navigator.pop(
                                context,
                                _EnrollmentSelection(
                                  academicYearId: selectedYearId!,
                                  classArmId: selectedClassArmId!,
                                ),
                              ),
                  child: const Text('Enroll'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selection == null) {
      return;
    }

    final todayIso = _todayIso();
    try {
      await db.enrollApplicantLocally(
        scope: scope,
        applicantId: applicant.id,
        academicYearId: selection.academicYearId,
        classArmId: selection.classArmId,
        enrollmentDate: todayIso,
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applicant enrolled and student record created.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Admissions',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 20),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterStatus == null,
                    onSelected: (_) => setState(() => _filterStatus = null),
                  ),
                  ..._statuses.map(
                    (status) => FilterChip(
                      label: Text(status),
                      selected: _filterStatus == status,
                      onSelected: (_) => setState(() => _filterStatus = status),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New Applicant'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ApplicantFormScreen()),
                ).then((_) => setState(() {})),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Applicant>>(
            future: (() {
              final scope = _currentScope();
              if (scope == null) {
                return Future.value(const <Applicant>[]);
              }
              return db.getApplicants(scope: scope, status: _filterStatus);
            })(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No applicants found.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Guardian')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Applied')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rows.map((applicant) {
                    return DataRow(
                      cells: [
                        DataCell(Text(
                            '${applicant.firstName} ${applicant.lastName}')),
                        DataCell(Text(applicant.guardianName ?? '-')),
                        DataCell(_StatusBadge(applicant.status)),
                        DataCell(
                          Text(applicant.createdAt
                              .toLocal()
                              .toString()
                              .substring(0, 10)),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              if (applicant.status == 'applied')
                                OutlinedButton(
                                  onPressed: () async {
                                    await _setApplicantStatus(
                                        db, applicant, 'screened');
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Screen'),
                                ),
                              if (applicant.status == 'applied' ||
                                  applicant.status == 'screened')
                                FilledButton.tonal(
                                  onPressed: () async {
                                    await _setApplicantStatus(
                                      db,
                                      applicant,
                                      'admitted',
                                      admittedAt: DateTime.now(),
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Admit'),
                                ),
                              if (applicant.status == 'admitted')
                                FilledButton(
                                  onPressed: () =>
                                      _enrollApplicant(db, applicant),
                                  child: const Text('Enroll'),
                                ),
                              if (applicant.status != 'rejected' &&
                                  applicant.status != 'enrolled')
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ApplicantFormScreen(
                                        applicant: applicant,
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) setState(() {});
                                  }),
                                  child: const Text('Edit'),
                                ),
                              if (applicant.status != 'rejected' &&
                                  applicant.status != 'enrolled')
                                TextButton(
                                  onPressed: () async {
                                    await _setApplicantStatus(
                                        db, applicant, 'rejected');
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Reject'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _EnrollmentSelection {
  const _EnrollmentSelection({
    required this.academicYearId,
    required this.classArmId,
  });

  final String academicYearId;
  final String classArmId;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'applied' => Colors.blue,
      'screened' => Colors.cyan,
      'admitted' => Colors.orange,
      'enrolled' => Colors.green,
      'rejected' => Colors.red,
      'withdrawn' => Colors.grey,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
