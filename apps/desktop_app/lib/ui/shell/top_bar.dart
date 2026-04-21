import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

/// Horizontal top bar displayed above the page content area.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

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
          _SyncStatusChip(isOfflineSession: auth.isOfflineSession),
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

/// Small indicator chip showing online/offline sync status.
class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.isOfflineSession});

  final bool isOfflineSession;

  @override
  Widget build(BuildContext context) {
    final isOnline = !isOfflineSession;
    return Chip(
      avatar: Icon(
        isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 16,
        color: isOnline ? Colors.green : Colors.orange,
      ),
      label: Text(
        isOnline ? 'Online Session' : 'Offline Session',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: isOnline
          ? Colors.green.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
      side: BorderSide.none,
    );
  }
}
