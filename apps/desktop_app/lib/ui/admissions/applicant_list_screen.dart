import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import 'applicant_form_screen.dart';

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
              // Status filter chips
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterStatus == null,
                    onSelected: (_) => setState(() => _filterStatus = null),
                  ),
                  ..._statuses.map((s) => FilterChip(
                        label: Text(s),
                        selected: _filterStatus == s,
                        onSelected: (_) =>
                            setState(() => _filterStatus = s),
                      )),
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
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<ApplicantData>>(
            future: db.getApplicants(status: _filterStatus),
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
                      Icon(Icons.assignment_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant),
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
                  ],
                  rows: rows.map((a) => DataRow(cells: [
                    DataCell(Text('${a.firstName} ${a.lastName}')),
                    DataCell(Text(a.guardianName ?? '—')),
                    DataCell(_StatusBadge(a.status)),
                    DataCell(Text(a.createdAt
                        .toLocal()
                        .toString()
                        .substring(0, 10))),
                  ])).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
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
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
