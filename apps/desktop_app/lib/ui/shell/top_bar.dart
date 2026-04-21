import 'package:flutter/material.dart';

/// Horizontal top bar displayed above the page content area.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
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
            pageTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          _SyncStatusChip(),
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 16,
            child: Icon(Icons.person, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Small indicator chip showing online/offline sync status.
class _SyncStatusChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO Phase A wiring: replace with SyncService connectivity stream.
    const isOnline = false;
    return Chip(
      avatar: Icon(
        isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 16,
        color: isOnline ? Colors.green : Colors.orange,
      ),
      label: Text(
        isOnline ? 'Synced' : 'Offline',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: isOnline
          ? Colors.green.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
      side: BorderSide.none,
    );
  }
}
