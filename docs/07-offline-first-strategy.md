# Offline-First Strategy

## Offline principles
- Core school operations must continue without internet.
- Every local write is durable and queued for sync.
- Users see sync status clearly and can resolve conflicts.

## Must work offline
- Trusted-device login
- Admissions and student records entry
- Attendance and marks entry
- Payment recording and receipt printing
- Local search and report generation

## Online-required operations
- First-time authentication
- Subscription validation
- SMS sending and push notifications
- Cloud backup restore and remote support

## Backup policy
- Automatic local SQLite backups (daily minimum, configurable frequency)
- Encrypted external backup exports (USB/drive/LAN)
- Cloud sync as supplemental recovery for already-synced data

## Restore and unsynced recovery expectations
- Restore validates backup version and checksum
- Migration runner executes before app becomes operational
- Sync reconciliation detects unsynced local writes
- Potential unsynced conflict sets are flagged for review
