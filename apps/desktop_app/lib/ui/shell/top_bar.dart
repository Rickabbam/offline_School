import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  Timer? _refreshTimer;
  Future<Map<String, int>>? _queueCountsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final db = context.read<AppDatabase>();
    setState(() {
      _queueCountsFuture = db.getSyncQueueCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Container(
      height: widget.preferredSize.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            widget.pageTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          FutureBuilder<Map<String, int>>(
            future: _queueCountsFuture,
            builder: (context, snapshot) {
              final queueCounts = snapshot.data ?? const <String, int>{};
              return _SyncStatusChip(
                isOfflineSession: auth.isOfflineSession,
                isOnline: context.read<SyncService>().isOnline,
                pendingCount: queueCounts['pending'] ?? 0,
                failedCount: queueCounts['failed'] ?? 0,
              );
            },
          ),
          const SizedBox(width: 16),
          Text(
            user?.fullName ?? 'Guest',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'User menu',
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<AuthService>().logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Sign out'),
              ),
            ],
            child: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({
    required this.isOfflineSession,
    required this.isOnline,
    required this.pendingCount,
    required this.failedCount,
  });

  final bool isOfflineSession;
  final bool isOnline;
  final int pendingCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    final color = failedCount > 0
        ? Colors.red
        : pendingCount > 0
            ? Colors.orange
            : isOnline && !isOfflineSession
                ? Colors.green
                : Colors.blueGrey;
    final label = failedCount > 0
        ? 'Sync issues: $failedCount failed'
        : pendingCount > 0
            ? 'Sync pending: $pendingCount'
            : isOfflineSession
                ? 'Offline session'
                : isOnline
                    ? 'Synced'
                    : 'Offline';

    return Chip(
      avatar: Icon(
        failedCount > 0
            ? Icons.error_outline
            : pendingCount > 0
                ? Icons.sync
                : isOnline && !isOfflineSession
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
        size: 16,
        color: color,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.20)),
    );
  }
}
