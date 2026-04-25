import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/ui/staff/staff_editor_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StaffEditorService service;
  const user = AuthUser(
    id: 'user-1',
    email: 'admin@example.com',
    fullName: 'Admin User',
    role: 'admin',
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );
  const scope = LocalDataScope(
    tenantId: 'tenant-1',
    schoolId: 'school-1',
    campusId: 'campus-1',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    service = StaffEditorService();
  });

  tearDown(() async {
    await db.close();
  });

  test('creates offline staff and assignment queue records', () async {
    await service.saveStaff(
      db: db,
      user: user,
      input: const StaffEditorInput(
        staffNumber: 'STF-001',
        firstName: 'Akosua',
        middleName: '',
        lastName: 'Mensah',
        gender: 'female',
        phone: '0200000000',
        email: 'akosua@example.com',
        department: 'Academics',
        systemRole: 'teacher',
        employmentType: 'permanent',
        dateJoined: '2026-01-10',
        isActive: true,
        classTeacherClassArmId: 'arm-1',
        subjectIds: {'subject-1', 'subject-2'},
      ),
    );

    final staffRows = await db.select(db.staff).get();
    final assignments = await db.select(db.staffTeachingAssignments).get();
    final queueItems = await db.select(db.syncQueue).get();

    expect(staffRows, hasLength(1));
    expect(assignments, hasLength(3));
    expect(
      queueItems.map((item) => item.entityType),
      ['staff', 'staff_teaching_assignment', 'staff_teaching_assignment', 'staff_teaching_assignment'],
    );
  });

  test('deletes staff locally and cascades assignment deletes', () async {
    await db.upsertStaff(
      StaffCompanion.insert(
        id: 'staff-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        campusId: const Value('campus-1'),
        firstName: 'Akosua',
        lastName: 'Mensah',
        systemRole: const Value('teacher'),
        employmentType: const Value('permanent'),
        isActive: const Value(true),
        syncStatus: const Value('synced'),
        serverRevision: const Value(12),
      ),
    );
    await db.upsertStaffAssignment(
      StaffTeachingAssignmentsCompanion.insert(
        id: 'assignment-1',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        staffId: 'staff-1',
        assignmentType: 'class_teacher',
        classArmId: const Value('arm-1'),
        serverRevision: const Value(13),
      ),
    );
    await db.upsertStaffAssignment(
      StaffTeachingAssignmentsCompanion.insert(
        id: 'assignment-2',
        tenantId: scope.tenantId,
        schoolId: scope.schoolId,
        staffId: 'staff-1',
        assignmentType: 'subject_teacher',
        subjectId: const Value('subject-1'),
        serverRevision: const Value(14),
      ),
    );

    final existing = (await db.getAllStaff(scope: scope)).single;

    await service.deleteStaff(
      db: db,
      user: user,
      existing: existing,
    );

    final allStaff = await db.select(db.staff).get();
    final assignments = await db.select(db.staffTeachingAssignments).get();
    final queueItems = await db.select(db.syncQueue).get();

    expect(allStaff.single.deleted, isTrue);
    expect(allStaff.single.syncStatus, 'local');
    expect(assignments.every((item) => item.deleted), isTrue);
    expect(
      queueItems.map((item) => '${item.entityType}:${item.operation}').toList(),
      ['staff:delete', 'staff_teaching_assignment:delete', 'staff_teaching_assignment:delete'],
    );
  });
}
