import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/database/app_database.dart';
import 'package:desktop_app/sync/sync_service.dart';
import 'package:mobile_app/ui/attendance/attendance_screen.dart';
import 'package:mobile_app/ui/attendance/attendance_workspace_service.dart';
import 'package:mobile_app/ui/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await db.runMigrations();

  final authService = AuthService();
  await authService.initialise();
  final syncService = SyncService(db: db, auth: authService);
  if (authService.isAuthenticated && !authService.isOfflineSession) {
    await syncService.syncNow();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<SyncService>.value(value: syncService),
        ProxyProvider<AppDatabase, AttendanceWorkspaceService>(
          update: (_, db, __) => AttendanceWorkspaceService(db),
        ),
      ],
      child: const MobileAttendanceApp(),
    ),
  );
}

class MobileAttendanceApp extends StatelessWidget {
  const MobileAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'offline_School Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D3B66),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3EFE7),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        return switch (auth.state) {
          AuthState.authenticated => AttendanceScreen(
              workspaceService: context.read<AttendanceWorkspaceService>(),
            ),
          AuthState.unauthenticated => const LoginScreen(),
          AuthState.unknown => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        };
      },
    );
  }
}
