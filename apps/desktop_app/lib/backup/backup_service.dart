import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as c;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';

class BackupActorContext {
  const BackupActorContext({
    required this.reason,
    this.userId,
    this.userName,
    this.tenantId,
    this.schoolId,
    this.campusId,
  });

  final String reason;
  final String? userId;
  final String? userName;
  final String? tenantId;
  final String? schoolId;
  final String? campusId;

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'userId': userId,
        'userName': userName,
        'tenantId': tenantId,
        'schoolId': schoolId,
        'campusId': campusId,
      };
}

class LocalBackupInfo {
  const LocalBackupInfo({
    required this.filePath,
    required this.createdAt,
    required this.fileSizeBytes,
    required this.sha256,
    required this.reason,
    required this.schemaVersion,
    required this.appName,
    required this.actor,
  });

  final String filePath;
  final DateTime createdAt;
  final int fileSizeBytes;
  final String sha256;
  final String reason;
  final int schemaVersion;
  final String appName;
  final BackupActorContext actor;

  String get fileName => p.basename(filePath);
}

class BackupAuditEntry {
  const BackupAuditEntry({
    required this.timestamp,
    required this.eventType,
    required this.message,
    required this.actor,
  });

  final DateTime timestamp;
  final String eventType;
  final String message;
  final BackupActorContext actor;
}

class BackupStatus {
  const BackupStatus({
    required this.latestBackup,
    required this.backups,
    required this.auditEntries,
    required this.isHealthy,
    required this.latestValidationMessage,
    required this.latestBackupValidated,
    required this.unresolvedSyncCount,
    required this.unresolvedSyncSummary,
    required this.pendingOperatorAuditCount,
    required this.pendingOperatorAuditSummary,
  });

  final LocalBackupInfo? latestBackup;
  final List<LocalBackupInfo> backups;
  final List<BackupAuditEntry> auditEntries;
  final bool isHealthy;
  final String latestValidationMessage;
  final bool latestBackupValidated;
  final int unresolvedSyncCount;
  final List<String> unresolvedSyncSummary;
  final int pendingOperatorAuditCount;
  final List<String> pendingOperatorAuditSummary;
}

class BackupValidationResult {
  const BackupValidationResult({
    required this.isValid,
    required this.message,
  });

  final bool isValid;
  final String message;
}

class BackupScopeHint {
  const BackupScopeHint({
    this.tenantId,
    this.schoolId,
    this.campusId,
  });

  final String? tenantId;
  final String? schoolId;
  final String? campusId;
}

class EncryptedBackupExportInfo {
  const EncryptedBackupExportInfo({
    required this.filePath,
    required this.createdAt,
    required this.fileSizeBytes,
    required this.schemaVersion,
    required this.sourceBackupFileName,
  });

  final String filePath;
  final DateTime createdAt;
  final int fileSizeBytes;
  final int schemaVersion;
  final String sourceBackupFileName;

  String get fileName => p.basename(filePath);
}

class EncryptedBackupPackageInfo {
  const EncryptedBackupPackageInfo({
    required this.filePath,
    required this.createdAt,
    required this.schemaVersion,
    required this.sourceBackupFileName,
    required this.appName,
    required this.scopeHint,
  });

  final String filePath;
  final DateTime createdAt;
  final int schemaVersion;
  final String sourceBackupFileName;
  final String appName;
  final BackupScopeHint scopeHint;

  String get fileName => p.basename(filePath);
}

class StagedRestoreInfo {
  const StagedRestoreInfo({
    required this.stageDirectoryPath,
    required this.snapshotPath,
    required this.manifestPath,
    required this.packageInfo,
  });

  final String stageDirectoryPath;
  final String snapshotPath;
  final String manifestPath;
  final EncryptedBackupPackageInfo packageInfo;
}

class RestoreApplyResult {
  const RestoreApplyResult({
    required this.preRestoreBackup,
    required this.packageInfo,
    required this.restartRequired,
  });

  final LocalBackupInfo preRestoreBackup;
  final EncryptedBackupPackageInfo packageInfo;
  final bool restartRequired;
}

class PendingRestoreMarker {
  const PendingRestoreMarker({
    required this.appliedAt,
    required this.packageFileName,
    required this.tenantId,
    required this.schoolId,
    this.campusId,
  });

  final DateTime appliedAt;
  final String packageFileName;
  final String tenantId;
  final String schoolId;
  final String? campusId;
}

class PendingOperatorAuditEvent {
  const PendingOperatorAuditEvent({
    required this.idempotencyKey,
    required this.eventType,
    required this.queuedAt,
    required this.actor,
    this.metadata,
  });

  final String idempotencyKey;
  final String eventType;
  final DateTime queuedAt;
  final BackupActorContext actor;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'idempotencyKey': idempotencyKey,
        'eventType': eventType,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'actor': actor.toJson(),
        'metadata': metadata,
      };

  static PendingOperatorAuditEvent fromJson(Map<String, dynamic> json) =>
      PendingOperatorAuditEvent(
        idempotencyKey: (json['idempotencyKey'] as String?) ??
            _legacyIdempotencyKeyFor(json),
        eventType: '${json['eventType']}',
        queuedAt: DateTime.parse('${json['queuedAt']}').toLocal(),
        actor: BackupActorContext(
          reason: '${json['actor']?['reason'] ?? 'unknown'}',
          userId: json['actor']?['userId'] as String?,
          userName: json['actor']?['userName'] as String?,
          tenantId: json['actor']?['tenantId'] as String?,
          schoolId: json['actor']?['schoolId'] as String?,
          campusId: json['actor']?['campusId'] as String?,
        ),
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      );

  static String _legacyIdempotencyKeyFor(Map<String, dynamic> json) {
    final buffer = StringBuffer()
      ..write(json['eventType'] ?? '')
      ..write('|')
      ..write(json['queuedAt'] ?? '')
      ..write('|')
      ..write(json['actor']?['reason'] ?? '')
      ..write('|')
      ..write(json['actor']?['tenantId'] ?? '')
      ..write('|')
      ..write(json['actor']?['schoolId'] ?? '')
      ..write('|')
      ..write(json['actor']?['campusId'] ?? '')
      ..write('|')
      ..write(jsonEncode(json['metadata'] ?? const {}));
    return 'legacy-${sha256.convert(utf8.encode(buffer.toString())).toString().substring(0, 40)}';
  }
}

class BackupService extends ChangeNotifier {
  BackupService(this._db);

  static const Duration _minimumHealthyAge = Duration(days: 1);
  static const String _appName = 'offline_School Desktop';
  static const int _packageVersion = 1;
  static const int _pbkdf2Iterations = 150000;
  static const int _derivedKeyBits = 256;

  final AppDatabase _db;
  final c.Cipher _cipher = c.AesGcm.with256bits();
  final Random _random = Random.secure();
  bool _restartRequired = false;
  bool _restoreReconciliationPending = false;

  bool get restartRequired => _restartRequired;
  bool get restoreReconciliationPending => _restoreReconciliationPending;

  Future<void> initialiseRecoveryState() async {
    _restoreReconciliationPending =
        await _readPendingRestoreMarker() != null;
  }

  Future<void> ensureDailyBackup() async {
    final status = await getStatus();
    final latest = status.latestBackup;
    if (latest != null &&
        DateTime.now().difference(latest.createdAt) < _minimumHealthyAge) {
      return;
    }
    await createBackup(
      actor: const BackupActorContext(reason: 'automatic_daily'),
    );
  }

  Future<void> queueOperatorAuditEvent({
    required String eventType,
    required BackupActorContext actor,
    Map<String, dynamic>? metadata,
  }) async {
    final existing = await _readPendingOperatorAuditEvents();
    final next = [
      PendingOperatorAuditEvent(
        idempotencyKey: _generateOperatorAuditEventId(),
        eventType: eventType,
        queuedAt: DateTime.now(),
        actor: actor,
        metadata: metadata,
      ),
      ...existing,
    ];
    await _writePendingOperatorAuditEvents(next.take(200).toList());
  }

  Future<void> flushPendingOperatorAuditEvents({
    required AuthService auth,
    required SyncService sync,
  }) async {
    if (auth.isOfflineSession || !sync.isOnline) {
      return;
    }

    final user = auth.currentUser;
    if (user == null || user.tenantId == null || user.schoolId == null) {
      return;
    }

    final pending = await _readPendingOperatorAuditEvents();
    if (pending.isEmpty) {
      return;
    }

    final client = auth.createAuthenticatedClient();
    final remaining = <PendingOperatorAuditEvent>[];
    for (final item in pending) {
      if (item.actor.tenantId != null && item.actor.tenantId != user.tenantId) {
        remaining.add(item);
        continue;
      }
      if (item.actor.schoolId != null && item.actor.schoolId != user.schoolId) {
        remaining.add(item);
        continue;
      }
      if (item.actor.campusId != null &&
          user.campusId != null &&
          item.actor.campusId != user.campusId) {
        remaining.add(item);
        continue;
      }

      try {
        await client.post<void>(
          '/audit/operator-events',
          data: {
            'eventType': item.eventType,
            'idempotencyKey': item.idempotencyKey,
            if (item.metadata != null && item.metadata!.isNotEmpty)
              'metadata': item.metadata,
          },
        );
      } catch (_) {
        remaining.add(item);
      }
    }

    await _writePendingOperatorAuditEvents(remaining);
  }

  Future<LocalBackupInfo> createBackup({
    required BackupActorContext actor,
  }) async {
    final backupDir = await _backupDirectory();
    await backupDir.create(recursive: true);

    final timestamp = DateTime.now().toUtc();
    final stamp =
        '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
    final backupFile =
        File(p.join(backupDir.path, 'offline-school-$stamp.sqlite'));
    final manifestFile = File('${backupFile.path}.json');

    await _db.exportBackupSnapshot(backupFile.path);
    final fileBytes = await backupFile.readAsBytes();
    final fileHash = sha256.convert(fileBytes).toString();
    final fileSizeBytes = await backupFile.length();

    final manifest = {
      'appName': _appName,
      'fileName': p.basename(backupFile.path),
      'createdAt': timestamp.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'sha256': fileHash,
      'reason': actor.reason,
      'schemaVersion': _db.schemaVersion,
      'actor': actor.toJson(),
      'restoreReadiness': {
        'checksumValidated': true,
        'migrationRequiredOnRestore': true,
        'scopeHint': {
          'tenantId': actor.tenantId,
          'schoolId': actor.schoolId,
          'campusId': actor.campusId,
        },
      },
    };
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    final info = LocalBackupInfo(
      filePath: backupFile.path,
      createdAt: timestamp.toLocal(),
      fileSizeBytes: fileSizeBytes,
      sha256: fileHash,
      reason: actor.reason,
      schemaVersion: _db.schemaVersion,
      appName: _appName,
      actor: actor,
    );

    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: timestamp.toLocal(),
        eventType: 'backup_created',
        message:
            'Created ${info.fileName} (${(fileSizeBytes / 1024).toStringAsFixed(1)} KB)',
        actor: actor,
      ),
    );

    return info;
  }

  Future<BackupStatus> getStatus() async {
    final backups = await listBackups();
    final latestBackup = backups.isEmpty ? null : backups.first;
    final isHealthy = latestBackup != null &&
        DateTime.now().difference(latestBackup.createdAt) <= _minimumHealthyAge;
    final validation = latestBackup == null
        ? const BackupValidationResult(
            isValid: false,
            message: 'No backup available to validate.',
          )
        : await validateBackup(latestBackup);
    final pendingItems = await _db.getPendingQueueItems();
    final failedItems = await _db.getFailedSyncQueueItems(limit: 100);
    final openConflicts = await _db.getOpenSyncConflicts(limit: 100);
    final pendingOperatorAuditEvents = await _readPendingOperatorAuditEvents();
    final unresolvedItems = [...pendingItems, ...failedItems];
    final unresolvedConflictSummary = openConflicts
        .take(10)
        .map(
          (item) =>
              'CONFLICT ${item.entityType} ${item.operation} (${item.entityId})',
        )
        .toList(growable: false);
    final pendingOperatorAuditSummary = pendingOperatorAuditEvents
        .take(10)
        .map(
          (item) =>
              '${item.eventType} (${item.actor.campusId ?? item.actor.schoolId ?? 'unscoped'})',
        )
        .toList(growable: false);
    return BackupStatus(
      latestBackup: latestBackup,
      backups: backups,
      auditEntries: await getRecentAuditEntries(),
      isHealthy: isHealthy,
      latestValidationMessage: validation.message,
      latestBackupValidated: validation.isValid,
      unresolvedSyncCount: unresolvedItems.length + openConflicts.length,
      unresolvedSyncSummary: [
        ...unresolvedItems.take(10).map(
              (item) =>
                  '${item.status.toUpperCase()} ${item.entityType} ${item.operation} (${item.entityId})',
            ),
        ...unresolvedConflictSummary,
      ],
      pendingOperatorAuditCount: pendingOperatorAuditEvents.length,
      pendingOperatorAuditSummary: pendingOperatorAuditSummary,
    );
  }

  Future<BackupValidationResult> validateBackup(LocalBackupInfo backup) async {
    final backupFile = File(backup.filePath);
    final manifestFile = File('${backup.filePath}.json');
    if (!await backupFile.exists()) {
      return const BackupValidationResult(
        isValid: false,
        message: 'Backup file is missing.',
      );
    }
    if (!await manifestFile.exists()) {
      return const BackupValidationResult(
        isValid: false,
        message: 'Backup manifest is missing.',
      );
    }

    try {
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final expectedHash = '${manifest['sha256'] ?? ''}';
      final schemaVersion = manifest['schemaVersion'] as int? ?? 0;
      final actualHash =
          sha256.convert(await backupFile.readAsBytes()).toString();
      if (expectedHash != actualHash) {
        return const BackupValidationResult(
          isValid: false,
          message: 'Checksum mismatch detected.',
        );
      }
      if (schemaVersion > _db.schemaVersion) {
        return BackupValidationResult(
          isValid: false,
          message:
              'Backup schema $schemaVersion is newer than app schema ${_db.schemaVersion}.',
        );
      }
      return const BackupValidationResult(
        isValid: true,
        message: 'Checksum and schema compatibility look valid.',
      );
    } catch (error) {
      return BackupValidationResult(
        isValid: false,
        message: 'Backup validation failed: $error',
      );
    }
  }

  Future<BackupValidationResult> runRestoreDrill({
    required BackupActorContext actor,
  }) async {
    final status = await getStatus();
    final latestBackup = status.latestBackup;
    if (latestBackup == null) {
      const result = BackupValidationResult(
        isValid: false,
        message: 'Restore drill failed: no backup available.',
      );
      await _appendAuditEntry(
        BackupAuditEntry(
          timestamp: DateTime.now(),
          eventType: 'restore_drill_failed',
          message: result.message,
          actor: actor,
        ),
      );
      return result;
    }

    final validation = await validateBackup(latestBackup);
    final drillResult = !validation.isValid
        ? validation
        : status.unresolvedSyncCount > 0
            ? BackupValidationResult(
                isValid: false,
                message:
                    'Backup validated, but ${status.unresolvedSyncCount} unsynced local change(s) require review before restore.',
              )
            : validation;
    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: DateTime.now(),
        eventType: drillResult.isValid
            ? 'restore_drill_passed'
            : 'restore_drill_failed',
        message: '${drillResult.message} Backup: ${latestBackup.fileName}',
        actor: actor,
      ),
    );
    return drillResult;
  }

  Future<EncryptedBackupExportInfo> exportEncryptedBackup({
    required BackupActorContext actor,
    required String password,
    LocalBackupInfo? backup,
    String? outputDirectoryPath,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 8) {
      throw ArgumentError(
        'Encrypted backup exports require a password of at least 8 characters.',
      );
    }

    final sourceBackup = backup ?? await createBackup(actor: actor);
    final sourceValidation = await validateBackup(sourceBackup);
    if (!sourceValidation.isValid) {
      throw StateError(
        'Cannot export an invalid backup package: ${sourceValidation.message}',
      );
    }

    final backupBytes = await File(sourceBackup.filePath).readAsBytes();
    final manifest =
        jsonDecode(await File('${sourceBackup.filePath}.json').readAsString())
            as Map<String, dynamic>;
    final packageTimestamp = DateTime.now().toUtc();
    final envelope = await _buildEncryptedPackageEnvelope(
      password: normalizedPassword,
      packageTimestamp: packageTimestamp,
      sourceBackup: sourceBackup,
      manifest: manifest,
      backupBytes: backupBytes,
    );

    final exportDir = outputDirectoryPath == null
        ? await _encryptedExportDirectory()
        : Directory(outputDirectoryPath);
    await exportDir.create(recursive: true);
    final stamp =
        '${packageTimestamp.year}${packageTimestamp.month.toString().padLeft(2, '0')}${packageTimestamp.day.toString().padLeft(2, '0')}-${packageTimestamp.hour.toString().padLeft(2, '0')}${packageTimestamp.minute.toString().padLeft(2, '0')}${packageTimestamp.second.toString().padLeft(2, '0')}';
    final packageFile =
        File(p.join(exportDir.path, 'offline-school-export-$stamp.osbkx'));
    final encodedEnvelope = const JsonEncoder.withIndent('  ').convert(envelope);
    await packageFile.writeAsString(encodedEnvelope);

    final info = EncryptedBackupExportInfo(
      filePath: packageFile.path,
      createdAt: packageTimestamp.toLocal(),
      fileSizeBytes: await packageFile.length(),
      schemaVersion: sourceBackup.schemaVersion,
      sourceBackupFileName: sourceBackup.fileName,
    );

    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: packageTimestamp.toLocal(),
        eventType: 'backup_export_encrypted',
        message:
            'Exported ${info.fileName} from ${sourceBackup.fileName} (${(info.fileSizeBytes / 1024).toStringAsFixed(1)} KB)',
        actor: actor,
      ),
    );

    return info;
  }

  Future<BackupValidationResult> validateEncryptedExportPackage({
    required String filePath,
    required String password,
  }) async {
    final packageFile = File(filePath);
    if (!await packageFile.exists()) {
      return const BackupValidationResult(
        isValid: false,
        message: 'Encrypted backup package is missing.',
      );
    }

    try {
      final envelope = jsonDecode(await packageFile.readAsString())
          as Map<String, dynamic>;
      final decryptedPayload = await _decryptEncryptedPackageEnvelope(
        envelope: envelope,
        password: password.trim(),
      );
      final manifest =
          Map<String, dynamic>.from(decryptedPayload['manifest'] as Map);
      final backupBytes = base64Decode('${decryptedPayload['backupBytes']}');
      final expectedHash = '${manifest['sha256'] ?? ''}';
      final actualHash = sha256.convert(backupBytes).toString();
      final schemaVersion = manifest['schemaVersion'] as int? ?? 0;

      if (expectedHash != actualHash) {
        return const BackupValidationResult(
          isValid: false,
          message: 'Encrypted backup payload checksum mismatch detected.',
        );
      }
      if (schemaVersion > _db.schemaVersion) {
        return BackupValidationResult(
          isValid: false,
          message:
              'Encrypted backup schema $schemaVersion is newer than app schema ${_db.schemaVersion}.',
        );
      }

      return const BackupValidationResult(
        isValid: true,
        message:
            'Encrypted backup package password, checksum, and schema look valid.',
      );
    } catch (error) {
      return BackupValidationResult(
        isValid: false,
        message: 'Encrypted backup validation failed: $error',
      );
    }
  }

  Future<EncryptedBackupPackageInfo> inspectEncryptedBackupPackage({
    required String filePath,
    required String password,
  }) async {
    final packageFile = File(filePath);
    if (!await packageFile.exists()) {
      throw StateError('Encrypted backup package is missing.');
    }

    final envelope =
        jsonDecode(await packageFile.readAsString()) as Map<String, dynamic>;
    final decryptedPayload = await _decryptEncryptedPackageEnvelope(
      envelope: envelope,
      password: password.trim(),
    );
    final manifest =
        Map<String, dynamic>.from(decryptedPayload['manifest'] as Map);
    final restoreReadiness = Map<String, dynamic>.from(
      manifest['restoreReadiness'] as Map? ?? const {},
    );
    final scopeHintJson = Map<String, dynamic>.from(
      restoreReadiness['scopeHint'] as Map? ?? const {},
    );

    return EncryptedBackupPackageInfo(
      filePath: filePath,
      createdAt: DateTime.parse('${envelope['createdAt']}').toLocal(),
      schemaVersion: envelope['schemaVersion'] as int? ?? 0,
      sourceBackupFileName: '${envelope['sourceBackupFileName'] ?? ''}',
      appName: '${envelope['appName'] ?? _appName}',
      scopeHint: BackupScopeHint(
        tenantId: scopeHintJson['tenantId'] as String?,
        schoolId: scopeHintJson['schoolId'] as String?,
        campusId: scopeHintJson['campusId'] as String?,
      ),
    );
  }

  Future<StagedRestoreInfo> stageEncryptedRestorePackage({
    required String filePath,
    required String password,
    required BackupActorContext actor,
  }) async {
    final packageValidation = await validateEncryptedExportPackage(
      filePath: filePath,
      password: password,
    );
    if (!packageValidation.isValid) {
      throw StateError(
        'Encrypted backup package failed validation: ${packageValidation.message}',
      );
    }

    final packageInfo = await inspectEncryptedBackupPackage(
      filePath: filePath,
      password: password,
    );
    final envelope =
        jsonDecode(await File(filePath).readAsString()) as Map<String, dynamic>;
    final decryptedPayload = await _decryptEncryptedPackageEnvelope(
      envelope: envelope,
      password: password.trim(),
    );
    final manifest =
        Map<String, dynamic>.from(decryptedPayload['manifest'] as Map);
    final backupBytes = base64Decode('${decryptedPayload['backupBytes']}');

    final stageDir = await _restoreStageDirectory();
    await stageDir.create(recursive: true);
    final stageStamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final restoreDir = Directory(p.join(stageDir.path, 'restore-$stageStamp'));
    await restoreDir.create(recursive: true);

    final snapshotPath =
        p.join(restoreDir.path, packageInfo.sourceBackupFileName);
    final manifestPath = '$snapshotPath.json';
    await File(snapshotPath).writeAsBytes(backupBytes, flush: true);
    await File(manifestPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );

    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: DateTime.now(),
        eventType: 'restore_package_staged',
        message:
            'Staged ${packageInfo.fileName} for restore review (${packageInfo.scopeHint.schoolId ?? 'unscoped'}).',
        actor: actor,
      ),
    );

    return StagedRestoreInfo(
      stageDirectoryPath: restoreDir.path,
      snapshotPath: snapshotPath,
      manifestPath: manifestPath,
      packageInfo: packageInfo,
    );
  }

  Future<RestoreApplyResult> applyStagedRestore({
    required StagedRestoreInfo stagedRestore,
    required BackupActorContext actor,
  }) async {
    _assertRestoreScopeAllowed(
      packageInfo: stagedRestore.packageInfo,
      actor: actor,
    );

    final stagedValidation = await validateBackup(
      LocalBackupInfo(
        filePath: stagedRestore.snapshotPath,
        createdAt: stagedRestore.packageInfo.createdAt,
        fileSizeBytes: await File(stagedRestore.snapshotPath).length(),
        sha256: '',
        reason: 'staged_restore',
        schemaVersion: stagedRestore.packageInfo.schemaVersion,
        appName: stagedRestore.packageInfo.appName,
        actor: actor,
      ),
    );
    if (!stagedValidation.isValid) {
      throw StateError(
        'Staged restore snapshot failed validation: ${stagedValidation.message}',
      );
    }

    final status = await getStatus();
    if (status.unresolvedSyncCount > 0) {
      throw StateError(
        'Restore is blocked because ${status.unresolvedSyncCount} unresolved local change(s) still exist.',
      );
    }

    final preRestoreBackup = await createBackup(
      actor: BackupActorContext(
        reason: 'pre_restore_safety_net',
        userId: actor.userId,
        userName: actor.userName,
        tenantId: actor.tenantId,
        schoolId: actor.schoolId,
        campusId: actor.campusId,
      ),
    );

    await _db.replaceFromBackupSnapshot(stagedRestore.snapshotPath);
    await _writePendingRestoreMarker(
      PendingRestoreMarker(
        appliedAt: DateTime.now().toUtc(),
        packageFileName: stagedRestore.packageInfo.fileName,
        tenantId: actor.tenantId!,
        schoolId: actor.schoolId!,
        campusId: actor.campusId,
      ),
    );
    _restartRequired = true;
    _restoreReconciliationPending = true;
    notifyListeners();
    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: DateTime.now(),
        eventType: 'restore_applied',
        message:
            'Applied restore package ${stagedRestore.packageInfo.fileName}; app restart required before continued use.',
        actor: actor,
      ),
    );

    return RestoreApplyResult(
      preRestoreBackup: preRestoreBackup,
      packageInfo: stagedRestore.packageInfo,
      restartRequired: true,
    );
  }

  Future<bool> completePendingRestoreHandoff({
    required AuthService auth,
    required SyncService sync,
  }) async {
    final marker = await _readPendingRestoreMarker();
    if (marker == null) {
      _restoreReconciliationPending = false;
      return false;
    }

    final user = auth.currentUser;
    if (user == null ||
        user.tenantId == null ||
        user.schoolId == null ||
        auth.isOfflineSession ||
        !sync.isOnline) {
      _restoreReconciliationPending = true;
      notifyListeners();
      return false;
    }
    if (user.tenantId != marker.tenantId || user.schoolId != marker.schoolId) {
      _restoreReconciliationPending = true;
      notifyListeners();
      return false;
    }
    if (marker.campusId != null &&
        user.campusId != null &&
        user.campusId != marker.campusId) {
      _restoreReconciliationPending = true;
      notifyListeners();
      return false;
    }

    await sync.syncNow();
    await _appendAuditEntry(
      BackupAuditEntry(
        timestamp: DateTime.now(),
        eventType: 'restore_reconciliation_completed',
        message:
            'Completed post-restore reconciliation for ${marker.packageFileName}.',
        actor: BackupActorContext(
          reason: 'restore_reconciliation',
          userId: user.id,
          userName: user.fullName,
          tenantId: user.tenantId,
          schoolId: user.schoolId,
          campusId: user.campusId,
        ),
      ),
    );
    await queueOperatorAuditEvent(
      eventType: 'restore_reconciliation_completed',
      actor: BackupActorContext(
        reason: 'restore_reconciliation',
        userId: user.id,
        userName: user.fullName,
        tenantId: user.tenantId,
        schoolId: user.schoolId,
        campusId: user.campusId,
      ),
      metadata: {
        'packageFileName': marker.packageFileName,
      },
    );
    await flushPendingOperatorAuditEvents(
      auth: auth,
      sync: sync,
    );
    await _clearPendingRestoreMarker();
    _restartRequired = false;
    _restoreReconciliationPending = false;
    notifyListeners();
    return true;
  }

  Future<List<LocalBackupInfo>> listBackups() async {
    final backupDir = await _backupDirectory();
    if (!await backupDir.exists()) {
      return const [];
    }

    final manifests = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final backups = <LocalBackupInfo>[];
    for (final manifestFile in manifests) {
      try {
        final manifest = jsonDecode(await manifestFile.readAsString())
            as Map<String, dynamic>;
        final fileName = manifest['fileName'] as String?;
        if (fileName == null) {
          continue;
        }
        final backupFile = File(p.join(backupDir.path, fileName));
        if (!await backupFile.exists()) {
          continue;
        }
        final actorJson =
            manifest['actor'] as Map<String, dynamic>? ?? const {};
        backups.add(
          LocalBackupInfo(
            filePath: backupFile.path,
            createdAt: DateTime.parse('${manifest['createdAt']}').toLocal(),
            fileSizeBytes: manifest['fileSizeBytes'] as int? ?? 0,
            sha256: '${manifest['sha256']}',
            reason: '${manifest['reason'] ?? 'unknown'}',
            schemaVersion: manifest['schemaVersion'] as int? ?? 0,
            appName: '${manifest['appName'] ?? _appName}',
            actor: BackupActorContext(
              reason:
                  '${actorJson['reason'] ?? manifest['reason'] ?? 'unknown'}',
              userId: actorJson['userId'] as String?,
              userName: actorJson['userName'] as String?,
              tenantId: actorJson['tenantId'] as String?,
              schoolId: actorJson['schoolId'] as String?,
              campusId: actorJson['campusId'] as String?,
            ),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<List<BackupAuditEntry>> getRecentAuditEntries({int limit = 12}) async {
    final auditFile = await _auditFile();
    if (!await auditFile.exists()) {
      return const [];
    }

    try {
      final raw = jsonDecode(await auditFile.readAsString()) as List<dynamic>;
      final items = raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => BackupAuditEntry(
              timestamp: DateTime.parse('${item['timestamp']}').toLocal(),
              eventType: '${item['eventType']}',
              message: '${item['message']}',
              actor: BackupActorContext(
                reason: '${item['actor']?['reason'] ?? 'unknown'}',
                userId: item['actor']?['userId'] as String?,
                userName: item['actor']?['userName'] as String?,
                tenantId: item['actor']?['tenantId'] as String?,
                schoolId: item['actor']?['schoolId'] as String?,
                campusId: item['actor']?['campusId'] as String?,
              ),
            ),
          )
          .toList(growable: false);
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendAuditEntry(BackupAuditEntry entry) async {
    final auditFile = await _auditFile();
    await auditFile.parent.create(recursive: true);

    final existing = await getRecentAuditEntries(limit: 200);
    final updated = [
      {
        'timestamp': entry.timestamp.toUtc().toIso8601String(),
        'eventType': entry.eventType,
        'message': entry.message,
        'actor': entry.actor.toJson(),
      },
      ...existing.map(
        (item) => {
          'timestamp': item.timestamp.toUtc().toIso8601String(),
          'eventType': item.eventType,
          'message': item.message,
          'actor': item.actor.toJson(),
        },
      ),
    ];

    await auditFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(updated.take(200).toList()),
    );
  }

  Future<Directory> _backupDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'backups'));
  }

  Future<File> _auditFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'backups', 'backup-audit.json'));
  }

  Future<File> _pendingRestoreMarkerFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'backups', 'pending-restore.json'));
  }

  Future<File> _operatorAuditOutboxFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'backups', 'operator-audit-outbox.json'));
  }

  Future<Directory> _restoreStageDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'backups', 'restore-staging'));
  }

  void _assertRestoreScopeAllowed({
    required EncryptedBackupPackageInfo packageInfo,
    required BackupActorContext actor,
  }) {
    if (actor.tenantId == null || actor.schoolId == null) {
      throw StateError('Restore requires tenant and school scope.');
    }

    final packageTenantId = packageInfo.scopeHint.tenantId;
    final packageSchoolId = packageInfo.scopeHint.schoolId;
    final packageCampusId = packageInfo.scopeHint.campusId;

    if (packageTenantId != null && packageTenantId != actor.tenantId) {
      throw StateError(
        'Restore package tenant scope does not match this device.',
      );
    }
    if (packageSchoolId != null && packageSchoolId != actor.schoolId) {
      throw StateError(
        'Restore package school scope does not match this device.',
      );
    }
    if (actor.campusId != null &&
        actor.campusId!.isNotEmpty &&
        packageCampusId != null &&
        packageCampusId != actor.campusId) {
      throw StateError(
        'Restore package campus scope does not match this device.',
      );
    }
  }

  Future<Map<String, dynamic>> _buildEncryptedPackageEnvelope({
    required String password,
    required DateTime packageTimestamp,
    required LocalBackupInfo sourceBackup,
    required Map<String, dynamic> manifest,
    required Uint8List backupBytes,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveSecretKey(password: password, salt: salt);
    final payloadBytes = utf8.encode(
      jsonEncode({
        'manifest': manifest,
        'backupBytes': base64Encode(backupBytes),
      }),
    );
    final encrypted = await _cipher.encrypt(
      payloadBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'packageVersion': _packageVersion,
      'appName': _appName,
      'createdAt': packageTimestamp.toIso8601String(),
      'sourceBackupFileName': sourceBackup.fileName,
      'schemaVersion': sourceBackup.schemaVersion,
      'kdf': {
        'algorithm': 'pbkdf2_hmac_sha256',
        'iterations': _pbkdf2Iterations,
        'derivedKeyBits': _derivedKeyBits,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': 'aes_256_gcm',
        'nonce': base64Encode(encrypted.nonce),
        'ciphertext': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      },
    };
  }

  Future<Map<String, dynamic>> _decryptEncryptedPackageEnvelope({
    required Map<String, dynamic> envelope,
    required String password,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 8) {
      throw ArgumentError(
        'Encrypted backup exports require a password of at least 8 characters.',
      );
    }
    if ((envelope['packageVersion'] as int? ?? 0) != _packageVersion) {
      throw StateError('Unsupported encrypted backup package version.');
    }

    final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);
    final cipher = Map<String, dynamic>.from(envelope['cipher'] as Map);
    final secretKey = await _deriveSecretKey(
      password: normalizedPassword,
      salt: base64Decode('${kdf['salt']}'),
    );
    final box = c.SecretBox(
      base64Decode('${cipher['ciphertext']}'),
      nonce: base64Decode('${cipher['nonce']}'),
      mac: c.Mac(base64Decode('${cipher['mac']}')),
    );
    final clearBytes = await _cipher.decrypt(box, secretKey: secretKey);
    return jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
  }

  Future<c.SecretKey> _deriveSecretKey({
    required String password,
    required List<int> salt,
  }) {
    final pbkdf2 = c.Pbkdf2(
      macAlgorithm: c.Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: _derivedKeyBits,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var index = 0; index < length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return bytes;
  }

  String _generateOperatorAuditEventId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(16);
    final randomBytes = _randomBytes(8);
    final randomHex = randomBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'operator-audit-$millis-$randomHex';
  }

  Future<Directory> _encryptedExportDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'backups', 'exports'));
  }

  Future<void> _writePendingRestoreMarker(PendingRestoreMarker marker) async {
    final file = await _pendingRestoreMarkerFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'appliedAt': marker.appliedAt.toIso8601String(),
        'packageFileName': marker.packageFileName,
        'tenantId': marker.tenantId,
        'schoolId': marker.schoolId,
        'campusId': marker.campusId,
      }),
      flush: true,
    );
  }

  Future<PendingRestoreMarker?> _readPendingRestoreMarker() async {
    final file = await _pendingRestoreMarkerFile();
    if (!await file.exists()) {
      return null;
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return PendingRestoreMarker(
        appliedAt: DateTime.parse('${json['appliedAt']}').toLocal(),
        packageFileName: '${json['packageFileName']}',
        tenantId: '${json['tenantId']}',
        schoolId: '${json['schoolId']}',
        campusId: json['campusId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingRestoreMarker() async {
    final file = await _pendingRestoreMarkerFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<PendingOperatorAuditEvent>> _readPendingOperatorAuditEvents() async {
    final file = await _operatorAuditOutboxFile();
    if (!await file.exists()) {
      return const [];
    }

    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .map((item) => PendingOperatorAuditEvent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writePendingOperatorAuditEvents(
    List<PendingOperatorAuditEvent> items,
  ) async {
    final file = await _operatorAuditOutboxFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert(items.map((item) => item.toJson()).toList(growable: false)),
      flush: true,
    );
  }
}
