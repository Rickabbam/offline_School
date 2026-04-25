import 'package:flutter/material.dart';

import 'package:desktop_app/auth/auth_service.dart';

enum ShellSection {
  dashboard,
  students,
  staff,
  admissions,
  attendance,
  finance,
  exams,
  reports,
  settings,
  onboarding,
}

class ShellNavItem {
  const ShellNavItem({
    required this.section,
    required this.icon,
    required this.label,
    required this.allowedRoles,
  });

  final ShellSection section;
  final IconData icon;
  final String label;
  final Set<String> allowedRoles;
}

const shellNavItems = [
  ShellNavItem(
    section: ShellSection.dashboard,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard',
    allowedRoles: {
      'admin',
      'cashier',
      'teacher',
      'support_technician',
      'support_admin',
    },
  ),
  ShellNavItem(
    section: ShellSection.students,
    icon: Icons.people_outline,
    label: 'Students',
    allowedRoles: {'admin', 'teacher'},
  ),
  ShellNavItem(
    section: ShellSection.staff,
    icon: Icons.badge_outlined,
    label: 'Staff',
    allowedRoles: {'admin'},
  ),
  ShellNavItem(
    section: ShellSection.admissions,
    icon: Icons.assignment_outlined,
    label: 'Admissions',
    allowedRoles: {'admin', 'teacher'},
  ),
  ShellNavItem(
    section: ShellSection.attendance,
    icon: Icons.fact_check_outlined,
    label: 'Attendance',
    allowedRoles: {'admin', 'teacher'},
  ),
  ShellNavItem(
    section: ShellSection.finance,
    icon: Icons.account_balance_wallet_outlined,
    label: 'Finance',
    allowedRoles: {'admin', 'cashier'},
  ),
  ShellNavItem(
    section: ShellSection.exams,
    icon: Icons.quiz_outlined,
    label: 'Exams',
    allowedRoles: {'admin', 'teacher'},
  ),
  ShellNavItem(
    section: ShellSection.reports,
    icon: Icons.bar_chart_outlined,
    label: 'Reports',
    allowedRoles: {'admin', 'cashier', 'teacher', 'support_admin'},
  ),
  ShellNavItem(
    section: ShellSection.settings,
    icon: Icons.settings_outlined,
    label: 'Settings',
    allowedRoles: {'admin', 'support_admin', 'support_technician'},
  ),
];

const onboardingNavItem = ShellNavItem(
  section: ShellSection.onboarding,
  icon: Icons.playlist_add_check_circle_outlined,
  label: 'Onboarding',
  allowedRoles: {'admin', 'support_admin', 'support_technician'},
);

bool requiresSchoolSetup(AuthUser? user) {
  if (user == null) return false;
  return user.tenantId == null || user.schoolId == null || user.campusId == null;
}

List<ShellNavItem> visibleShellItems(AuthUser? user) {
  if (user == null) return const [];

  if (requiresSchoolSetup(user)) {
    return canAccessSection(user, ShellSection.onboarding)
        ? const [onboardingNavItem]
        : const [];
  }

  return shellNavItems
      .where((item) => canAccessSection(user, item.section))
      .toList(growable: false);
}

bool canAccessSection(AuthUser? user, ShellSection section) {
  if (user == null) return false;

  if (section == ShellSection.onboarding) {
    return onboardingNavItem.allowedRoles.contains(user.role);
  }

  final matches = shellNavItems.where((item) => item.section == section);
  if (matches.isEmpty) return false;
  return matches.first.allowedRoles.contains(user.role);
}
