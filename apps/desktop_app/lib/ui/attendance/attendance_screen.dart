import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/attendance/attendance_workspace_service.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.service});

  final AttendanceWorkspaceService service;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _statusOptions = ['present', 'absent', 'late', 'excused'];

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

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      final workspace = await widget.service.loadWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _workspace = workspace;
        _selectedClassArmId = workspace.classArms.isEmpty
            ? null
            : _selectedClassArmId ?? '${workspace.classArms.first['id']}';
        _loadingWorkspace = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _workspaceError = 'Failed to load attendance workspace: $e';
        _loadingWorkspace = false;
      });
    }
  }

  Future<void> _markAttendance(
    AppDatabase db,
    Student student,
    String status,
  ) async {
    if (_selectedClassArmId == null) {
      return;
    }

    final workspace = _workspace;
    final user = context.read<AuthService>().currentUser;
    if (workspace == null ||
        workspace.currentAcademicYearId == null ||
        workspace.currentTermId == null ||
        user == null ||
        user.tenantId == null ||
        user.schoolId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _workspaceError =
            'Attendance requires an active academic year, term, and school scope.';
      });
      return;
    }

    final dateStr = _dateLabel(_selectedDate);
    await db.upsertAttendanceRecord(
      AttendanceRecordsCompanion(
        id: Value(const Uuid().v4()),
        tenantId: Value(user.tenantId!),
        schoolId: Value(user.schoolId!),
        campusId: Value(user.campusId),
        studentId: Value(student.id),
        classArmId: Value(_selectedClassArmId!),
        academicYearId: Value(workspace.currentAcademicYearId!),
        termId: Value(workspace.currentTermId!),
        attendanceDate: Value(dateStr),
        status: Value(status),
        syncStatus: const Value('local'),
      ),
    );
    if (mounted) {
      setState(() {});
    }
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
                  : FutureBuilder<List<Student>>(
                      future: db.getStudentsForClassArm(_selectedClassArmId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final students = snapshot.data ?? [];
                        if (students.isEmpty) {
                          return const Center(
                            child: Text('No students enrolled in this class.'),
                          );
                        }

                        return FutureBuilder<List<AttendanceRecord>>(
                          future: db.getAttendanceForClass(
                            classArmId: _selectedClassArmId!,
                            date: _dateLabel(_selectedDate),
                          ),
                          builder: (context, attendanceSnapshot) {
                            final records = attendanceSnapshot.data ?? [];
                            final statusMap = <String, String>{
                              for (final record in records)
                                record.studentId: record.status,
                            };

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Student')),
                                  DataColumn(label: Text('Mark Attendance')),
                                  DataColumn(label: Text('Current Status')),
                                ],
                                rows: students.map((student) {
                                  final current = statusMap[student.id] ?? '';
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                          '${student.firstName} ${student.lastName}')),
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
                                      DataCell(Text(
                                          current.isEmpty ? '-' : current)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
