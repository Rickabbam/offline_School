import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.service,
  });

  final FinanceService service;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<InvoiceWorkspaceData> _future;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = widget.service.loadInvoiceWorkspace();
  }

  void _reload() {
    setState(() {
      _future = widget.service.loadInvoiceWorkspace();
    });
  }

  Future<void> _showGenerateDialog(InvoiceWorkspaceData data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _GenerateInvoicesDialog(
        service: widget.service,
        workspace: data,
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  Future<void> _transitionInvoice(
    String invoiceId,
    String targetStatus,
  ) async {
    await widget.service.transitionInvoiceStatus(
      invoiceId: invoiceId,
      targetStatus: targetStatus,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InvoiceWorkspaceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Unable to load invoices.'));
        }

        final studentsById = {
          for (final student in data.students) student.id: student,
        };
        final classArmsById = {
          for (final arm in data.classArms) arm.id: arm,
        };
        final termsById = {
          for (final term in data.terms) term.id: term,
        };

        final filtered = data.invoices.where((invoice) {
          return _statusFilter == null || invoice.status == _statusFilter;
        }).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoices',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate draft invoices per enrolled student per term, then confirm and post them after cashier review.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text('All statuses'),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'draft',
                        child: Text('Draft'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'posted',
                        child: Text('Posted'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: data.terms.isEmpty ? null : () => _showGenerateDialog(data),
                    icon: const Icon(Icons.library_add_outlined),
                    label: const Text('Generate Drafts'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      data.terms.isEmpty
                          ? 'Create academic terms before generating invoices.'
                          : 'No invoices match the current filters.',
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Invoice')),
                          DataColumn(label: Text('Student')),
                          DataColumn(label: Text('Class')),
                          DataColumn(label: Text('Term')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((invoice) {
                          final student = studentsById[invoice.studentId];
                          final classArm = classArmsById[invoice.classArmId];
                          final term = termsById[invoice.termId];
                          return DataRow(
                            cells: [
                              DataCell(Text(invoice.invoiceCode)),
                              DataCell(Text(
                                student == null
                                    ? invoice.studentId
                                    : '${student.firstName} ${student.lastName}',
                              )),
                              DataCell(Text(classArm?.displayName ?? '-')),
                              DataCell(Text(term?.name ?? invoice.termId)),
                              DataCell(_InvoiceStatusChip(invoice.status)),
                              DataCell(Text(invoice.totalAmount.toStringAsFixed(2))),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (context) => _InvoiceDetailDialog(
                                          invoice: invoice,
                                          studentName: student == null
                                              ? invoice.studentId
                                              : '${student.firstName} ${student.lastName}',
                                          termName: term?.name ?? invoice.termId,
                                        ),
                                      ),
                                      child: const Text('View'),
                                    ),
                                    if (invoice.status == 'draft')
                                      FilledButton(
                                        onPressed: () => _transitionInvoice(
                                          invoice.id,
                                          'confirmed',
                                        ),
                                        child: const Text('Confirm'),
                                      ),
                                    if (invoice.status == 'confirmed')
                                      FilledButton(
                                        onPressed: () => _transitionInvoice(
                                          invoice.id,
                                          'posted',
                                        ),
                                        child: const Text('Post'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GenerateInvoicesDialog extends StatefulWidget {
  const _GenerateInvoicesDialog({
    required this.service,
    required this.workspace,
  });

  final FinanceService service;
  final InvoiceWorkspaceData workspace;

  @override
  State<_GenerateInvoicesDialog> createState() => _GenerateInvoicesDialogState();
}

class _GenerateInvoicesDialogState extends State<_GenerateInvoicesDialog> {
  String? _termId;
  String? _classLevelId;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _termId = widget.workspace.terms.isEmpty ? null : widget.workspace.terms.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Draft Invoices'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _termId,
              decoration: const InputDecoration(
                labelText: 'Term',
                border: OutlineInputBorder(),
              ),
              items: widget.workspace.terms
                  .map(
                    (term) => DropdownMenuItem(
                      value: term.id,
                      child: Text(term.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _termId = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _classLevelId,
              decoration: const InputDecoration(
                labelText: 'Class filter',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All classes'),
                ),
                ...widget.workspace.classLevels.map(
                  (level) => DropdownMenuItem<String?>(
                    value: level.id,
                    child: Text(level.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _classLevelId = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _studentId,
              decoration: const InputDecoration(
                labelText: 'Mode',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Batch: all matching students'),
                ),
                ...widget.workspace.students.map(
                  (student) => DropdownMenuItem<String?>(
                    value: student.id,
                    child: Text('${student.firstName} ${student.lastName}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _studentId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _termId == null
              ? null
              : () async {
                  final result = await widget.service.generateInvoices(
                    termId: _termId!,
                    classLevelId: _classLevelId,
                    studentId: _studentId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Created ${result['created']} invoice(s); skipped ${result['skippedExisting']} existing and ${result['skippedNoCharges']} with no charges.',
                        ),
                      ),
                    );
                    Navigator.of(context).pop(true);
                  }
                },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _InvoiceDetailDialog extends StatelessWidget {
  const _InvoiceDetailDialog({
    required this.invoice,
    required this.studentName,
    required this.termName,
  });

  final Invoice invoice;
  final String studentName;
  final String termName;

  @override
  Widget build(BuildContext context) {
    final lines =
        (jsonDecode(invoice.lineItemsJson) as List<dynamic>).cast<Map<String, dynamic>>();
    return AlertDialog(
      title: Text(invoice.invoiceCode),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(studentName),
            Text(termName),
            const SizedBox(height: 16),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('${line['description']}')),
                    Text((line['amount'] as num).toStringAsFixed(2)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Total')),
                Text(invoice.totalAmount.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InvoiceStatusChip extends StatelessWidget {
  const _InvoiceStatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'draft' => Colors.orange,
      'confirmed' => Colors.blue,
      'posted' => Colors.green,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
