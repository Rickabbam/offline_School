import 'package:flutter/material.dart';

import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.service,
  });

  final FinanceService service;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<PaymentWorkspaceData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.loadPaymentWorkspace();
  }

  void _reload() {
    setState(() {
      _future = widget.service.loadPaymentWorkspace();
    });
  }

  Future<void> _showCollectDialog(PaymentWorkspaceData data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CollectPaymentDialog(
        service: widget.service,
        workspace: data,
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  Future<void> _transitionPayment(
    String paymentId,
    String targetStatus,
  ) async {
    await widget.service.transitionPaymentStatus(
      paymentId: paymentId,
      targetStatus: targetStatus,
    );
    _reload();
  }

  Future<void> _showReversalDialog(Payment payment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ReversePaymentDialog(
        service: widget.service,
        payment: payment,
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymentWorkspaceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Unable to load payments.'));
        }

        final invoicesById = {
          for (final invoice in data.invoices) invoice.id: invoice,
        };
        final studentsById = {
          for (final student in data.students) student.id: student,
        };
        final termsById = {
          for (final term in data.terms) term.id: term,
        };
        final reversedPaymentIds =
            data.reversals.map((row) => row.paymentId).toSet();

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
                          'Payments',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Record cashier payments offline against posted invoices. Posted payments remain immutable and corrections go through a reversal entry.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: data.invoices.isEmpty
                        ? null
                        : () => _showCollectDialog(data),
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: const Text('Collect Payment'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (data.payments.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      data.invoices.isEmpty
                          ? 'Post an invoice before collecting a payment.'
                          : 'No payments recorded yet.',
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
                          DataColumn(label: Text('Payment')),
                          DataColumn(label: Text('Invoice')),
                          DataColumn(label: Text('Student')),
                          DataColumn(label: Text('Term')),
                          DataColumn(label: Text('Mode')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: data.payments.map((payment) {
                          final invoice = invoicesById[payment.invoiceId];
                          final student = invoice == null
                              ? null
                              : studentsById[invoice.studentId];
                          final term = invoice == null
                              ? null
                              : termsById[invoice.termId];
                          final isReversed =
                              reversedPaymentIds.contains(payment.id);
                          return DataRow(
                            cells: [
                              DataCell(Text(payment.paymentCode)),
                              DataCell(Text(
                                  invoice?.invoiceCode ?? payment.invoiceId)),
                              DataCell(Text(
                                student == null
                                    ? '-'
                                    : '${student.firstName} ${student.lastName}',
                              )),
                              DataCell(Text(term?.name ?? '-')),
                              DataCell(
                                  Text(_paymentModeLabel(payment.paymentMode))),
                              DataCell(Text(payment.amount.toStringAsFixed(2))),
                              DataCell(_PaymentStatusChip(
                                status: payment.status,
                                reversed: isReversed,
                              )),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (payment.status == 'draft')
                                      FilledButton(
                                        onPressed: () => _transitionPayment(
                                          payment.id,
                                          'confirmed',
                                        ),
                                        child: const Text('Confirm'),
                                      ),
                                    if (payment.status == 'confirmed')
                                      FilledButton(
                                        onPressed: () => _transitionPayment(
                                          payment.id,
                                          'posted',
                                        ),
                                        child: const Text('Post'),
                                      ),
                                    if (payment.status == 'posted' &&
                                        !isReversed)
                                      TextButton(
                                        onPressed: () =>
                                            _showReversalDialog(payment),
                                        child: const Text('Reverse'),
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

class _CollectPaymentDialog extends StatefulWidget {
  const _CollectPaymentDialog({
    required this.service,
    required this.workspace,
  });

  final FinanceService service;
  final PaymentWorkspaceData workspace;

  @override
  State<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<_CollectPaymentDialog> {
  String? _invoiceId;
  String _paymentMode = 'cash';
  late final TextEditingController _amountCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.workspace.invoices.isEmpty
        ? null
        : widget.workspace.invoices.first.id;
    _amountCtrl = TextEditingController();
    _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    _referenceCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesById = {
      for (final invoice in widget.workspace.invoices) invoice.id: invoice,
    };
    final outstandingByInvoiceId = _outstandingByInvoiceId(widget.workspace);

    return AlertDialog(
      title: const Text('Collect Payment'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _invoiceId,
              decoration: const InputDecoration(
                labelText: 'Posted invoice',
                border: OutlineInputBorder(),
              ),
              items: widget.workspace.invoices
                  .map(
                    (invoice) => DropdownMenuItem(
                      value: invoice.id,
                      child: Text(
                        '${invoice.invoiceCode} - ${(outstandingByInvoiceId[invoice.id] ?? invoice.totalAmount).toStringAsFixed(2)} outstanding',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _invoiceId = value),
            ),
            const SizedBox(height: 16),
            if (_invoiceId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Outstanding: ${(outstandingByInvoiceId[_invoiceId!] ?? invoicesById[_invoiceId!]!.totalAmount).toStringAsFixed(2)}',
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mtn_momo', child: Text('MTN MoMo')),
                DropdownMenuItem(
                    value: 'telecel_cash', child: Text('Telecel Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMode = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment date',
                border: OutlineInputBorder(),
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                labelText: 'Reference',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
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
          onPressed: _invoiceId == null
              ? null
              : () async {
                  final amount = double.tryParse(_amountCtrl.text.trim());
                  if (amount == null) {
                    return;
                  }
                  await widget.service.createPayment(
                    invoiceId: _invoiceId!,
                    amount: amount,
                    paymentMode: _paymentMode,
                    paymentDate: _dateCtrl.text.trim(),
                    reference: _referenceCtrl.text,
                    notes: _notesCtrl.text,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
          child: const Text('Save Draft'),
        ),
      ],
    );
  }
}

class _ReversePaymentDialog extends StatefulWidget {
  const _ReversePaymentDialog({
    required this.service,
    required this.payment,
  });

  final FinanceService service;
  final Payment payment;

  @override
  State<_ReversePaymentDialog> createState() => _ReversePaymentDialogState();
}

class _ReversePaymentDialogState extends State<_ReversePaymentDialog> {
  late final TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reverse ${widget.payment.paymentCode}'),
      content: TextField(
        controller: _reasonCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reversal reason',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.service.createPaymentReversal(
              paymentId: widget.payment.id,
              reason: _reasonCtrl.text,
            );
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Create Reversal'),
        ),
      ],
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({
    required this.status,
    required this.reversed,
  });

  final String status;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final label = reversed ? '$status / reversed' : status;
    final color = switch (status) {
      'draft' => Colors.orange,
      'confirmed' => Colors.blue,
      'posted' => reversed ? Colors.red : Colors.green,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}

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

Map<String, double> _outstandingByInvoiceId(PaymentWorkspaceData data) {
  final reversedPaymentIds = data.reversals.map((row) => row.paymentId).toSet();
  final postedTotals = <String, double>{};
  for (final payment in data.payments) {
    if (payment.status != 'posted' || reversedPaymentIds.contains(payment.id)) {
      continue;
    }
    postedTotals.update(
      payment.invoiceId,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  return {
    for (final invoice in data.invoices)
      invoice.id: invoice.totalAmount - (postedTotals[invoice.id] ?? 0),
  };
}
