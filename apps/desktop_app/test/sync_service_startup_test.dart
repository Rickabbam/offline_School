import 'dart:async';
import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/connectivity_monitor.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingConnectivitySource implements ConnectivitySource {
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => false;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<void> start() async {
    throw StateError('connectivity unavailable');
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.runMigrations();
  });

  tearDown(() async {
    await db.close();
  });

  test('sync startup resets in-progress queue items even when connectivity fails',
      () async {
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'queue-startup-1',
            entityType: 'student',
            entityId: 'student-1',
            operation: 'update',
            payloadJson: jsonEncode({
              'tenantId': 'tenant-1',
              'schoolId': 'school-1',
              'id': 'student-1',
            }),
            idempotencyKey: 'student:student-1:queue-startup-1',
            status: const Value('in_progress'),
          ),
        );

    final service = SyncService(
      db: db,
      auth: AuthService(),
      connectivity: _FailingConnectivitySource(),
    );

    await service.start();

    final queueItem = await (db.select(db.syncQueue)
          ..where((row) => row.id.equals('queue-startup-1')))
        .getSingle();
    expect(queueItem.status, 'pending');
    expect(service.isRunning, isTrue);

    service.dispose();
    expect(service.isRunning, isFalse);
  });
}
