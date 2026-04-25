# DATA MIGRATIONS AND VERSIONING

## Local SQLite
- every schema change requires migration strategy
- data preservation required
- startup migration must not corrupt queue/conflict state

## Cloud PostgreSQL
- every entity change requires migration
- partial rollout safety required
- backfills must be explicit for revisions / scopes / natural keys

## Versioning
- backup artifacts must include schema/app version
- restore must validate compatibility
- sync protocol version should be explicit if breaking changes are introduced
