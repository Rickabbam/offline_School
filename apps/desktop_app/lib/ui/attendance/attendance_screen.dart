import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/attendance/attendance_capture_service.dart';
import 'package:desktop_app/ui/attendance/attendance_workspace_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.service});

  final AttendanceWorkspaceService service;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _statusOptions = ['present', 'absent', 'late', 'excused'];
  final _captureService = AttendanceCaptureService();

  AttendanceWorkspaceData? _workspace;
  String? _selectedClassArmId;
  DateTime _selectedDate = DateTime.now();
  bool _loadingWorkspace = true;
  String? _workspaceError;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _loadingWorkspace = true;
      _workspaceError = null;
    });

    try {
      final user = context.read<AuthService>().currentUser;
      if (user?.tenantId == null || user?.schoolId == null) {
        throw StateError('Missing tenant or school scope.');
      }
      final workspace = await widget.service.loadWorkspace(
        LocalDataScope(
          tenantId: user!.tenantId!,
          schoolId: user.schoolId!,
          campusId: user.campusId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _selectedClassArmId = workspace.classArms.isEmpty
            ? null
            : _selectedClassArmId ?? '${workspace.classArms.first['id']}';
        _loadingWorkspace = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _workspaceError = 'Failed to load attendance workspace: $error';
        _loadingWorkspace = false;
      });
    }
  }

  Future<void> _markAttendance(
    AppDatabase db,
    Student student,
    String status,
  ) async {
    if (_selectedClassArmId == null) return;

    final workspace = _workspace;
    final user = context.read<AuthService>().currentUser;
    if (workspace == null ||
        workspace.currentAcademicYearId == null ||
        workspace.currentTermId == null ||
        user == null ||
        user.tenantId == null ||
        user.schoolId == null) {
      if (!mounted) return;
      setState(() {
        _workspaceError =
            'Attendance requires an active academic year, term, and school scope.';
      });
      return;
    }

    await _captureService.markAttendance(
      db: db,
      user: user,
      student: student,
      classArmId: _selectedClassArmId!,
      academicYearId: workspace.currentAcademicYearId!,
      termId: workspace.currentTermId!,
      date: _selectedDate,
      status: status,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<_AttendanceClassData> _loadClassData(AppDatabase db) async {
    final classArmId = _selectedClassArmId;
    final workspace = _workspace;
    final user = context.read<AuthService>().currentUser;
    if (classArmId == null) {
      return const _AttendanceClassData(
        students: [],
        dailyRecords: [],
        termRecords: [],
      );
    }
    if (user?.tenantId == null || user?.schoolId == null) {
      return const _AttendanceClassData(
        students: [],
        dailyRecords: [],
        termRecords: [],
      );
    }
    final scope = LocalDataScope(
      tenantId: user!.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );

    final students = await db.getStudentsForClassArm(
      classArmId,
      scope: scope,
    );
    final dailyRecords = await db.getAttendanceForClass(
      scope: scope,
      classArmId: classArmId,
      date: _dateLabel(_selectedDate),
    );
    final termRecords = workspace?.currentTermId == null
        ? const <AttendanceRecord>[]
        : await db.getAttendanceForClassTerm(
            scope: scope,
            classArmId: classArmId,
            termId: workspace!.currentTermId!,
          );

    return _AttendanceClassData(
      students: students,
      dailyRecords: dailyRecords,
      termRecords: termRecords,
    );
  }

  Map<String, int> _dailySummaryCounts(
    List<Student> students,
    List<AttendanceRecord> records,
  ) {
    final counts = <String, int>{
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
    };

    for (final record in records) {
      counts.update(record.status, (value) => value + 1, ifAbsent: () => 1);
    }

    counts['marked'] = records.length;
    counts['remaining'] = students.length - records.length;
    return counts;
  }

  List<_StudentTermAttendanceSummary> _buildTermSummary(
    List<Student> students,
    List<AttendanceRecord> records,
  ) {
    final summaries = <String, _StudentTermAttendanceSummaryBuilder>{};
    for (final student in students) {
      summaries[student.id] = _StudentTermAttendanceSummaryBuilder(
        studentId: student.id,
        studentName: '${student.firstName} ${student.lastName}',
      );
    }

    for (final record in records) {
      final summary = summaries[record.studentId];
      if (summary == null) {
        continue;
      }
      summary.add(record.status);
    }

    return summaries.values.map((item) => item.build()).toList(growable: false)
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final workspace = _workspace;

    if (_loadingWorkspace) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_workspaceError != null && workspace == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_workspaceError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _loadWorkspace, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Attendance',
                  style: Theme.of(context).textTheme.headlineSmall),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_dateLabel(_selectedDate)),
                onPressed: _pickDate,
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClassArmId,
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: workspace?.classArms
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: '${item['id']}',
                              child: Text(
                                AttendanceWorkspaceService.labelForClassArm(
                                    item),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList() ??
                      const [],
                  onChanged: (value) =>
                      setState(() => _selectedClassArmId = value),
                ),
              ),
              if (workspace?.currentAcademicYearLabel != null ||
                  workspace?.currentTermLabel != null)
                Chip(
                  avatar: const Icon(Icons.event_note_outlined, size: 18),
                  label: Text(
                    [
                      if (workspace?.currentAcademicYearLabel != null)
                        workspace!.currentAcademicYearLabel!,
                      if (workspace?.currentTermLabel != null)
                        workspace?.currentTermLabel ?? '',
                    ].join(' • '),
                  ),
                ),
              IconButton(
                tooltip: 'Reload attendance workspace',
                onPressed: _loadWorkspace,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_workspaceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _workspaceError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: (workspace == null || workspace.classArms.isEmpty)
              ? Center(
                  child: Text(
                    'No class arms are configured for this school yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : _selectedClassArmId == null
                  ? Center(
                      child: Text(
                        'Select a class to mark attendance.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : FutureBuilder<_AttendanceClassData>(
                      future: _loadClassData(db),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final classData = snapshot.data ??
                            const _AttendanceClassData(
                              students: [],
                              dailyRecords: [],
                              termRecords: [],
                            );
                        final students = classData.students;
                        if (students.isEmpty) {
                          return const Center(
                            child: Text('No students enrolled in this class.'),
                          );
                        }

                        final statusMap = <String, String>{
                          for (final record in classData.dailyRecords)
                            record.studentId: record.status,
                        };
                        final dailySummary = _dailySummaryCounts(
                          students,
                          classData.dailyRecords,
                        );
                        final termSummary = _buildTermSummary(
                          students,
                          classData.termRecords,
                        );

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _SummaryChip(
                                    label: 'Marked',
                                    value: '${dailySummary['marked'] ?? 0}',
                                  ),
                                  _SummaryChip(
                                    label: 'Remaining',
                                    value: '${dailySummary['remaining'] ?? 0}',
                                  ),
                                  _SummaryChip(
                                    label: 'Present',
                                    value: '${dailySummary['present'] ?? 0}',
                                    color: Colors.green,
                                  ),
                                  _SummaryChip(
                                    label: 'Absent',
                                    value: '${dailySummary['absent'] ?? 0}',
                                    color: Colors.red,
                                  ),
                                  _SummaryChip(
                                    label: 'Late',
                                    value: '${dailySummary['late'] ?? 0}',
                                    color: Colors.orange,
                                  ),
                                  _SummaryChip(
                                    label: 'Excused',
                                    value: '${dailySummary['excused'] ?? 0}',
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Daily Class Register',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              DataTable(
                                columns: const [
                                  DataColumn(label: Text('Student')),
                                  DataColumn(label: Text('Mark Attendance')),
                                  DataColumn(label: Text('Current Status')),
                                ],
                                rows: students.map((student) {
                                  final current = statusMap[student.id] ?? '';
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${student.firstName} ${student.lastName}',
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children:
                                              _statusOptions.map((status) {
                                            final icons = {
                                              'present':
                                                  Icons.check_circle_outline,
                                              'absent': Icons.cancel_outlined,
                                              'late': Icons.access_time,
                                              'excused': Icons.info_outline,
                                            };
                                            final colors = {
                                              'present': Colors.green,
                                              'absent': Colors.red,
                                              'late': Colors.orange,
                                              'excused': Colors.blue,
                                            };
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 6),
                                              child: Tooltip(
                                                message: status,
                                                child: IconButton(
                                                  icon: Icon(
                                                    icons[status],
                                                    color: current == status
                                                        ? colors[status]
                                                        : Colors.grey.shade400,
                                                  ),
                                                  iconSize: 22,
                                                  onPressed: () =>
                                                      _markAttendance(
                                                    db,
                                                    student,
                                                    status,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(current.isEmpty ? '-' : current),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Term Attendance Summary',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Built from local synced and offline-captured attendance records for the current term.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              DataTable(
                                columns: const [
                                  DataColumn(label: Text('Student')),
                                  DataColumn(label: Text('Days Marked')),
                                  DataColumn(label: Text('Present')),
                                  DataColumn(label: Text('Absent')),
                                  DataColumn(label: Text('Late')),
                                  DataColumn(label: Text('Excused')),
                                ],
                                rows: termSummary.map((summary) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(summary.studentName)),
                                      DataCell(Text('${summary.markedDays}')),
                                      DataCell(Text('${summary.presentCount}')),
                                      DataCell(Text('${summary.absentCount}')),
                                      DataCell(Text('${summary.lateCount}')),
                                      DataCell(Text('${summary.excusedCount}')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: resolvedColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceClassData {
  const _AttendanceClassData({
    required this.students,
    required this.dailyRecords,
    required this.termRecords,
  });

  final List<Student> students;
  final List<AttendanceRecord> dailyRecords;
  final List<AttendanceRecord> termRecords;
}

class _StudentTermAttendanceSummary {
  const _StudentTermAttendanceSummary({
    required this.studentId,
    required this.studentName,
    required this.markedDays,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
  });

  final String studentId;
  final String studentName;
  final int markedDays;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
}

class _StudentTermAttendanceSummaryBuilder {
  _StudentTermAttendanceSummaryBuilder({
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;
  int presentCount = 0;
  int absentCount = 0;
  int lateCount = 0;
  int excusedCount = 0;

  void add(String status) {
    switch (status) {
      case 'present':
        presentCount += 1;
        break;
      case 'absent':
        absentCount += 1;
        break;
      case 'late':
        lateCount += 1;
        break;
      case 'excused':
        excusedCount += 1;
        break;
    }
  }

  _StudentTermAttendanceSummary build() {
    return _StudentTermAttendanceSummary(
      studentId: studentId,
      studentName: studentName,
      markedDays: presentCount + absentCount + lateCount + excusedCount,
      presentCount: presentCount,
      absentCount: absentCount,
      lateCount: lateCount,
      excusedCount: excusedCount,
    );
  }
}
