import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:mobile_app/ui/attendance/attendance_capture_service.dart';
import 'package:mobile_app/ui/attendance/attendance_workspace_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.workspaceService,
  });

  final AttendanceWorkspaceService workspaceService;

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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

      final workspace = await widget.workspaceService.loadWorkspace(
        LocalDataScope(
          tenantId: user!.tenantId!,
          schoolId: user.schoolId!,
          campusId: user.campusId,
        ),
      );

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
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _workspaceError = 'Failed to load attendance workspace: $error';
        _loadingWorkspace = false;
      });
    }
  }

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

  Future<void> _markAttendance(
    AppDatabase db,
    Student student,
    String status,
  ) async {
    final workspace = _workspace;
    final user = context.read<AuthService>().currentUser;
    if (_selectedClassArmId == null ||
        workspace?.currentAcademicYearId == null ||
        workspace?.currentTermId == null ||
        user == null) {
      setState(() {
        _workspaceError =
            'Attendance requires an active academic year, term, and class.';
      });
      return;
    }

    await _captureService.markAttendance(
      db: db,
      user: user,
      student: student,
      classArmId: _selectedClassArmId!,
      academicYearId: workspace!.currentAcademicYearId!,
      termId: workspace.currentTermId!,
      date: _selectedDate,
      status: status,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await context.read<SyncService>().syncNow();
      await _loadWorkspace();
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<_AttendanceClassData> _loadClassData(AppDatabase db) async {
    final classArmId = _selectedClassArmId;
    final workspace = _workspace;
    final user = context.read<AuthService>().currentUser;
    if (classArmId == null || user?.tenantId == null || user?.schoolId == null) {
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final auth = context.watch<AuthService>();
    final workspace = _workspace;
    final user = auth.currentUser;

    if (_loadingWorkspace) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_workspaceError != null && workspace == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_workspaceError!, textAlign: TextAlign.center),
        ),
      );
    }

    final scope = user?.tenantId == null || user?.schoolId == null
        ? null
        : LocalDataScope(
            tenantId: user!.tenantId!,
            schoolId: user.schoolId!,
            campusId: user.campusId,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkspace,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (scope != null) _SyncStatusCard(scope: scope),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workspace?.currentAcademicYearLabel == null
                                ? 'Attendance register'
                                : '${workspace?.currentAcademicYearLabel} • ${workspace?.currentTermLabel ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_dateLabel(_selectedDate)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedClassArmId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: workspace?.classArms
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: '${item['id']}',
                                  child: Text(
                                    AttendanceWorkspaceService.labelForClassArm(item),
                                  ),
                                ),
                              )
                              .toList() ??
                          const [],
                      onChanged: (value) {
                        setState(() => _selectedClassArmId = value);
                      },
                    ),
                    if (_workspaceError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _workspaceError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (workspace == null || workspace.classArms.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No class arms are cached on this device yet.'),
                ),
              )
            else
              FutureBuilder<_AttendanceClassData>(
                future: _loadClassData(db),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final data = snapshot.data ??
                      const _AttendanceClassData(
                        students: [],
                        dailyRecords: [],
                        termRecords: [],
                      );
                  final statusMap = <String, String>{
                    for (final record in data.dailyRecords)
                      record.studentId: record.status,
                  };
                  final summary = _dailySummaryCounts(
                    data.students,
                    data.dailyRecords,
                  );

                  return Column(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryChip(
                            label: 'Marked',
                            value: '${summary['marked'] ?? 0}',
                          ),
                          _SummaryChip(
                            label: 'Remaining',
                            value: '${summary['remaining'] ?? 0}',
                          ),
                          _SummaryChip(
                            label: 'Present',
                            value: '${summary['present'] ?? 0}',
                            color: const Color(0xFF2A9D8F),
                          ),
                          _SummaryChip(
                            label: 'Absent',
                            value: '${summary['absent'] ?? 0}',
                            color: const Color(0xFFD62828),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (data.students.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No students enrolled in this class.'),
                          ),
                        )
                      else
                        ...data.students.map(
                          (student) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.firstName} ${student.lastName}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (student.studentNumber != null &&
                                      student.studentNumber!.isNotEmpty)
                                    Text(
                                      student.studentNumber!,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _statusOptions.map((status) {
                                      final selected = statusMap[student.id] == status;
                                      return ChoiceChip(
                                        label: Text(status),
                                        selected: selected,
                                        onSelected: (_) {
                                          _markAttendance(db, student, status);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.scope});

  final LocalDataScope scope;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        db.getSyncQueueCounts(),
        db.getRecentSyncConflicts(scope: scope),
      ]),
      builder: (context, snapshot) {
        final counts = snapshot.data == null
            ? const <String, int>{}
            : snapshot.data![0] as Map<String, int>;
        final conflicts = snapshot.data == null
            ? const <SyncConflict>[]
            : snapshot.data![1] as List<SyncConflict>;
        final pending = counts['pending'] ?? 0;
        final failed = counts['failed'] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Pending queue: $pending'),
                Text('Failed queue: $failed'),
                Text('Open conflicts: ${conflicts.length}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.color = const Color(0xFF0D3B66),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
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
