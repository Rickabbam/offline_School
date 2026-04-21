import 'package:flutter/material.dart';

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const _items = [
  _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  _NavItem(icon: Icons.people_outline, label: 'Students'),
  _NavItem(icon: Icons.badge_outlined, label: 'Staff'),
  _NavItem(icon: Icons.fact_check_outlined, label: 'Attendance'),
  _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Finance'),
  _NavItem(icon: Icons.quiz_outlined, label: 'Exams'),
  _NavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
  _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
];

/// Vertical navigation sidebar shown on the left of the app shell.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      color: colorScheme.primary,
      child: Column(
        children: [
          // App logo / name
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
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = index == selectedIndex;
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onPrimary.withOpacity(0.6),
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimary.withOpacity(0.6),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedTileColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
