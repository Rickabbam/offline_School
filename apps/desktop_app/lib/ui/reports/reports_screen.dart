import 'package:flutter/material.dart';

import 'package:desktop_app/ui/reports/reports_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.service});

  final ReportsService service;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportsWorkspaceData? _data;
  bool _loading = true;
  bool _syncing = false;
  bool _retryingFailed = false;
  String? _conflictActionId;
  bool _requestingReconciliation = false;
  bool _creatingBackup = false;
  bool _runningRestoreDrill = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports workspace: $e';
        _loading = false;
      });
    }
  }

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    try {
      await widget.service.syncNow();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync attempt failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _retryFailedItems() async {
    setState(() => _retryingFailed = true);
    try {
      await widget.service.retryFailedItems();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingFailed = false);
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() => _creatingBackup = true);
    try {
      await widget.service.createBackupNow();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingBackup = false);
      }
    }
  }

  Future<void> _ignoreSyncConflict(String conflictId) async {
    setState(() => _conflictActionId = conflictId);
    try {
      await widget.service.ignoreSyncConflict(conflictId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ignore conflict failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _conflictActionId = null);
      }
    }
  }

  Future<void> _requeueSyncConflict(String conflictId) async {
    setState(() => _conflictActionId = conflictId);
    try {
      await widget.service.requeueSyncConflict(conflictId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requeue conflict failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _conflictActionId = null);
      }
    }
  }

  Future<void> _runRestoreDrill() async {
    setState(() => _runningRestoreDrill = true);
    try {
      final result = await widget.service.runRestoreDrill();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore drill failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _runningRestoreDrill = false);
      }
    }
  }

  Future<void> _requestReconciliation() async {
    setState(() => _requestingReconciliation = true);
    try {
      await widget.service.requestDeviceReconciliation();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconciliation request recorded for this device.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reconciliation request failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _requestingReconciliation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = _data!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
                      'Pilot Readiness',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Local-first operational summary for Phase B verification.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _syncing ? null : _runSync,
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_syncing ? 'Syncing...' : 'Run Sync Now'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _retryingFailed ||
                        (data.syncQueueCounts['failed'] ?? 0) == 0
                    ? null
                    : _retryFailedItems,
                icon: _retryingFailed
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retryingFailed ? 'Retrying...' : 'Retry Failed'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _creatingBackup ? null : _createBackup,
                icon: _creatingBackup
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt_outlined),
                label: Text(
                  _creatingBackup ? 'Backing Up...' : 'Create Backup',
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _requestingReconciliation ||
                        !data.canRequestReconciliation
                    ? null
                    : _requestReconciliation,
                icon: _requestingReconciliation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt),
                label: Text(
                  _requestingReconciliation
                      ? 'Requesting...'
                      : 'Request Reconciliation',
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _runningRestoreDrill ? null : _runRestoreDrill,
                icon: _runningRestoreDrill
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: Text(
                  _runningRestoreDrill
                      ? 'Running Drill...'
                      : 'Run Restore Drill',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatusCard(
                label: 'Network',
                value: data.isOnline ? 'Online' : 'Offline',
                healthy: data.isOnline,
              ),
              _StatusCard(
                label: 'Session',
                value: data.isOfflineSession ? 'Offline Token' : 'Online Token',
                healthy: !data.isOfflineSession,
              ),
              _StatusCard(
                label: 'Pending Queue',
                value: '${data.syncQueueCounts['pending'] ?? 0}',
                healthy: (data.syncQueueCounts['pending'] ?? 0) == 0,
              ),
              _StatusCard(
                label: 'Failed Queue',
                value: '${data.syncQueueCounts['failed'] ?? 0}',
                healthy: (data.syncQueueCounts['failed'] ?? 0) == 0,
              ),
              _StatusCard(
                label: 'Sync Conflicts',
                value: '${data.openSyncConflictCount}',
                healthy: data.openSyncConflictCount == 0,
              ),
              _StatusCard(
                label: 'Reconciliation',
                value: '${data.pendingReconciliationRequestCount} pending',
                healthy: data.pendingReconciliationRequestCount == 0,
              ),
              _StatusCard(
                label: 'Backup',
                value: data.backupStatusLabel,
                healthy:
                    data.pilotChecks['Automatic local backup healthy'] ?? false,
              ),
              _StatusCard(
                label: 'Backup Validation',
                value: data.backupValidationLabel,
                healthy: data.isBackupValidationHealthy,
              ),
              _StatusCard(
                label: 'Restore Drill',
                value: data.restoreDrillStatusLabel,
                healthy:
                    data.pilotChecks['Restore drill recently passed'] ?? false,
              ),
              _StatusCard(
                label: 'Unsynced Review',
                value: data.unresolvedSyncReviewLabel,
                healthy: data.pilotChecks[
                        'No unresolved unsynced records for restore'] ??
                    false,
              ),
              _StatusCard(
                label: 'Audit Uploads',
                value: data.pendingOperatorAuditLabel,
                healthy:
                    data.pilotChecks['Operator recovery audit flushed'] ??
                        false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: data.summaryCounts.entries
                .map(
                  (entry) => _MetricCard(
                    label: entry.key,
                    value: '${entry.value}',
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _SummaryPanel(
                title: 'Pilot Checks',
                items: data.pilotChecks.entries
                    .map((entry) =>
                        '${entry.value ? 'PASS' : 'OPEN'} ${entry.key}')
                    .toList(),
                emptyState: 'No pilot checks available.',
              ),
              _SummaryPanel(
                title: 'Available Data',
                items: data.availableSections,
                emptyState: 'No scoped data is available for this role.',
              ),
              _SummaryPanel(
                title: 'Current Academic Years',
                items: data.currentAcademicYears,
                emptyState: 'No current academic year marked yet.',
              ),
              _SummaryPanel(
                title: 'Admission Statuses',
                items: data.admissionStatusCounts.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .toList(),
                emptyState: 'No admissions recorded locally yet.',
              ),
              _SummaryPanel(
                title: 'Last Pulls',
                items: data.lastPulls,
                emptyState: 'No successful sync pull recorded yet.',
              ),
              _SummaryPanel(
                title: 'Recent Queue Activity',
                items: data.recentQueueItems,
                emptyState: 'No local sync activity recorded yet.',
              ),
              _SummaryPanel(
                title: 'Failed Queue Items',
                items: data.failedQueueItems,
                emptyState: 'No failed queue items.',
              ),
              _SummaryPanel(
                title: 'Reconciliation Requests',
                items: data.reconciliationRequestItems
                    .map(
                      (item) => [
                        item.status.toUpperCase(),
                        item.reason,
                        item.requestedAt.toLocal().toString().substring(0, 19),
                        item.targetDeviceId,
                        if (item.acknowledgedAt != null)
                          'ack ${item.acknowledgedAt!.toLocal().toString().substring(0, 19)}',
                      ].join(' | '),
                    )
                    .toList(),
                emptyState: 'No cached reconciliation requests.',
              ),
              _SummaryPanel(
                title: 'Sync Conflicts',
                items: const [],
                emptyState: '',
                child: _SyncConflictPanel(
                  items: data.syncConflictItems,
                  canManage: data.canManageSyncConflicts,
                  activeConflictId: _conflictActionId,
                  onIgnore: _ignoreSyncConflict,
                  onRequeue: _requeueSyncConflict,
                ),
              ),
              _SummaryPanel(
                title: 'Unsynced Review',
                items: data.unresolvedSyncItems,
                emptyState: 'No unresolved local sync changes.',
              ),
              _SummaryPanel(
                title: 'Pending Audit Uploads',
                items: data.pendingOperatorAuditItems,
                emptyState: 'No pending operator audit uploads.',
              ),
              _SummaryPanel(
                title: 'Recent Backups',
                items: data.recentBackups,
                emptyState: 'No local backups available yet.',
              ),
              _SummaryPanel(
                title: 'Backup Audit',
                items: data.backupAuditEntries,
                emptyState: 'No backup audit activity recorded yet.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? Colors.green : Colors.orange;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.title,
    required this.items,
    required this.emptyState,
    this.child,
  });

  final String title;
  final List<String> items;
  final String emptyState;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (child != null)
                child!
              else if (items.isEmpty)
                Text(emptyState, style: Theme.of(context).textTheme.bodyMedium)
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(item,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncConflictPanel extends StatelessWidget {
  const _SyncConflictPanel({
    required this.items,
    required this.canManage,
    required this.activeConflictId,
    required this.onIgnore,
    required this.onRequeue,
  });

  final List<SyncConflictView> items;
  final bool canManage;
  final String? activeConflictId;
  final ValueChanged<String> onIgnore;
  final ValueChanged<String> onRequeue;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No open sync conflicts.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canManage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'View only. Conflict actions require admin or support admin access.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ...items.map((item) {
          final busy = activeConflictId == item.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.entityType} ${item.operation} ${item.entityId}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.serverMessage ?? item.conflictType,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (item.baseUpdatedAt != null ||
                      item.serverUpdatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [
                          if (item.baseUpdatedAt != null)
                            'Local base ${item.baseUpdatedAt}',
                          if (item.serverUpdatedAt != null)
                            'Server current ${item.serverUpdatedAt}',
                        ].join(' | '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged ${item.createdAt.toLocal().toString().substring(0, 19)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: busy ? null : () => onIgnore(item.id),
                          child: Text(busy ? 'Working...' : 'Ignore'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: busy ? null : () => onRequeue(item.id),
                          child: const Text('Requeue'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
