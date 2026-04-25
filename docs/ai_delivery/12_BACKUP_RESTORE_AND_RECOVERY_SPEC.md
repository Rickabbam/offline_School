# BACKUP, RESTORE, AND RECOVERY SPEC

## Backup layers
1. local automatic backups
2. encrypted external exports
3. cloud recovery for already-synced records

## Restore flow
1. select backup
2. validate checksum/version
3. restore local DB
4. run migrations
5. reconcile sync state
6. identify unresolved unsynced writes
7. surface review actions
8. audit the restore

## Required implementation details
- backup manifest
- encryption metadata
- checksum/hash validation
- restore operation log
- unresolved conflict/reconciliation UI
- operator support bundle export
