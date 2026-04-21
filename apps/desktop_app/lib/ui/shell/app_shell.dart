import 'package:flutter/material.dart';

import 'sidebar.dart';
import 'top_bar.dart';

/// The main application shell with a sidebar, top bar, and content area.
///
/// Navigation modules (students, attendance, finance, etc.) are mounted
/// in [_body] based on [_selectedIndex].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onNavSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onSelected: _onNavSelected,
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(pageTitle: _pageTitle(_selectedIndex)),
                Expanded(
                  child: _body(_selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle(int index) {
    const titles = [
      'Dashboard',
      'Students',
      'Staff',
      'Attendance',
      'Finance',
      'Exams',
      'Reports',
      'Settings',
    ];
    return index < titles.length ? titles[index] : '';
  }

  Widget _body(int index) {
    // Placeholder content — each module is wired in during Phase B+.
    return Center(
      child: Text(
        _pageTitle(index),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.grey.shade400,
            ),
      ),
    );
  }
}
