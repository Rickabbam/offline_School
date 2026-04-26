import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/backup/backup_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:desktop_app/ui/auth/login_screen.dart';
import 'package:desktop_app/ui/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the local SQLite database and run pending migrations.
  final db = AppDatabase();
  await db.runMigrations();
  final backupService = BackupService(db);
  await backupService.initialiseRecoveryState();
  try {
    await backupService.ensureDailyBackup();
  } catch (error) {
    debugPrint('Automatic backup skipped: $error');
  }

  final authService = AuthService();
  await authService.initialise();

  // Start the background sync service (push/pull when online).
  final syncService = SyncService(db: db, auth: authService);
  syncService.onConnectivityRestored = () async {
    await backupService.flushPendingOperatorAuditEvents(
      auth: authService,
      sync: syncService,
    );
    await backupService.completePendingRestoreHandoff(
      auth: authService,
      sync: syncService,
    );
  };
  await syncService.start();
  authService.addListener(() {
    unawaited(
      () async {
        await backupService.flushPendingOperatorAuditEvents(
          auth: authService,
          sync: syncService,
        );
        await backupService.completePendingRestoreHandoff(
          auth: authService,
          sync: syncService,
        );
      }(),
    );
  });
  try {
    await backupService.flushPendingOperatorAuditEvents(
      auth: authService,
      sync: syncService,
    );
    await backupService.completePendingRestoreHandoff(
      auth: authService,
      sync: syncService,
    );
  } catch (error) {
    debugPrint('Post-restore reconciliation skipped: $error');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<BackupService>.value(value: backupService),
        Provider<SyncService>.value(value: syncService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
      ],
      child: const OfflineSchoolApp(),
    ),
  );
}

class OfflineSchoolApp extends StatelessWidget {
  const OfflineSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'offline_School',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, BackupService>(
      builder: (context, auth, backup, _) {
        if (backup.restartRequired) {
          return const _RestartRequiredScreen();
        }
        if (auth.state == AuthState.authenticated &&
            backup.restoreReconciliationPending) {
          return const _RestoreReconciliationPendingScreen();
        }
        return switch (auth.state) {
          AuthState.authenticated => const AppShell(),
          AuthState.unauthenticated => const LoginScreen(),
          AuthState.unknown => const _StartupScreen(),
        };
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _RestartRequiredScreen extends StatelessWidget {
  const _RestartRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt, size: 56),
              SizedBox(height: 16),
              Text(
                'Restore Applied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'The local database has been replaced from a staged restore package. Restart the app before continuing.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreReconciliationPendingScreen extends StatelessWidget {
  const _RestoreReconciliationPendingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Restore Reconciliation Pending',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'This restored workspace is waiting for an online post-restore reconciliation before normal use continues.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
