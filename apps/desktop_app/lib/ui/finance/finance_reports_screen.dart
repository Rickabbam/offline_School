import 'package:flutter/material.dart';

import 'package:desktop_app/ui/finance/finance_service.dart';

class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({
    super.key,
    required this.service,
  });

  final FinanceService service;

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  late Future<FinanceReportWorkspaceData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.loadReportWorkspace();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceReportWorkspaceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Unable to load finance reports.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance Reports',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Offline arrears, daily collection, and class fee summaries from posted finance records.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ReportMetricCard(
                    label: 'Posted invoices',
                    value: _money(data.totalPostedInvoices),
                  ),
                  _ReportMetricCard(
                    label: 'Collected',
                    value: _money(data.totalCollected),
                  ),
                  _ReportMetricCard(
                    label: 'Reversed',
                    value: _money(data.totalReversed),
                  ),
                  _ReportMetricCard(
                    label: 'Outstanding',
                    value: _money(data.totalOutstanding),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ArrearsTable(rows: data.arrears),
              const SizedBox(height: 24),
              _DailyCollectionsTable(rows: data.dailyCollections),
              const SizedBox(height: 24),
              _ClassSummaryTable(rows: data.classSummaries),
            ],
          ),
        );
      },
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
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

class _ArrearsTable extends StatelessWidget {
  const _ArrearsTable({required this.rows});

  final List<ArrearsReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      title: 'Arrears',
      emptyText: 'No outstanding balances on posted invoices.',
      hasRows: rows.isNotEmpty,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Student')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Term')),
          DataColumn(label: Text('Invoice')),
          DataColumn(label: Text('Billed')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Outstanding')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.studentName)),
                  DataCell(Text(row.className)),
                  DataCell(Text(row.termName)),
                  DataCell(Text(row.invoiceCode)),
                  DataCell(Text(_money(row.invoiceTotal))),
                  DataCell(Text(_money(row.paidAmount))),
                  DataCell(Text(_money(row.outstandingAmount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DailyCollectionsTable extends StatelessWidget {
  const _DailyCollectionsTable({required this.rows});

  final List<DailyCollectionReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      title: 'Daily Collections',
      emptyText: 'No posted collections available.',
      hasRows: rows.isNotEmpty,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Mode')),
          DataColumn(label: Text('Payments')),
          DataColumn(label: Text('Total')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.paymentDate)),
                  DataCell(Text(_paymentModeLabel(row.paymentMode))),
                  DataCell(Text('${row.paymentCount}')),
                  DataCell(Text(_money(row.totalAmount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ClassSummaryTable extends StatelessWidget {
  const _ClassSummaryTable({required this.rows});

  final List<ClassFeeSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      title: 'Class Fee Summary',
      emptyText: 'No posted invoice summaries available.',
      hasRows: rows.isNotEmpty,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Term')),
          DataColumn(label: Text('Invoices')),
          DataColumn(label: Text('Billed')),
          DataColumn(label: Text('Collected')),
          DataColumn(label: Text('Outstanding')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.className)),
                  DataCell(Text(row.termName)),
                  DataCell(Text('${row.invoiceCount}')),
                  DataCell(Text(_money(row.billedAmount))),
                  DataCell(Text(_money(row.collectedAmount))),
                  DataCell(Text(_money(row.outstandingAmount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.emptyText,
    required this.child,
    required this.hasRows,
  });

  final String title;
  final String emptyText;
  final Widget child;
  final bool hasRows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!hasRows)
              Text(emptyText)
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) => value.toStringAsFixed(2);

String _paymentModeLabel(String mode) {
  switch (mode) {
    case 'cash':
      return 'Cash';
    case 'mtn_momo':
      return 'MTN MoMo';
    case 'telecel_cash':
      return 'Telecel Cash';
    case 'bank':
      return 'Bank';
    default:
      return mode;
  }
}
