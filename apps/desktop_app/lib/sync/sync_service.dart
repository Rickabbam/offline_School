import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/connectivity_monitor.dart';

const int _maxRetries = 5;
const int _pullPageSize = 250;
const Duration _pushInterval = Duration(seconds: 30);
const Duration _pullInterval = Duration(minutes: 2);

class SyncService {
  SyncService({
    required this.db,
    required AuthService auth,
  }) : _auth = auth;

  final AppDatabase db;
  final AuthService _auth;
  final _logger = Logger();
  final ConnectivityMonitor _connectivity = ConnectivityMonitor();

  Timer? _pushTimer;
  Timer? _pullTimer;
  StreamSubscription<bool>? _connectivitySub;
  late final VoidCallback _authListener;
  LocalDataScope? _lastReconciledScope;
  bool _suspendedForRestart = false;
  bool _remoteReconciliationInFlight = false;
  bool _pushCycleInFlight = false;
  bool _pullCycleInFlight = false;
  Future<void> Function()? onConnectivityRestored;

  bool get isRunning => _pushTimer != null;
  bool get isOnline => _connectivity.isOnline;
  bool get isSuspendedForRestart => _suspendedForRestart;

  static const List<String> _entityTypes = [
    'student',
    'guardian',
    'enrollment',
    'fee_category',
    'fee_structure_item',
    'invoice',
    'payment',
    'payment_reversal',
    'staff',
    'applicant',
    'attendance_record',
    'academic_year',
    'term',
    'class_level',
    'class_arm',
    'subject',
    'school',
    'campus',
    'grading_scheme',
    'staff_teaching_assignment',
  ];

  void start() {
    _authListener = _handleAuthChanged;
    _auth.addListener(_authListener);
    _connectivity.start().then((_) async {
      _logger.i('SyncService started. Online: ${_connectivity.isOnline}');
      await db.resetInProgressQueueItems();

      _pushTimer = Timer.periodic(_pushInterval, (_) => _runPushCycle());
      _pullTimer = Timer.periodic(_pullInterval, (_) => _runPullCycle());

      if (_connectivity.isOnline) {
        _checkPendingRemoteReconciliation();
        _runPushCycle();
        _runPullCycle();
      }

      _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
        if (online) {
          _logger.i('Back online - triggering sync.');
          final callback = onConnectivityRestored;
          if (callback != null) {
            callback();
          }
          _checkPendingRemoteReconciliation();
          _runPushCycle();
          _runPullCycle();
        }
      });
    });
  }

  void dispose() {
    _pushTimer?.cancel();
    _pullTimer?.cancel();
    _connectivitySub?.cancel();
    _auth.removeListener(_authListener);
    _connectivity.dispose();
  }

  void suspendForRestart() {
    _suspendedForRestart = true;
    _pushTimer?.cancel();
    _pullTimer?.cancel();
    _connectivitySub?.cancel();
    _auth.removeListener(_authListener);
  }

  Future<void> syncNow() async {
    if (_suspendedForRestart) {
      return;
    }
    await _ensureLocalScopeReconciled();
    await refreshReconciliationRequestCache();
    await _checkPendingRemoteReconciliation();
    await _runPushCycle();
    await _runPullCycle();
  }

  Future<void> retryFailedItems() async {
    if (_suspendedForRestart) {
      return;
    }
    final failedItems = await db.getRetryableFailedSyncQueueItems(limit: 100);
    for (final item in failedItems) {
      await db.resetQueueItemToPending(item.id);
    }
    await syncNow();
  }

  void _handleAuthChanged() {
    if (_suspendedForRestart) {
      return;
    }
    if (!_auth.isAuthenticated) {
      _lastReconciledScope = null;
      return;
    }

    _ensureLocalScopeReconciled();
    if (_connectivity.isOnline && !_auth.isOfflineSession) {
      refreshReconciliationRequestCache();
      _checkPendingRemoteReconciliation();
      _runPushCycle();
      _runPullCycle();
    }
  }

  Future<Map<String, dynamic>?> refreshReconciliationRequestCache() async {
    if (_suspendedForRestart ||
        !_connectivity.isOnline ||
        !_auth.isAuthenticated ||
        _auth.isOfflineSession) {
      return null;
    }

    final user = _auth.currentUser;
    final deviceId = await _auth.getDeviceFingerprint();
    if (user?.tenantId == null ||
        user?.schoolId == null ||
        deviceId == null ||
        deviceId.isEmpty) {
      return null;
    }

    final scope = LocalDataScope(
      tenantId: user!.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final client = _auth.createAuthenticatedClient();
    final response = await client.get<Map<String, dynamic>>(
      '/sync/reconciliation-requests/current',
      queryParameters: {'device_id': deviceId},
    );
    final request = response.data?['request'];
    if (request is! Map) {
      await db.clearPendingReconciliationRequestForDevice(
        scope: scope,
        targetDeviceId: deviceId,
      );
      return null;
    }

    final requestMap =
        Map<String, dynamic>.from(request.cast<String, dynamic>());
    await db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: Value('${requestMap['id']}'),
        tenantId: Value('${requestMap['tenantId']}'),
        schoolId: Value('${requestMap['schoolId']}'),
        campusId: Value(requestMap['campusId'] as String?),
        targetDeviceId: Value('${requestMap['targetDeviceId']}'),
        reason: Value('${requestMap['reason']}'),
        status: Value('${requestMap['status']}'),
        requestedAt: Value(DateTime.parse('${requestMap['requestedAt']}')),
        acknowledgedAt: Value(
          requestMap['acknowledgedAt'] == null
              ? null
              : DateTime.parse('${requestMap['acknowledgedAt']}'),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return requestMap;
  }

  Future<void> _checkPendingRemoteReconciliation() async {
    if (_suspendedForRestart ||
        _remoteReconciliationInFlight ||
        !_connectivity.isOnline ||
        !_auth.isAuthenticated ||
        _auth.isOfflineSession) {
      return;
    }

    final deviceId = await _auth.getDeviceFingerprint();
    if (deviceId == null || deviceId.isEmpty) {
      return;
    }

    _remoteReconciliationInFlight = true;
    try {
      final request = await refreshReconciliationRequestCache();
      if (request == null) {
        return;
      }

      final requestId = request['id'] as String?;
      if (requestId == null || requestId.isEmpty) {
        return;
      }

      _logger.i(
        'Applying remote reconciliation request $requestId for device $deviceId.',
      );
      await _ensureLocalScopeReconciled();
      await _runPushCycle();
      await _runPullCycle();
      final client = _auth.createAuthenticatedClient();
      await client.post<void>(
        '/sync/reconciliation-requests/$requestId/ack',
        data: {'device_id': deviceId},
      );
      final user = _auth.currentUser;
      if (user?.tenantId != null && user?.schoolId != null) {
        await db.markReconciliationRequestApplied(
          scope: LocalDataScope(
            tenantId: user!.tenantId!,
            schoolId: user.schoolId!,
            campusId: user.campusId,
          ),
          requestId: requestId,
          targetDeviceId: deviceId,
        );
      }
      _logger.i(
        'Acknowledged remote reconciliation request $requestId for device $deviceId.',
      );
    } on DioException catch (error) {
      _logger.w('Remote reconciliation check failed: ${error.message}');
    } catch (error) {
      _logger.w('Unexpected remote reconciliation error: $error');
    } finally {
      _remoteReconciliationInFlight = false;
    }
  }

  Future<void> _runPushCycle() async {
    if (_suspendedForRestart) {
      return;
    }
    if (!_connectivity.isOnline ||
        !_auth.isAuthenticated ||
        _auth.isOfflineSession ||
        _pushCycleInFlight) {
      return;
    }

    _pushCycleInFlight = true;
    try {
      var claimedCount = 0;
      while (true) {
        final item = await db.claimNextPendingQueueItem();
        if (item == null) {
          break;
        }

        claimedCount += 1;
        await _pushItem(item);
      }
      if (claimedCount > 0) {
        _logger.d('Push cycle: processed $claimedCount claimed item(s).');
      }
    } finally {
      _pushCycleInFlight = false;
    }
  }

  Future<void> _pushItem(SyncQueueData item) async {
    if (item.retryCount >= _maxRetries) {
      await db.markQueueItemFailed(item.id);
      _logger.w('Queue item ${item.id} exceeded max retries. Marked failed.');
      return;
    }

    try {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      final client = _auth.createAuthenticatedClient();
      final originDeviceId = await _auth.getDeviceFingerprint();

      final response = await client.post<Map<String, dynamic>>(
        '/sync/push',
        data: {
          'idempotency_key': item.idempotencyKey,
          if (originDeviceId != null) 'origin_device_id': originDeviceId,
          'lamport_clock': item.lamportClock,
          'entity_type': item.entityType,
          'entity_id': item.entityId,
          'operation': item.operation,
          'payload': payload,
        },
        options: Options(headers: {'X-Idempotency-Key': item.idempotencyKey}),
      );

      final ack = response.data;
      final acknowledgedEntityId = ack?['entityId'] as String? ?? item.entityId;
      final serverRevision = (ack?['serverRevision'] as num?)?.toInt();
      if (serverRevision == null) {
        throw StateError(
          'Sync push acknowledgement for ${item.entityType}/${item.entityId} '
          'did not include a server revision.',
        );
      }
      await db.applyPushAcknowledgement(
        queueItemId: item.id,
        entityType: item.entityType,
        requestedEntityId: item.entityId,
        canonicalEntityId: acknowledgedEntityId,
        serverRevision: serverRevision,
        tenantId: '${payload['tenantId']}',
        schoolId: '${payload['schoolId']}',
      );
      _logger
          .d('Pushed ${item.entityType}/${item.entityId} (${item.operation}).');
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 409) {
        await db.markQueueItemFailed(item.id);
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        await db.recordSyncConflict(
          queueItemId: item.id,
          tenantId: '${payload['tenantId']}',
          schoolId: '${payload['schoolId']}',
          campusId: payload['campusId'] as String?,
          entityType: item.entityType,
          entityId: item.entityId,
          operation: item.operation,
          conflictType: 'stale_update',
          payload: payload,
          serverMessage: error.response?.data is Map<String, dynamic>
              ? (error.response!.data as Map<String, dynamic>)['message']
                  as String?
              : error.message,
          response: error.response?.data is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  error.response!.data as Map<String, dynamic>,
                )
              : null,
        );
        _logger.w(
          'Push conflict for ${item.entityType}/${item.entityId}. Marked failed for manual review.',
        );
        return;
      }

      await db.incrementQueueRetry(item.id);
      _logger.w('Push failed for item ${item.id}: ${error.message}');
    } catch (error) {
      await db.incrementQueueRetry(item.id);
      _logger.w('Unexpected push error for item ${item.id}: $error');
    }
  }

  Future<void> _runPullCycle() async {
    if (_suspendedForRestart) {
      return;
    }
    if (!_connectivity.isOnline ||
        !_auth.isAuthenticated ||
        _auth.isOfflineSession ||
        _pullCycleInFlight) {
      return;
    }

    _pullCycleInFlight = true;
    try {
      await _ensureLocalScopeReconciled();

      for (final entityType in _entityTypes) {
        await _pullDeltas(entityType);
      }
    } finally {
      _pullCycleInFlight = false;
    }
  }

  Future<void> _pullDeltas(String entityType) async {
    var cursor = await db.getLastRevision(entityType);
    var totalAppliedCount = 0;
    Map<String, dynamic>? deferredRecord;
    int? deferredRevision;

    try {
      final client = _auth.createAuthenticatedClient();
      while (true) {
        final response = await client.get<Map<String, dynamic>>(
          '/sync/pull',
          queryParameters: {
            'entity_type': entityType,
            'since': cursor,
            'limit': _pullPageSize,
          },
        );

        final data = response.data;
        if (data == null) {
          return;
        }

        final records = data['records'] as List<dynamic>? ?? [];
        final newRevision = data['latest_revision'] as int? ?? cursor;
        final hasMore = data['has_more'] as bool? ?? false;
        final nextSince = data['next_since'] as int? ?? newRevision;
        var latestAppliedRevision = cursor;

        if (records.isNotEmpty) {
          for (final item in records) {
            final envelope = Map<String, dynamic>.from(item as Map);
            final record = Map<String, dynamic>.from(
              envelope['record'] as Map<String, dynamic>,
            );
            final recordId = '${record['id']}';
            final revision = (envelope['revision'] as num?)?.toInt() ??
                (record['serverRevision'] as int? ?? latestAppliedRevision);

            if (await db.hasBlockingSyncStateForEntity(
              entityType: entityType,
              entityId: recordId,
            )) {
              deferredRecord = record;
              deferredRevision = revision;
              await db.recordSyncConflict(
                queueItemId: null,
                tenantId: '${record['tenantId']}',
                schoolId: '${record['schoolId']}',
                campusId: record['campusId'] as String?,
                entityType: entityType,
                entityId: recordId,
                operation: 'pull',
                conflictType: 'pull_deferred',
                payload: record,
                serverMessage:
                    'Inbound sync was deferred because local unsynced work or an open conflict exists.',
                response: {
                  'revision': revision,
                  'reason': 'blocking_local_sync_state',
                },
              );
              break;
            }

            final blockingLocalEntityId =
                await findBlockingLocalEntityIdForPull(
              entityType: entityType,
              record: record,
            );
            if (blockingLocalEntityId != null) {
              deferredRecord = record;
              deferredRevision = revision;
              await db.recordSyncConflict(
                queueItemId: null,
                tenantId: '${record['tenantId']}',
                schoolId: '${record['schoolId']}',
                campusId: record['campusId'] as String?,
                entityType: entityType,
                entityId: recordId,
                operation: 'pull',
                conflictType: 'pull_deferred',
                payload: record,
                serverMessage:
                    'Inbound sync was deferred because matching local offline work exists under a different entity id.',
                response: {
                  'revision': revision,
                  'reason': 'blocking_local_natural_key_sync_state',
                  'blockingEntityId': blockingLocalEntityId,
                },
              );
              break;
            }

            await _applyPulledRecord(entityType, record);
            totalAppliedCount += 1;
            if (revision > latestAppliedRevision) {
              latestAppliedRevision = revision;
            }
          }
        }

        final targetRevision =
            deferredRecord == null ? newRevision : latestAppliedRevision;
        if (targetRevision > cursor) {
          await db.updateLastRevision(entityType, targetRevision);
          cursor = targetRevision;
        }

        if (deferredRecord != null) {
          break;
        }

        if (!hasMore || records.isEmpty) {
          cursor = nextSince > cursor ? nextSince : cursor;
          break;
        }

        cursor = nextSince > cursor ? nextSince : cursor;
      }

      if (totalAppliedCount > 0) {
        _logger.d(
          'Pulled $totalAppliedCount $entityType delta(s) up to revision $cursor.',
        );
      }
      if (deferredRecord != null) {
        _logger.w(
          'Deferred pull for $entityType/${deferredRecord['id']} at revision '
          '${deferredRevision ?? '?'} because local unsynced work or an open conflict exists.',
        );
      }
    } on DioException catch (error) {
      _logger.w('Pull failed for $entityType: ${error.message}');
    } catch (error) {
      _logger.w('Unexpected pull error for $entityType: $error');
    }
  }

  @visibleForTesting
  Future<String?> findBlockingLocalEntityIdForPull({
    required String entityType,
    required Map<String, dynamic> record,
  }) async {
    switch (entityType) {
      case 'attendance_record':
        final tenantId = record['tenantId'] as String?;
        final schoolId = record['schoolId'] as String?;
        final classArmId = record['classArmId'] as String?;
        final studentId = record['studentId'] as String?;
        final attendanceDate = record['attendanceDate'] as String?;
        if (tenantId == null ||
            schoolId == null ||
            classArmId == null ||
            studentId == null ||
            attendanceDate == null) {
          return null;
        }

        final localRecord = await db.findAttendanceRecord(
          scope: LocalDataScope(
            tenantId: tenantId,
            schoolId: schoolId,
            campusId: record['campusId'] as String?,
          ),
          classArmId: classArmId,
          studentId: studentId,
          date: attendanceDate,
        );
        if (localRecord == null || localRecord.id == '${record['id']}') {
          return null;
        }

        final hasBlockingState = await db.hasBlockingSyncStateForEntity(
          entityType: entityType,
          entityId: localRecord.id,
        );
        return hasBlockingState ? localRecord.id : null;
      default:
        return null;
    }
  }

  Future<void> _applyPulledRecord(
    String entityType,
    Map<String, dynamic> record,
  ) async {
    switch (entityType) {
      case 'student':
        await db.upsertStudent(
          StudentsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            studentNumber: Value(record['studentNumber'] as String?),
            firstName: Value('${record['firstName']}'),
            middleName: Value(record['middleName'] as String?),
            lastName: Value('${record['lastName']}'),
            dateOfBirth: Value(record['dateOfBirth'] as String?),
            gender: Value(record['gender'] as String?),
            status: Value('${record['status']}'),
            profilePhotoUrl: Value(record['profilePhotoUrl'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'guardian':
        await db.upsertGuardian(
          GuardiansCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            studentId: Value('${record['studentId']}'),
            firstName: Value('${record['firstName']}'),
            lastName: Value('${record['lastName']}'),
            relationship: Value('${record['relationship']}'),
            phone: Value(record['phone'] as String?),
            email: Value(record['email'] as String?),
            isPrimary: Value(record['isPrimary'] as bool? ?? false),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
          ),
        );
        break;
      case 'enrollment':
        await db.upsertEnrollment(
          EnrollmentsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            studentId: Value('${record['studentId']}'),
            classArmId: Value('${record['classArmId']}'),
            academicYearId: Value('${record['academicYearId']}'),
            enrollmentDate: Value('${record['enrollmentDate']}'),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
          ),
        );
        break;
      case 'fee_category':
        await db.upsertFeeCategory(
          FeeCategoriesCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            name: Value('${record['name']}'),
            billingTerm: Value('${record['billingTerm']}'),
            isActive: Value(record['isActive'] as bool? ?? true),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'fee_structure_item':
        await db.upsertFeeStructureItem(
          FeeStructureItemsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            feeCategoryId: Value('${record['feeCategoryId']}'),
            classLevelId: Value(record['classLevelId'] as String?),
            termId: Value(record['termId'] as String?),
            amount: Value((record['amount'] as num?)?.toDouble() ??
                double.parse('${record['amount']}')),
            notes: Value(record['notes'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'invoice':
        await db.upsertInvoice(
          InvoicesCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            studentId: Value('${record['studentId']}'),
            academicYearId: Value('${record['academicYearId']}'),
            termId: Value('${record['termId']}'),
            classArmId: Value('${record['classArmId']}'),
            invoiceCode: Value('${record['invoiceCode']}'),
            status: Value('${record['status']}'),
            lineItemsJson: Value(jsonEncode(record['lineItems'] ?? const [])),
            totalAmount: Value((record['totalAmount'] as num?)?.toDouble() ??
                double.parse('${record['totalAmount']}')),
            generatedByUserId: Value(record['generatedByUserId'] as String?),
            postedAt: Value(
              record['postedAt'] == null
                  ? null
                  : DateTime.parse('${record['postedAt']}'),
            ),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'payment':
        await db.upsertPayment(
          PaymentsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            invoiceId: Value('${record['invoiceId']}'),
            paymentCode: Value('${record['paymentCode']}'),
            status: Value('${record['status']}'),
            amount: Value((record['amount'] as num?)?.toDouble() ??
                double.parse('${record['amount']}')),
            paymentMode: Value('${record['paymentMode']}'),
            paymentDate: Value('${record['paymentDate']}'),
            reference: Value(record['reference'] as String?),
            notes: Value(record['notes'] as String?),
            receivedByUserId: Value(record['receivedByUserId'] as String?),
            postedAt: Value(
              record['postedAt'] == null
                  ? null
                  : DateTime.parse('${record['postedAt']}'),
            ),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'payment_reversal':
        await db.upsertPaymentReversal(
          PaymentReversalsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            paymentId: Value('${record['paymentId']}'),
            invoiceId: Value('${record['invoiceId']}'),
            amount: Value((record['amount'] as num?)?.toDouble() ??
                double.parse('${record['amount']}')),
            reason: Value('${record['reason']}'),
            reversedByUserId: Value(record['reversedByUserId'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'staff':
        await db.upsertStaff(
          StaffCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            userId: Value(record['userId'] as String?),
            staffNumber: Value(record['staffNumber'] as String?),
            firstName: Value('${record['firstName']}'),
            middleName: Value(record['middleName'] as String?),
            lastName: Value('${record['lastName']}'),
            gender: Value(record['gender'] as String?),
            phone: Value(record['phone'] as String?),
            email: Value(record['email'] as String?),
            department: Value(record['department'] as String?),
            systemRole: Value('${record['systemRole']}'),
            employmentType: Value('${record['employmentType']}'),
            dateJoined: Value(record['dateJoined'] as String?),
            isActive: Value(record['isActive'] as bool? ?? true),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'staff_teaching_assignment':
        await db.upsertStaffAssignment(
          StaffTeachingAssignmentsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            staffId: Value('${record['staffId']}'),
            assignmentType: Value('${record['assignmentType']}'),
            subjectId: Value(record['subjectId'] as String?),
            classArmId: Value(record['classArmId'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'applicant':
        await db.upsertApplicant(
          ApplicantsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            firstName: Value('${record['firstName']}'),
            middleName: Value(record['middleName'] as String?),
            lastName: Value('${record['lastName']}'),
            dateOfBirth: Value(record['dateOfBirth'] as String?),
            gender: Value(record['gender'] as String?),
            classLevelId: Value(record['classLevelId'] as String?),
            academicYearId: Value(record['academicYearId'] as String?),
            status: Value('${record['status']}'),
            guardianName: Value(record['guardianName'] as String?),
            guardianPhone: Value(record['guardianPhone'] as String?),
            guardianEmail: Value(record['guardianEmail'] as String?),
            documentNotes: Value(record['documentNotes'] as String?),
            studentId: Value(record['studentId'] as String?),
            admittedAt: Value(
              record['admittedAt'] == null
                  ? null
                  : DateTime.parse('${record['admittedAt']}'),
            ),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'attendance_record':
        await db.upsertAttendanceRecord(
          AttendanceRecordsCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            campusId: Value(record['campusId'] as String?),
            studentId: Value('${record['studentId']}'),
            classArmId: Value('${record['classArmId']}'),
            academicYearId: Value('${record['academicYearId']}'),
            termId: Value('${record['termId']}'),
            attendanceDate: Value('${record['attendanceDate']}'),
            status: Value('${record['status']}'),
            notes: Value(record['notes'] as String?),
            recordedByUserId: Value(record['recordedByUserId'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            syncStatus: const Value('synced'),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'academic_year':
        await db.upsertAcademicYear(
          AcademicYearsCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            label: Value('${record['label']}'),
            startDate: Value('${record['startDate']}'),
            endDate: Value('${record['endDate']}'),
            isCurrent: Value(record['isCurrent'] as bool? ?? false),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'term':
        await db.upsertTerm(
          TermsCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            academicYearId: Value('${record['academicYearId']}'),
            name: Value('${record['name']}'),
            termNumber: Value(record['termNumber'] as int? ?? 0),
            startDate: Value('${record['startDate']}'),
            endDate: Value('${record['endDate']}'),
            isCurrent: Value(record['isCurrent'] as bool? ?? false),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'class_level':
        await db.upsertClassLevel(
          ClassLevelsCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            name: Value('${record['name']}'),
            sortOrder: Value(record['sortOrder'] as int? ?? 0),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'class_arm':
        await db.upsertClassArm(
          ClassArmsCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            classLevelId: Value('${record['classLevelId']}'),
            arm: Value('${record['arm']}'),
            displayName: Value('${record['displayName']}'),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'subject':
        await db.upsertSubject(
          SubjectsCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            name: Value('${record['name']}'),
            code: Value(record['code'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'school':
        await db.upsertSchoolProfile(
          SchoolProfileCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            name: Value('${record['name']}'),
            shortName: Value(record['shortName'] as String?),
            schoolType: Value('${record['schoolType']}'),
            address: Value(record['address'] as String?),
            region: Value(record['region'] as String?),
            district: Value(record['district'] as String?),
            contactPhone: Value(record['contactPhone'] as String?),
            contactEmail: Value(record['contactEmail'] as String?),
            onboardingDefaultsJson:
                Value(jsonEncode(record['onboardingDefaults'] ?? const {})),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'campus':
        await db.upsertCampusProfile(
          CampusProfileCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            name: Value('${record['name']}'),
            address: Value(record['address'] as String?),
            contactPhone: Value(record['contactPhone'] as String?),
            registrationCode: Value(record['registrationCode'] as String?),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
      case 'grading_scheme':
        await db.upsertGradingScheme(
          GradingSchemesCacheCompanion(
            id: Value('${record['id']}'),
            tenantId: Value('${record['tenantId']}'),
            schoolId: Value('${record['schoolId']}'),
            name: Value('${record['name']}'),
            bandsJson: Value(jsonEncode(record['bands'])),
            isDefault: Value(record['isDefault'] as bool? ?? false),
            serverRevision: Value(record['serverRevision'] as int? ?? 0),
            deleted: Value(record['deleted'] as bool? ?? false),
            createdAt: Value(DateTime.parse('${record['createdAt']}')),
            updatedAt: Value(DateTime.parse('${record['updatedAt']}')),
          ),
        );
        break;
    }

    await db.resolveOpenSyncConflictForEntity(
      tenantId: '${record['tenantId']}',
      schoolId: '${record['schoolId']}',
      campusId: record['campusId'] as String?,
      entityType: entityType,
      entityId: '${record['id']}',
      conflictType: 'pull_deferred',
    );
  }

  Future<void> _ensureLocalScopeReconciled() async {
    final user = _auth.currentUser;
    if (user?.tenantId == null || user?.schoolId == null) {
      return;
    }

    final scope = LocalDataScope(
      tenantId: user!.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    if (_isSameScope(scope, _lastReconciledScope)) {
      return;
    }

    await db.reconcileLocalScope(scope: scope);
    _lastReconciledScope = scope;
    _logger.i(
      'Reconciled local SQLite scope for tenant ${scope.tenantId}, school ${scope.schoolId}, campus ${scope.campusId ?? 'none'}.',
    );
  }

  bool _isSameScope(LocalDataScope current, LocalDataScope? previous) {
    if (previous == null) {
      return false;
    }
    return current.tenantId == previous.tenantId &&
        current.schoolId == previous.schoolId &&
        current.campusId == previous.campusId;
  }
}
