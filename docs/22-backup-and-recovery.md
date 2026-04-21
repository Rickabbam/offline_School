# Backup and Recovery

## Backup layers
1. Automatic local backup (daily minimum)
2. Encrypted external backup export (USB/drive/LAN)
3. Cloud recovery for synced records

## Restore flow
1. Select backup file
2. Validate version/checksum
3. Restore DB
4. Run migrations
5. Reconcile with cloud sync state
6. Flag unresolved unsynced records for review

## Security
- Encrypted backup artifacts
- Password-protected restore packages
- Audited restore operations
