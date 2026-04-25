import 'package:flutter/material.dart';

import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';

class FeeStructuresScreen extends StatefulWidget {
  const FeeStructuresScreen({
    super.key,
    required this.service,
  });

  final FinanceService service;

  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  late Future<FeeStructuresWorkspaceData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.loadWorkspace();
  }

  void _reload() {
    setState(() {
      _future = widget.service.loadWorkspace();
    });
  }

  Future<void> _showCategoryDialog({
    FeeCategory? existing,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _FeeCategoryDialog(
        service: widget.service,
        existing: existing,
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  Future<void> _showItemDialog(FeeStructuresWorkspaceData data,
      {FeeStructureItem? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _FeeStructureItemDialog(
        service: widget.service,
        workspace: data,
        existing: existing,
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeeStructuresWorkspaceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Unable to load fee structures.'));
        }

        final categoriesById = {
          for (final category in data.categories) category.id: category,
        };
        final classLevelsById = {
          for (final level in data.classLevels) level.id: level,
        };
        final termsById = {
          for (final term in data.terms) term.id: term,
        };

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
                          'Fee Structures',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure fee categories and class or term variations locally. Changes queue for sync and remain usable offline.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Add Category'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: data.categories.isEmpty
                        ? null
                        : () => _showItemDialog(data),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Add Variation'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: data.categories.map((category) {
                  final categoryItems = data.items
                      .where((item) => item.feeCategoryId == category.id)
                      .toList(growable: false);
                  return SizedBox(
                    width: 300,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showCategoryDialog(existing: category),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  _CategoryStatusChip(
                                    isActive: category.isActive,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category.billingTerm == 'one_time'
                                    ? 'One-time fee'
                                    : 'Per-term fee',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${categoryItems.length} configured variation(s)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (data.items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      data.categories.isEmpty
                          ? 'Create a fee category first, then add class or term variations.'
                          : 'No fee variations yet. Add the first amount rule for a category.',
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configured Variations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Category')),
                              DataColumn(label: Text('Class')),
                              DataColumn(label: Text('Term')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Notes')),
                            ],
                            rows: data.items.map((item) {
                              return DataRow(
                                onSelectChanged: (_) =>
                                    _showItemDialog(data, existing: item),
                                cells: [
                                  DataCell(Text(
                                    categoriesById[item.feeCategoryId]?.name ??
                                        item.feeCategoryId,
                                  )),
                                  DataCell(Text(
                                    classLevelsById[item.classLevelId]?.name ??
                                        'All classes',
                                  )),
                                  DataCell(Text(
                                    termsById[item.termId]?.name ?? 'All terms',
                                  )),
                                  DataCell(
                                    Text(item.amount.toStringAsFixed(2)),
                                  ),
                                  DataCell(Text(item.notes ?? '-')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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

class _CategoryStatusChip extends StatelessWidget {
  const _CategoryStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.orange;
    return Chip(
      label: Text(isActive ? 'Active' : 'Paused'),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FeeCategoryDialog extends StatefulWidget {
  const _FeeCategoryDialog({
    required this.service,
    this.existing,
  });

  final FinanceService service;
  final FeeCategory? existing;

  @override
  State<_FeeCategoryDialog> createState() => _FeeCategoryDialogState();
}

class _FeeCategoryDialogState extends State<_FeeCategoryDialog> {
  late final TextEditingController _nameCtrl;
  late String _billingTerm;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _billingTerm = widget.existing?.billingTerm ?? 'per_term';
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.existing;
    return AlertDialog(
      title:
          Text(service == null ? 'Add Fee Category' : 'Edit Fee Category'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _billingTerm,
              decoration: const InputDecoration(
                labelText: 'Billing term',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'per_term',
                  child: Text('Per term'),
                ),
                DropdownMenuItem(
                  value: 'one_time',
                  child: Text('One time'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _billingTerm = value);
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Category active'),
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
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) {
              return;
            }
            if (widget.existing == null) {
              await widget.service.createFeeCategory(
                name: _nameCtrl.text.trim(),
                billingTerm: _billingTerm,
                isActive: _isActive,
              );
            } else {
              await widget.service.updateFeeCategory(
                id: widget.existing!.id,
                name: _nameCtrl.text.trim(),
                billingTerm: _billingTerm,
                isActive: _isActive,
              );
            }
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FeeStructureItemDialog extends StatefulWidget {
  const _FeeStructureItemDialog({
    required this.service,
    required this.workspace,
    this.existing,
  });

  final FinanceService service;
  final FeeStructuresWorkspaceData workspace;
  final FeeStructureItem? existing;

  @override
  State<_FeeStructureItemDialog> createState() => _FeeStructureItemDialogState();
}

class _FeeStructureItemDialogState extends State<_FeeStructureItemDialog> {
  late String _feeCategoryId;
  String? _classLevelId;
  String? _termId;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _feeCategoryId = widget.existing?.feeCategoryId ??
        widget.workspace.categories.first.id;
    _classLevelId = widget.existing?.classLevelId;
    _termId = widget.existing?.termId;
    _amountCtrl = TextEditingController(
      text: widget.existing?.amount.toStringAsFixed(2) ?? '',
    );
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Fee Variation' : 'Edit Fee Variation',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _feeCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: widget.workspace.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _feeCategoryId = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _classLevelId,
              decoration: const InputDecoration(
                labelText: 'Class variation',
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
              initialValue: _termId,
              decoration: const InputDecoration(
                labelText: 'Term variation',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All terms'),
                ),
                ...widget.workspace.terms.map(
                  (term) => DropdownMenuItem<String?>(
                    value: term.id,
                    child: Text(term.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _termId = value),
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
          onPressed: () async {
            final amount = double.tryParse(_amountCtrl.text.trim());
            if (amount == null || amount < 0) {
              return;
            }
            if (widget.existing == null) {
              await widget.service.createFeeStructureItem(
                feeCategoryId: _feeCategoryId,
                classLevelId: _classLevelId,
                termId: _termId,
                amount: amount,
                notes: _notesCtrl.text,
              );
            } else {
              await widget.service.updateFeeStructureItem(
                id: widget.existing!.id,
                feeCategoryId: _feeCategoryId,
                classLevelId: _classLevelId,
                termId: _termId,
                amount: amount,
                notes: _notesCtrl.text,
              );
            }
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
