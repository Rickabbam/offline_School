import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'sync/sync_service.dart';
import 'ui/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the local SQLite database and run pending migrations.
  final db = AppDatabase();
  await db.runMigrations();

  // Start the background sync service (push/pull when online).
  final syncService = SyncService(db: db);
  syncService.start();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<SyncService>.value(value: syncService),
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
      home: const AppShell(),
    );
  }
}
