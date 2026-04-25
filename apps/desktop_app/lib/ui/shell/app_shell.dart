import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/auth/role_access.dart';
import 'package:desktop_app/backup/backup_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:desktop_app/ui/admissions/applicant_list_screen.dart';
import 'package:desktop_app/ui/attendance/attendance_screen.dart';
import 'package:desktop_app/ui/attendance/attendance_workspace_service.dart';
import 'package:desktop_app/ui/finance/finance_screen.dart';
import 'package:desktop_app/ui/finance/finance_service.dart';
import 'package:desktop_app/ui/onboarding/onboarding_wizard.dart';
import 'package:desktop_app/ui/reports/reports_screen.dart';
import 'package:desktop_app/ui/reports/reports_service.dart';
import 'package:desktop_app/ui/settings/settings_screen.dart';
import 'package:desktop_app/ui/settings/settings_service.dart';
import 'package:desktop_app/ui/shell/sidebar.dart';
import 'package:desktop_app/ui/shell/top_bar.dart';
import 'package:desktop_app/ui/staff/staff_list_screen.dart';
import 'package:desktop_app/ui/students/student_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellSection _selectedSection = ShellSection.dashboard;

  void _onNavSelected(ShellSection section) {
    setState(() => _selectedSection = section);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final needsSetup = requiresSchoolSetup(user);
    final visibleItems = visibleShellItems(user);

    if (needsSetup) {
      if (canAccessSection(user, ShellSection.onboarding)) {
        return OnboardingWizard(
          onCompleted: () =>
              setState(() => _selectedSection = ShellSection.dashboard),
        );
      }

      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'This account is authenticated but has not been assigned to a school workspace yet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!visibleItems.any((item) => item.section == _selectedSection)) {
      _selectedSection = visibleItems.isNotEmpty
          ? visibleItems.first.section
          : ShellSection.dashboard;
    }

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            items: visibleItems,
            selectedSection: _selectedSection,
            onSelected: _onNavSelected,
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(pageTitle: _pageTitle(_selectedSection)),
                Expanded(
                  child: _body(_selectedSection, user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle(ShellSection section) {
    return switch (section) {
      ShellSection.dashboard => 'Dashboard',
      ShellSection.students => 'Students',
      ShellSection.staff => 'Staff',
      ShellSection.admissions => 'Admissions',
      ShellSection.attendance => 'Attendance',
      ShellSection.finance => 'Finance',
      ShellSection.exams => 'Exams',
      ShellSection.reports => 'Reports',
      ShellSection.settings => 'Settings',
      ShellSection.onboarding => 'Onboarding',
    };
  }

  Widget _body(ShellSection section, AuthUser? user) {
    if (!canAccessSection(user, section)) {
      return _AccessDeniedScreen(title: _pageTitle(section));
    }

    switch (section) {
      case ShellSection.dashboard:
        return _DashboardScreen(
          user: user,
          onOpenStudents: () => _onNavSelected(ShellSection.students),
          onOpenStaff: () => _onNavSelected(ShellSection.staff),
          onOpenAdmissions: () => _onNavSelected(ShellSection.admissions),
          onOpenAttendance: () => _onNavSelected(ShellSection.attendance),
          onOpenFinance: () => _onNavSelected(ShellSection.finance),
          onOpenReports: () => _onNavSelected(ShellSection.reports),
          onOpenSettings: () => _onNavSelected(ShellSection.settings),
          onOpenOnboarding: () => _onNavSelected(ShellSection.onboarding),
        );
      case ShellSection.students:
        return const StudentListScreen();
      case ShellSection.staff:
        return const StaffListScreen();
      case ShellSection.admissions:
        return const ApplicantListScreen();
      case ShellSection.attendance:
        return AttendanceScreen(
          service: AttendanceWorkspaceService(context.read<AppDatabase>()),
        );
      case ShellSection.settings:
        return SettingsScreen(
          service: SettingsService(
            context.read<AuthService>(),
            context.read<AppDatabase>(),
          ),
        );
      case ShellSection.reports:
        return ReportsScreen(
          service: ReportsService(
            auth: context.read<AuthService>(),
            db: context.read<AppDatabase>(),
            backup: context.read<BackupService>(),
            sync: context.read<SyncService>(),
          ),
        );
      case ShellSection.onboarding:
        return OnboardingWizard(
          onCompleted: () => _onNavSelected(ShellSection.dashboard),
        );
      case ShellSection.finance:
        return FinanceScreen(
          service: FinanceService(
            context.read<AuthService>(),
            context.read<AppDatabase>(),
          ),
        );
      case ShellSection.exams:
        return _PlaceholderModule(title: _pageTitle(section));
    }
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.user,
    required this.onOpenStudents,
    required this.onOpenStaff,
    required this.onOpenAdmissions,
    required this.onOpenAttendance,
    required this.onOpenFinance,
    required this.onOpenReports,
    required this.onOpenSettings,
    required this.onOpenOnboarding,
  });

  final AuthUser? user;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenStaff;
  final VoidCallback onOpenAdmissions;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenFinance;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenOnboarding;

  @override
  Widget build(BuildContext context) {
    final cards = [
      if (canAccessSection(user, ShellSection.students))
        (
          title: 'Students',
          description: 'Manage student records and local search.',
          icon: Icons.people_outline,
          onTap: onOpenStudents,
        ),
      if (canAccessSection(user, ShellSection.staff))
        (
          title: 'Staff',
          description: 'Capture staff profiles and school roles.',
          icon: Icons.badge_outlined,
          onTap: onOpenStaff,
        ),
      if (canAccessSection(user, ShellSection.admissions))
        (
          title: 'Admissions',
          description: 'Track applicants before enrollment.',
          icon: Icons.assignment_outlined,
          onTap: onOpenAdmissions,
        ),
      if (canAccessSection(user, ShellSection.attendance))
        (
          title: 'Attendance',
          description: 'Mark daily attendance for a class.',
          icon: Icons.fact_check_outlined,
          onTap: onOpenAttendance,
        ),
      if (canAccessSection(user, ShellSection.finance))
        (
          title: 'Finance',
          description: 'Reserved for cashier and admin workflows.',
          icon: Icons.account_balance_wallet_outlined,
          onTap: onOpenFinance,
        ),
      if (canAccessSection(user, ShellSection.reports))
        (
          title: 'Reports',
          description: 'Access summary and reporting surfaces.',
          icon: Icons.bar_chart_outlined,
          onTap: onOpenReports,
        ),
      if (canAccessSection(user, ShellSection.settings))
        (
          title: 'Settings',
          description: 'Update school and campus profiles for this workspace.',
          icon: Icons.settings_outlined,
          onTap: onOpenSettings,
        ),
      if (requiresSchoolSetup(user) &&
          canAccessSection(user, ShellSection.onboarding))
        (
          title: 'Onboarding Wizard',
          description: 'Complete the 11-step school setup flow.',
          icon: Icons.playlist_add_check_circle_outlined,
          onTap: onOpenOnboarding,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceStatusCard(user: user),
          const SizedBox(height: 24),
          Text(
            'Operational MVP',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The desktop client now exposes the workflows your role is allowed to use.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: 260,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: card.onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(card.icon, size: 28),
                              const SizedBox(height: 16),
                              Text(
                                card.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStatusCard extends StatelessWidget {
  const _WorkspaceStatusCard({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = [
      ('Role', user?.role ?? 'unknown'),
      ('Tenant', _formatScopeValue(user?.tenantId)),
      ('School', _formatScopeValue(user?.schoolId)),
      ('Campus', _formatScopeValue(user?.campusId)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Workspace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This session is scoped to the tenant, school, and campus assigned to your account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: rows
                  .map(
                    (row) => Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.$2,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatScopeValue(String? value) {
    if (value == null || value.isEmpty) return 'Not assigned';
    return value.length <= 12 ? value : '${value.substring(0, 8)}...';
  }
}

class _PlaceholderModule extends StatelessWidget {
  const _PlaceholderModule({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title is planned in a later roadmap step.',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 54,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Access restricted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your role does not have access to $title.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
