import 'package:flutter/material.dart';

import 'package:desktop_app/auth/role_access.dart';

/// Vertical navigation sidebar shown on the left of the app shell.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.items,
    required this.selectedSection,
    required this.onSelected,
  });

  final List<ShellNavItem> items;
  final ShellSection selectedSection;
  final ValueChanged<ShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      color: colorScheme.primary,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.school, color: colorScheme.onPrimary, size: 40),
                const SizedBox(height: 8),
                Text(
                  'offline_School',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = item.section == selectedSection;
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onPrimary.withValues(alpha: 0.6),
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimary.withValues(alpha: 0.6),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedTileColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () => onSelected(item.section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
