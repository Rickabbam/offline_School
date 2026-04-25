import 'package:desktop_app/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
  });

  tearDown(() async {
    await db.close();
  });

  test('stores and counts pending reconciliation requests in scope', () async {
    const scope = LocalDataScope(
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    await db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: const Value('request-1'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        targetDeviceId: const Value('device-1'),
        reason: const Value('manual_support_reconcile'),
        status: const Value('pending'),
        requestedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
        updatedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
      ),
    );

    expect(
      await db.getPendingReconciliationRequestCount(scope: scope),
      1,
    );
    final requests = await db.getRecentReconciliationRequests(scope: scope);
    expect(requests, hasLength(1));
    expect(requests.single.targetDeviceId, 'device-1');
    expect(requests.single.status, 'pending');
  });

  test('marks a cached reconciliation request as applied', () async {
    const scope = LocalDataScope(
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );
    final acknowledgedAt = DateTime.parse('2026-04-23T11:00:00Z');

    await db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: const Value('request-2'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        targetDeviceId: const Value('device-1'),
        reason: const Value('manual_support_reconcile'),
        status: const Value('pending'),
        requestedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
        updatedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
      ),
    );

    await db.markReconciliationRequestApplied(
      scope: scope,
      requestId: 'request-2',
      targetDeviceId: 'device-1',
      acknowledgedAt: acknowledgedAt,
    );

    final requests = await db.getRecentReconciliationRequests(scope: scope);
    expect(requests.single.status, 'applied');
    expect(requests.single.acknowledgedAt?.toUtc(), acknowledgedAt.toUtc());
    expect(
      await db.getPendingReconciliationRequestCount(scope: scope),
      0,
    );
  });

  test('clears only the pending request for the scoped device', () async {
    const scope = LocalDataScope(
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    await db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: const Value('request-3'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        targetDeviceId: const Value('device-1'),
        reason: const Value('manual_support_reconcile'),
        status: const Value('pending'),
        requestedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
        updatedAt: Value(DateTime.parse('2026-04-23T10:00:00Z')),
      ),
    );
    await db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: const Value('request-4'),
        tenantId: const Value('tenant-1'),
        schoolId: const Value('school-1'),
        campusId: const Value('campus-1'),
        targetDeviceId: const Value('device-2'),
        reason: const Value('manual_support_reconcile'),
        status: const Value('pending'),
        requestedAt: Value(DateTime.parse('2026-04-23T10:05:00Z')),
        updatedAt: Value(DateTime.parse('2026-04-23T10:05:00Z')),
      ),
    );

    await db.clearPendingReconciliationRequestForDevice(
      scope: scope,
      targetDeviceId: 'device-1',
    );

    final requests = await db.getRecentReconciliationRequests(scope: scope);
    expect(requests, hasLength(1));
    expect(requests.single.targetDeviceId, 'device-2');
  });
}
