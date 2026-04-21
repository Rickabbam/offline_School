import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../database/app_database.dart';
import 'connectivity_monitor.dart';

/// How many push failures before a queue item is permanently abandoned.
const int _maxRetries = 5;

/// Interval between push cycles when online.
const Duration _pushInterval = Duration(seconds: 30);

/// Interval between delta pull cycles when online.
const Duration _pullInterval = Duration(minutes: 2);

/// Background service that:
///   1. Detects internet connectivity via [ConnectivityMonitor].
///   2. Pushes pending [SyncQueue] items to the backend.
///   3. Pulls delta updates from the backend for each known entity type.
///
/// The service runs silently and never blocks the UI thread.
class SyncService {
  SyncService({required this.db, String? backendBaseUrl})
      : _baseUrl = backendBaseUrl ?? const String.fromEnvironment(
          'BACKEND_URL',
          defaultValue: 'http://localhost:3000',
        );

  final AppDatabase db;
  final String _baseUrl;
  final _logger = Logger();
  final ConnectivityMonitor _connectivity = ConnectivityMonitor();

  late final Dio _dio;
  Timer? _pushTimer;
  Timer? _pullTimer;
  StreamSubscription<bool>? _connectivitySub;

  bool get isRunning => _pushTimer != null;

  /// Starts the background sync loops. Call once from [main].
  void start() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _connectivity.start().then((_) {
      _logger.i('SyncService started. Online: ${_connectivity.isOnline}');

      // Schedule periodic push and pull regardless of connectivity.
      // Each cycle checks [isOnline] before doing network work.
      _pushTimer = Timer.periodic(_pushInterval, (_) => _runPushCycle());
      _pullTimer = Timer.periodic(_pullInterval, (_) => _runPullCycle());

      // Run immediately on startup if already online.
      if (_connectivity.isOnline) {
        _runPushCycle();
        _runPullCycle();
      }

      // Re-run immediately when connectivity is restored.
      _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
        if (online) {
          _logger.i('Back online — triggering sync.');
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
    _connectivity.dispose();
  }

  // ─── Push cycle ────────────────────────────────────────────────────────────

  Future<void> _runPushCycle() async {
    if (!_connectivity.isOnline) return;

    final pending = await db.getPendingQueueItems();
    if (pending.isEmpty) return;

    _logger.d('Push cycle: ${pending.length} item(s) to push.');

    for (final item in pending) {
      await _pushItem(item);
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

      await _dio.post(
        '/sync/push',
        data: {
          'idempotency_key': item.idempotencyKey,
          'entity_type': item.entityType,
          'entity_id': item.entityId,
          'operation': item.operation,
          'payload': payload,
        },
        options: Options(headers: {'X-Idempotency-Key': item.idempotencyKey}),
      );

      await db.markQueueItemDone(item.id);
      _logger.d('Pushed ${item.entityType}/${item.entityId} (${item.operation}).');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // 409 Conflict = server already processed this idempotency key.
        await db.markQueueItemDone(item.id);
        _logger.d('Item ${item.id} already on server (409). Marked done.');
      } else {
        await db.incrementQueueRetry(item.id);
        _logger.w('Push failed for item ${item.id}: ${e.message}');
      }
    } catch (e) {
      await db.incrementQueueRetry(item.id);
      _logger.w('Unexpected push error for item ${item.id}: $e');
    }
  }

  // ─── Pull cycle ────────────────────────────────────────────────────────────

  /// Entity types registered for delta pull.
  /// Extend this list as new entity modules are added in Phase B+.
  static const List<String> _entityTypes = [
    // Phase B additions will append here: 'student', 'staff', etc.
  ];

  Future<void> _runPullCycle() async {
    if (!_connectivity.isOnline) return;
    if (_entityTypes.isEmpty) return;

    for (final entityType in _entityTypes) {
      await _pullDeltas(entityType);
    }
  }

  Future<void> _pullDeltas(String entityType) async {
    final since = await db.getLastRevision(entityType);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {'entity_type': entityType, 'since': since},
      );

      final data = response.data;
      if (data == null) return;

      final records = data['records'] as List<dynamic>? ?? [];
      final newRevision = data['latest_revision'] as int? ?? since;

      if (records.isNotEmpty) {
        _logger.d(
          'Pulled ${records.length} ${entityType} delta(s) '
          '(revision $since → $newRevision).',
        );
        // TODO Phase B: dispatch records to entity-specific DAOs for upsert.
      }

      if (newRevision > since) {
        await db.updateLastRevision(entityType, newRevision);
      }
    } on DioException catch (e) {
      _logger.w('Pull failed for $entityType: ${e.message}');
    } catch (e) {
      _logger.w('Unexpected pull error for $entityType: $e');
    }
  }
}
