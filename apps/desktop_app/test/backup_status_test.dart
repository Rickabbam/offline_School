import 'dart:io';

import 'package:desktop_app/backup/backup_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempSupportDir;
  late AppDatabase db;
  late BackupService backup;

  setUp(() async {
    tempSupportDir = await Directory.systemTemp.createTemp(
      'offline-school-backup-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return tempSupportDir.path;
      }
      return null;
    });

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
    backup = BackupService(db);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await db.close();
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  test('reports pending operator audit uploads in backup status', () async {
    await backup.queueOperatorAuditEvent(
      eventType: 'sync_conflict_requeued',
      actor: const BackupActorContext(
        reason: 'sync_conflict_requeue',
        userId: 'user-1',
        userName: 'Admin User',
        tenantId: 'tenant-1',
        schoolId: 'school-1',
        campusId: 'campus-1',
      ),
      metadata: const {
        'conflictId': 'conflict-1',
        'entityType': 'attendance_record',
      },
    );

    final status = await backup.getStatus();

    expect(status.pendingOperatorAuditCount, 1);
    expect(
      status.pendingOperatorAuditSummary,
      contains('sync_conflict_requeued (campus-1)'),
    );
  });
}
