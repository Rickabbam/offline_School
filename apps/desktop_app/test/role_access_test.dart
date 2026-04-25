import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/auth/role_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseUser = AuthUser(
    id: 'user-1',
    email: 'user@example.com',
    fullName: 'User Example',
    role: 'admin',
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );

  test('support technician advisory visibility excludes student and finance workspaces', () {
    const supportTech = AuthUser(
      id: 'user-2',
      email: 'tech@example.com',
      fullName: 'Support Tech',
      role: 'support_technician',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    expect(canAccessSection(supportTech, ShellSection.students), isFalse);
    expect(canAccessSection(supportTech, ShellSection.finance), isFalse);
    expect(canAccessSection(supportTech, ShellSection.settings), isTrue);
  });

  test('cashier advisory visibility is limited to finance, dashboard, and reports', () {
    const cashier = AuthUser(
      id: 'user-3',
      email: 'cashier@example.com',
      fullName: 'Cashier User',
      role: 'cashier',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    expect(canAccessSection(cashier, ShellSection.finance), isTrue);
    expect(canAccessSection(cashier, ShellSection.reports), isTrue);
    expect(canAccessSection(cashier, ShellSection.students), isFalse);
    expect(canAccessSection(cashier, ShellSection.staff), isFalse);
  });

  test('school setup state exposes onboarding only to setup-capable roles', () {
    const supportAdminNeedingSetup = AuthUser(
      id: 'user-4',
      email: 'support-admin@example.com',
      fullName: 'Support Admin',
      role: 'support_admin',
      tenantId: null,
      schoolId: null,
      campusId: null,
    );

    expect(requiresSchoolSetup(supportAdminNeedingSetup), isTrue);
    expect(
      visibleShellItems(supportAdminNeedingSetup).map((item) => item.section),
      [ShellSection.onboarding],
    );
    expect(
      visibleShellItems(baseUser).any((item) => item.section == ShellSection.onboarding),
      isFalse,
    );
  });
}
