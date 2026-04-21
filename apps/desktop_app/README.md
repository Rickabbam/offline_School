# Desktop App

Flutter Windows desktop application — the primary school operations client.

## Prerequisites
- Flutter 3.19+ with Windows desktop support enabled: `flutter config --enable-windows-desktop`
- Visual Studio 2022 with "Desktop development with C++" workload

## Setup

```bash
flutter pub get
flutter run -d windows
```

## Generate Drift database code

Drift uses code generation. Run this whenever you change a table definition:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Build Windows installer (MSIX)

```bash
flutter pub run msix:create
```

Output: `build/windows/runner/Release/offline_school.msix`

## Project structure

```
lib/
├── main.dart                    # Entry point: DB init, sync start, app launch
├── database/
│   ├── app_database.dart        # Drift AppDatabase + migration strategy
│   └── tables/
│       ├── sync_queue.dart      # Local write queue for backend push
│       └── sync_state.dart      # Tracks last pulled server revision
├── sync/
│   ├── connectivity_monitor.dart  # Watches network state
│   └── sync_service.dart          # Push/pull background service
└── ui/
    └── shell/
        ├── app_shell.dart       # Main layout: sidebar + topbar + body
        ├── sidebar.dart         # Vertical navigation
        └── top_bar.dart         # Horizontal top bar with sync status
```

## Database

- **Engine:** SQLite via Drift ORM
- **File location:** `%APPDATA%\offline_school\offline_school.db` (Windows)
- **Schema version:** 1 (Phase A baseline: sync_queue + sync_state)
- **Migrations:** defined in `AppDatabase.migration`; never edit past migrations
