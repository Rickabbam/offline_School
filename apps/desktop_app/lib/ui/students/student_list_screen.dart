import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/students/student_form_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final user = context.watch<AuthService>().currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Students',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or number...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _search = value.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Student'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentFormScreen()),
                ).then((_) => setState(() {})),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Student>>(
            future: user?.tenantId == null || user?.schoolId == null
                ? Future.value(const <Student>[])
                : db.getStudents(
                    scope: LocalDataScope(
                      tenantId: user!.tenantId!,
                      schoolId: user.schoolId!,
                      campusId: user.campusId,
                    ),
                    search: _search.isEmpty ? null : _search,
                  ),
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
                        Icons.people_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _search.isEmpty
                            ? 'No students yet. Add the first student.'
                            : 'No students match "$_search".',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Full Name')),
                    DataColumn(label: Text('Gender')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Sync')),
                  ],
                  rows: rows
                      .map(
                        (student) => DataRow(
                          onSelectChanged: (_) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentFormScreen(existing: student),
                            ),
                          ).then((_) => setState(() {})),
                          cells: [
                            DataCell(Text(student.studentNumber ?? '-')),
                            DataCell(Text(
                                '${student.firstName} ${student.lastName}')),
                            DataCell(Text(student.gender ?? '-')),
                            DataCell(_StatusChip(student.status)),
                            DataCell(_SyncChip(student.syncStatus)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => Colors.green,
      'withdrawn' => Colors.orange,
      'graduated' => Colors.blue,
      'transferred' => Colors.purple,
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

class _SyncChip extends StatelessWidget {
  const _SyncChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'synced' => (Icons.cloud_done_outlined, Colors.green),
      'local' => (Icons.cloud_off_outlined, Colors.orange),
      'failed' => (Icons.error_outline, Colors.red),
      _ => (Icons.sync, Colors.grey),
    };

    return Icon(icon, color: color, size: 18);
  }
}
