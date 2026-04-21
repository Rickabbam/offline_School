# Desktop Installer and Updater

## Installer requirements (Windows first)
- Full offline installer package
- Includes runtime dependencies
- Initializes local SQLite DB
- Runs DB migrations
- Seeds default configuration
- Supports backup import
- Verifies printer integration baseline

## Update modes
### Online delta update
- Resumable download
- Checksum/signature verification
- Safe rollback on failure

### Offline patch update
- USB-transferable patch package
- Executable without live internet
- Migration-safe update path
