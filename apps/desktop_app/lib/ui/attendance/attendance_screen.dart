import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';

/// Daily class attendance screen for teachers.
/// Teachers select a class, date, then mark each student as
/// present / absent / late / excused.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // In a full implementation these would be pulled from the local DB.
  // Using placeholder values until academic setup is wired in Flutter.
  String? _selectedClassArmId;
  DateTime _selectedDate = DateTime.now();

  static const _statusOptions = ['present', 'absent', 'late', 'excused'];

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _markAttendance(
      AppDatabase db, StudentData student, String status) async {
    if (_selectedClassArmId == null) return;
    final dateStr = _dateLabel(_selectedDate);
    await db.upsertAttendanceRecord(AttendanceRecordsCompanion(
      id: Value(const Uuid().v4()),
      tenantId: const Value('local'),
      schoolId: const Value('local'),
      studentId: Value(student.id),
      classArmId: Value(_selectedClassArmId!),
      academicYearId: const Value('local'),
      termId: const Value('local'),
      attendanceDate: Value(dateStr),
      status: Value(status),
      syncStatus: const Value('local'),
    ));
    if (mounted) {
      setState(() {}); // Refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Attendance',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_dateLabel(_selectedDate)),
                onPressed: _pickDate,
              ),
              const SizedBox(width: 12),
              // Placeholder class selector — wired to real data in Step 9 setup
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _selectedClassArmId,
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'demo-class-arm',
                        child: Text('Basic 1A (demo)')),
                  ],
                  onChanged: (v) => setState(() => _selectedClassArmId = v),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Student list with attendance controls ──────────────────────────────
        Expanded(
          child: _selectedClassArmId == null
              ? Center(
                  child: Text('Select a class to mark attendance.',
                      style: Theme.of(context).textTheme.bodyLarge),
                )
              : FutureBuilder<List<StudentData>>(
                  future: db.getStudents(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final students = snap.data ?? [];
                    if (students.isEmpty) {
                      return const Center(
                          child: Text('No students enrolled in this class.'));
                    }

                    return FutureBuilder<List<AttendanceRecordData>>(
                      future: db.getAttendanceForClass(
                          classArmId: _selectedClassArmId!,
                          date: _dateLabel(_selectedDate)),
                      builder: (ctx2, aSn) {
                        final records = aSn.data ?? [];
                        final Map<String, String> statusMap = {
                          for (final r in records) r.studentId: r.status,
                        };

                        return SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Mark Attendance')),
                              DataColumn(label: Text('Current Status')),
                            ],
                            rows: students.map((s) {
                              final current = statusMap[s.id] ?? '';
                              return DataRow(cells: [
                                DataCell(Text('${s.firstName} ${s.lastName}')),
                                DataCell(
                                  Row(
                                    children: _statusOptions.map((st) {
                                      final icons = {
                                        'present': Icons.check_circle_outline,
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
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Tooltip(
                                          message: st,
                                          child: IconButton(
                                            icon: Icon(icons[st],
                                                color: current == st
                                                    ? colors[st]
                                                    : Colors.grey.shade400),
                                            iconSize: 22,
                                            onPressed: () =>
                                                _markAttendance(db, s, st),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                DataCell(Text(current.isEmpty ? '—' : current)),
                              ]);
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
