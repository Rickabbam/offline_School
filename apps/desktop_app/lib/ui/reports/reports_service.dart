import 'dart:convert';

import 'package:desktop_app/backup/backup_service.dart';
import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:drift/drift.dart';

class SyncConflictView {
  const SyncConflictView({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.conflictType,
    required this.serverMessage,
    required this.createdAt,
    this.baseUpdatedAt,
    this.serverUpdatedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String conflictType;
  final String? serverMessage;
  final DateTime createdAt;
  final String? baseUpdatedAt;
  final String? serverUpdatedAt;
}

class ReconciliationRequestView {
  const ReconciliationRequestView({
    required this.id,
    required this.targetDeviceId,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.acknowledgedAt,
  });

  final String id;
  final String targetDeviceId;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final DateTime? acknowledgedAt;
}

class ReportsWorkspaceData {
  const ReportsWorkspaceData({
    required this.summaryCounts,
    required this.admissionStatusCounts,
    required this.currentAcademicYears,
    required this.availableSections,
    required this.syncQueueCounts,
    required this.lastPulls,
    required this.pilotChecks,
    required this.recentQueueItems,
    required this.failedQueueItems,
    required this.openSyncConflictCount,
    required this.syncConflictItems,
    required this.canManageSyncConflicts,
    required this.pendingReconciliationRequestCount,
    required this.reconciliationRequestItems,
    required this.canRequestReconciliation,
    required this.backupStatusLabel,
    required this.backupValidationLabel,
    required this.isBackupValidationHealthy,
    required this.restoreDrillStatusLabel,
    required this.unresolvedSyncReviewLabel,
    required this.unresolvedSyncItems,
    required this.pendingOperatorAuditLabel,
    required this.pendingOperatorAuditItems,
    required this.recentBackups,
    required this.backupAuditEntries,
    required this.isOnline,
    required this.isOfflineSession,
  });

  final Map<String, int> summaryCounts;
  final Map<String, int> admissionStatusCounts;
  final List<String> currentAcademicYears;
  final List<String> availableSections;
  final Map<String, int> syncQueueCounts;
  final List<String> lastPulls;
  final Map<String, bool> pilotChecks;
  final List<String> recentQueueItems;
  final List<String> failedQueueItems;
  final int openSyncConflictCount;
  final List<SyncConflictView> syncConflictItems;
  final bool canManageSyncConflicts;
  final int pendingReconciliationRequestCount;
  final List<ReconciliationRequestView> reconciliationRequestItems;
  final bool canRequestReconciliation;
  final String backupStatusLabel;
  final String backupValidationLabel;
  final bool isBackupValidationHealthy;
  final String restoreDrillStatusLabel;
  final String unresolvedSyncReviewLabel;
  final List<String> unresolvedSyncItems;
  final String pendingOperatorAuditLabel;
  final List<String> pendingOperatorAuditItems;
  final List<String> recentBackups;
  final List<String> backupAuditEntries;
  final bool isOnline;
  final bool isOfflineSession;
}

class ReportsService {
  ReportsService({
    required AuthService auth,
    required AppDatabase db,
    required BackupService backup,
    required SyncService sync,
  })  : _auth = auth,
        _db = db,
        _backup = backup,
        _sync = sync;

  final AuthService _auth;
  final AppDatabase _db;
  final BackupService _backup;
  final SyncService _sync;

  AuthUser get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user available.');
    }
    return user;
  }

  Future<ReportsWorkspaceData> loadWorkspace() async {
    final user = _user;
    if (user.tenantId == null || user.schoolId == null) {
      throw StateError('Reports require tenant and school scope.');
    }
    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final canViewOperationalData = _canViewOperationalReportData(user);
    final students = canViewOperationalData
        ? await _db.getStudents(scope: scope)
        : const <Student>[];
    final applicants = canViewOperationalData
        ? await _db.getApplicants(scope: scope)
        : const <Applicant>[];
    final academicYears = canViewOperationalData
        ? await _db.getAcademicYears(scope: scope)
        : const <AcademicYearsCacheData>[];
    final classArms = canViewOperationalData
        ? await _db.getClassArms(scope: scope)
        : const <ClassArmsCacheData>[];
    final subjects = canViewOperationalData
        ? await _db.getSubjects(scope: scope)
        : const <SubjectsCacheData>[];
    final staff = user.role == 'admin' && canViewOperationalData
        ? await _db.getAllStaff(scope: scope)
        : const <StaffData>[];
    final queueCounts = await _db.getSyncQueueCounts();
    final syncStates = await _db.getAllSyncStates();
    final recentQueueItems = await _db.getRecentSyncQueueItems(limit: 8);
    final failedQueueItems = await _db.getFailedSyncQueueItems(limit: 12);
    if (_sync.isOnline && !_auth.isOfflineSession) {
      try {
        await _sync.refreshReconciliationRequestCache();
      } catch (_) {}
    }
    final pendingReconciliationRequestCount =
        await _db.getPendingReconciliationRequestCount(scope: scope);
    final reconciliationRequests = await _db.getRecentReconciliationRequests(
      scope: scope,
      limit: 10,
    );
    final openSyncConflictCount = await _db.getOpenSyncConflictCount(
      scope: scope,
    );
    final recentSyncConflicts = await _db.getRecentSyncConflicts(
      scope: scope,
      limit: 12,
    );
    final backupStatus = await _backup.getStatus();
    final latestRestoreDrill = backupStatus.auditEntries
        .where(
          (entry) =>
              entry.eventType == 'restore_drill_passed' ||
              entry.eventType == 'restore_drill_failed',
        )
        .cast<BackupAuditEntry?>()
        .firstWhere(
          (entry) => entry != null,
          orElse: () => null,
        );

    final summaryCounts = canViewOperationalData
        ? <String, int>{
            'Students': students.length,
            'Applicants': applicants.length,
            'Attendance Records':
                await _db.getScopedAttendanceRecordCount(scope: scope),
            'Pending Sync': queueCounts['pending'] ?? 0,
            'Failed Sync': queueCounts['failed'] ?? 0,
            'Open Conflicts': openSyncConflictCount,
            'Reconciliation Requests': pendingReconciliationRequestCount,
            'Pending Audit Uploads': backupStatus.pendingOperatorAuditCount,
          }
        : <String, int>{
            'Pending Sync': queueCounts['pending'] ?? 0,
            'Failed Sync': queueCounts['failed'] ?? 0,
            'Open Conflicts': openSyncConflictCount,
            'Reconciliation Requests': pendingReconciliationRequestCount,
            'Pending Audit Uploads': backupStatus.pendingOperatorAuditCount,
            'Tracked Pull States': syncStates.length,
            'Recent Backups': backupStatus.backups.take(5).length,
            'Unresolved Restore Review': backupStatus.unresolvedSyncCount,
          };

    if (staff.isNotEmpty) {
      summaryCounts['Staff'] = staff.length;
    }

    final admissionStatusCounts = <String, int>{};
    for (final applicant in applicants) {
      admissionStatusCounts.update(
        _titleCase(applicant.status),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final currentAcademicYears = canViewOperationalData
        ? academicYears
            .where((item) => item.isCurrent == true)
            .map((item) => item.label)
            .toList(growable: false)
        : const <String>[];

    final availableSections = canViewOperationalData
        ? <String>[
            'Students',
            'Admissions',
            'Attendance',
            'Academic Years',
            'Class Arms',
            'Subjects',
            if (staff.isNotEmpty) 'Staff',
            'Sync Queue',
            'Sync Conflicts',
            'Backups',
            'Restore Readiness',
          ]
        : <String>[
            'Sync Queue',
            'Sync Conflicts',
            'Backups',
            'Restore Readiness',
            'Backup Audit',
          ];

    final lastPulls = syncStates
        .where((item) => item.lastPulledAt != null)
        .map(
          (item) =>
              '${item.entityType}: ${item.lastPulledAt!.toLocal().toString().substring(0, 19)}',
        )
        .toList(growable: false);

    final pilotChecks = canViewOperationalData
        ? <String, bool>{
            'Academic year configured': academicYears.isNotEmpty,
            'Class arms configured': classArms.isNotEmpty,
            'Subjects configured': subjects.isNotEmpty,
            'Students captured locally': students.isNotEmpty,
            'Attendance ready offline':
                currentAcademicYears.isNotEmpty && classArms.isNotEmpty,
            'Sync queue clear of failures': (queueCounts['failed'] ?? 0) == 0,
            'No pending reconciliation requests':
                pendingReconciliationRequestCount == 0,
            'No unresolved sync conflicts': openSyncConflictCount == 0,
            'Automatic local backup healthy': backupStatus.isHealthy,
            'Restore drill recently passed':
                latestRestoreDrill?.eventType == 'restore_drill_passed',
            'No unresolved unsynced records for restore':
                backupStatus.unresolvedSyncCount == 0,
            'Operator recovery audit flushed':
                backupStatus.pendingOperatorAuditCount == 0,
            'Trusted online session available': !_auth.isOfflineSession,
          }
        : <String, bool>{
            'Sync queue clear of failures': (queueCounts['failed'] ?? 0) == 0,
            'No pending reconciliation requests':
                pendingReconciliationRequestCount == 0,
            'No unresolved sync conflicts': openSyncConflictCount == 0,
            'Automatic local backup healthy': backupStatus.isHealthy,
            'Restore drill recently passed':
                latestRestoreDrill?.eventType == 'restore_drill_passed',
            'No unresolved unsynced records for restore':
                backupStatus.unresolvedSyncCount == 0,
            'Operator recovery audit flushed':
                backupStatus.pendingOperatorAuditCount == 0,
            'Trusted online session available': !_auth.isOfflineSession,
            'Running online session available':
                _sync.isOnline && !_auth.isOfflineSession,
          };
    if (user.role == 'admin' && canViewOperationalData) {
      pilotChecks['Staff captured locally'] = staff.isNotEmpty;
    }

    return ReportsWorkspaceData(
      summaryCounts: summaryCounts,
      admissionStatusCounts: admissionStatusCounts,
      currentAcademicYears: currentAcademicYears,
      availableSections: availableSections,
      syncQueueCounts: queueCounts,
      lastPulls: lastPulls,
      pilotChecks: pilotChecks,
      recentQueueItems: recentQueueItems
          .map(
            (item) =>
                '${item.status.toUpperCase()} ${item.entityType} ${item.operation} (retries: ${item.retryCount})',
          )
          .toList(growable: false),
      failedQueueItems: failedQueueItems
          .map(
            (item) =>
                '${item.entityType} ${item.operation} for ${item.entityId} (retries: ${item.retryCount})',
          )
          .toList(growable: false),
      openSyncConflictCount: openSyncConflictCount,
      syncConflictItems: recentSyncConflicts.map(
        (item) {
          final responseJson = item.responseJson == null
              ? null
              : jsonDecode(item.responseJson!) as Map<String, dynamic>;
          return SyncConflictView(
            id: item.id,
            entityType: item.entityType,
            entityId: item.entityId,
            operation: item.operation,
            conflictType: item.conflictType,
            serverMessage: item.serverMessage,
            createdAt: item.createdAt,
            baseUpdatedAt: responseJson?['baseUpdatedAt'] as String?,
            serverUpdatedAt: responseJson?['serverUpdatedAt'] as String?,
          );
        },
      ).toList(growable: false),
      canManageSyncConflicts: _canManageSyncConflicts(user),
      pendingReconciliationRequestCount: pendingReconciliationRequestCount,
      reconciliationRequestItems: reconciliationRequests
          .map(
            (item) => ReconciliationRequestView(
              id: item.id,
              targetDeviceId: item.targetDeviceId,
              reason: item.reason,
              status: item.status,
              requestedAt: item.requestedAt,
              acknowledgedAt: item.acknowledgedAt,
            ),
          )
          .toList(growable: false),
      canRequestReconciliation: _canRequestReconciliation(user),
      backupStatusLabel: backupStatus.latestBackup == null
          ? 'No local backup created yet'
          : 'Latest backup: ${backupStatus.latestBackup!.createdAt.toString().substring(0, 19)}',
      backupValidationLabel: backupStatus.latestValidationMessage,
      isBackupValidationHealthy: backupStatus.latestBackupValidated,
      restoreDrillStatusLabel: latestRestoreDrill == null
          ? 'No restore drill recorded yet'
          : '${latestRestoreDrill.timestamp.toString().substring(0, 19)} ${latestRestoreDrill.eventType}',
      unresolvedSyncReviewLabel: backupStatus.unresolvedSyncCount == 0
          ? 'No unresolved local sync changes'
          : '${backupStatus.unresolvedSyncCount} local change(s) need review before restore',
      unresolvedSyncItems: backupStatus.unresolvedSyncSummary,
      pendingOperatorAuditLabel: backupStatus.pendingOperatorAuditCount == 0
          ? 'No pending operator audit uploads'
          : '${backupStatus.pendingOperatorAuditCount} operator audit event(s) waiting for upload',
      pendingOperatorAuditItems: backupStatus.pendingOperatorAuditSummary,
      recentBackups: backupStatus.backups
          .take(5)
          .map(
            (backup) =>
                '${backup.createdAt.toString().substring(0, 19)} ${backup.fileName} (${(backup.fileSizeBytes / 1024).toStringAsFixed(1)} KB) ${backup.actor.campusId ?? 'unscoped'}',
          )
          .toList(growable: false),
      backupAuditEntries: backupStatus.auditEntries
          .map(
            (entry) =>
                '${entry.timestamp.toString().substring(0, 19)} ${entry.eventType}: ${entry.message}',
          )
          .toList(growable: false),
      isOnline: _sync.isOnline,
      isOfflineSession: _auth.isOfflineSession,
    );
  }

  Future<void> syncNow() => _sync.syncNow();

  Future<void> retryFailedItems() => _sync.retryFailedItems();

  Future<void> requestDeviceReconciliation({String? reason}) async {
    final user = _user;
    if (!_canRequestReconciliation(user)) {
      throw StateError('Your role cannot request sync reconciliation.');
    }
    if (_auth.isOfflineSession || !_sync.isOnline) {
      throw StateError(
        'Requesting reconciliation requires an online trusted session.',
      );
    }

    final deviceId = await _auth.getDeviceFingerprint();
    if (deviceId == null || deviceId.isEmpty) {
      throw StateError('This device is missing a registered fingerprint.');
    }

    final response = await _auth.createAuthenticatedClient().post<Map<String, dynamic>>(
      '/sync/reconciliation-requests',
      data: {
        'target_device_id': deviceId,
        if (user.campusId != null) 'campus_id': user.campusId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final request = Map<String, dynamic>.from(response.data!);
    await _db.upsertReconciliationRequestCache(
      SyncReconciliationRequestsCacheCompanion(
        id: Value('${request['id']}'),
        tenantId: Value('${request['tenantId']}'),
        schoolId: Value('${request['schoolId']}'),
        campusId: Value(request['campusId'] as String?),
        targetDeviceId: Value('${request['targetDeviceId']}'),
        reason: Value('${request['reason']}'),
        status: Value('${request['status']}'),
        requestedAt: Value(DateTime.parse('${request['requestedAt']}')),
        acknowledgedAt: Value(
          request['acknowledgedAt'] == null
              ? null
              : DateTime.parse('${request['acknowledgedAt']}'),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> ignoreSyncConflict(String conflictId) async {
    if (!_canManageSyncConflicts(_user)) {
      throw StateError('Your role cannot ignore sync conflicts.');
    }
    final user = _user;
    if (user.tenantId == null || user.schoolId == null) {
      throw StateError(
          'Ignoring sync conflicts requires tenant and school scope.');
    }
    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final conflict = await _db.getOpenSyncConflictById(
      scope: scope,
      conflictId: conflictId,
    );
    if (conflict == null) {
      return;
    }
    await _db.ignoreSyncConflict(
      scope: scope,
      conflictId: conflictId,
    );
    await _queueAndFlushOperatorAuditEvent(
      'sync_conflict_ignored',
      actor: _backupActor('sync_conflict_ignore'),
      metadata: {
        'conflictId': conflict.id,
        'entityType': conflict.entityType,
        'entityId': conflict.entityId,
        'operation': conflict.operation,
        'conflictType': conflict.conflictType,
        'queueItemId': conflict.queueItemId,
      },
    );
  }

  Future<void> requeueSyncConflict(String conflictId) async {
    if (!_canManageSyncConflicts(_user)) {
      throw StateError('Your role cannot requeue sync conflicts.');
    }
    final user = _user;
    if (user.tenantId == null || user.schoolId == null) {
      throw StateError(
          'Requeueing sync conflicts requires tenant and school scope.');
    }
    final scope = LocalDataScope(
      tenantId: user.tenantId!,
      schoolId: user.schoolId!,
      campusId: user.campusId,
    );
    final conflict = await _db.getOpenSyncConflictById(
      scope: scope,
      conflictId: conflictId,
    );
    if (conflict == null) {
      return;
    }
    await _db.requeueSyncConflict(
      scope: scope,
      conflictId: conflictId,
    );
    await _queueAndFlushOperatorAuditEvent(
      'sync_conflict_requeued',
      actor: _backupActor('sync_conflict_requeue'),
      metadata: {
        'conflictId': conflict.id,
        'entityType': conflict.entityType,
        'entityId': conflict.entityId,
        'operation': conflict.operation,
        'conflictType': conflict.conflictType,
        'queueItemId': conflict.queueItemId,
      },
    );
  }

  Future<void> createBackupNow() => _backup.createBackup(
        actor: _backupActor('manual_operator'),
      ).then((backup) async {
        await _queueAndFlushOperatorAuditEvent(
          'backup_created',
          actor: backup.actor,
          metadata: {
            'fileName': backup.fileName,
            'reason': backup.reason,
            'schemaVersion': backup.schemaVersion,
          },
        );
      });

  Future<EncryptedBackupExportInfo> exportEncryptedBackup({
    required String password,
    String? outputDirectoryPath,
  }) =>
      _backup.exportEncryptedBackup(
        actor: _backupActor('encrypted_export'),
        password: password,
        outputDirectoryPath: outputDirectoryPath,
      ).then((exportInfo) async {
        await _queueAndFlushOperatorAuditEvent(
          'backup_export_encrypted',
          actor: _backupActor('encrypted_export'),
          metadata: {
            'fileName': exportInfo.fileName,
            'sourceBackupFileName': exportInfo.sourceBackupFileName,
            'schemaVersion': exportInfo.schemaVersion,
          },
        );
        return exportInfo;
      });

  Future<BackupValidationResult> validateEncryptedBackupPackage({
    required String filePath,
    required String password,
  }) =>
      _backup.validateEncryptedExportPackage(
        filePath: filePath,
        password: password,
      );

  Future<EncryptedBackupPackageInfo> inspectEncryptedBackupPackage({
    required String filePath,
    required String password,
  }) =>
      _backup.inspectEncryptedBackupPackage(
        filePath: filePath,
        password: password,
      );

  Future<StagedRestoreInfo> stageEncryptedRestorePackage({
    required String filePath,
    required String password,
  }) =>
      _backup.stageEncryptedRestorePackage(
        filePath: filePath,
        password: password,
        actor: _backupActor('restore_stage'),
      ).then((staged) async {
        await _queueAndFlushOperatorAuditEvent(
          'restore_package_staged',
          actor: _backupActor('restore_stage'),
          metadata: {
            'packageFileName': staged.packageInfo.fileName,
            'sourceBackupFileName': staged.packageInfo.sourceBackupFileName,
            'schemaVersion': staged.packageInfo.schemaVersion,
          },
        );
        return staged;
      });

  Future<RestoreApplyResult> applyStagedRestore(
    StagedRestoreInfo stagedRestore,
  ) async {
    await _queueAndFlushOperatorAuditEvent(
      'restore_apply_requested',
      actor: _backupActor('restore_apply'),
      metadata: {
        'packageFileName': stagedRestore.packageInfo.fileName,
        'sourceBackupFileName': stagedRestore.packageInfo.sourceBackupFileName,
        'schemaVersion': stagedRestore.packageInfo.schemaVersion,
      },
    );
    _sync.suspendForRestart();
    return _backup.applyStagedRestore(
        stagedRestore: stagedRestore,
        actor: _backupActor('restore_apply'),
      );
  }

  Future<BackupValidationResult> runRestoreDrill() =>
      _backup.runRestoreDrill(
        actor: _backupActor('restore_drill'),
      ).then((result) async {
        await _queueAndFlushOperatorAuditEvent(
          result.isValid ? 'restore_drill_passed' : 'restore_drill_failed',
          actor: _backupActor('restore_drill'),
          metadata: {
            'message': result.message,
          },
        );
        return result;
      });

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  bool _canManageSyncConflicts(AuthUser user) {
    return user.role == 'admin' || user.role == 'support_admin';
  }

  bool _canRequestReconciliation(AuthUser user) {
    return user.role == 'admin' ||
        user.role == 'support_admin' ||
        user.role == 'support_technician';
  }

  bool _canViewOperationalReportData(AuthUser user) {
    return user.role == 'admin' ||
        user.role == 'cashier' ||
        user.role == 'teacher';
  }

  BackupActorContext _backupActor(String reason) {
    final user = _user;
    if (!_canManageBackupRecovery(user)) {
      throw StateError('Your role cannot manage backup or restore operations.');
    }
    return BackupActorContext(
      reason: reason,
      userId: user.id,
      userName: user.fullName,
      tenantId: user.tenantId,
      schoolId: user.schoolId,
      campusId: user.campusId,
    );
  }

  bool _canManageBackupRecovery(AuthUser user) {
    return user.role == 'admin' ||
        user.role == 'support_admin' ||
        user.role == 'support_technician';
  }

  Future<void> _queueAndFlushOperatorAuditEvent(
    String eventType, {
    required BackupActorContext actor,
    Map<String, dynamic>? metadata,
  }) async {
    await _backup.queueOperatorAuditEvent(
      eventType: eventType,
      actor: actor,
      metadata: metadata,
    );
    await _backup.flushPendingOperatorAuditEvents(
      auth: _auth,
      sync: _sync,
    );
  }
}
