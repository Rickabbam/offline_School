import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';

/// Student list screen with local search and quick add action.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
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
                    hintText: 'Search by name or number…',
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
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Student'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StudentFormScreen()),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Table ──────────────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<StudentData>>(
            future: db.getStudents(search: _search.isEmpty ? null : _search),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant),
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
                  rows: rows.map((s) {
                    return DataRow(cells: [
                      DataCell(Text(s.studentNumber ?? '—')),
                      DataCell(Text(
                          '${s.firstName} ${s.lastName}')),
                      DataCell(Text(s.gender ?? '—')),
                      DataCell(_StatusChip(s.status)),
                      DataCell(_SyncChip(s.syncStatus)),
                    ]);
                  }).toList(),
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
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.4)),
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
