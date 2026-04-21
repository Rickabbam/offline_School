# Sync Protocol

## Sync model
Hybrid model:
- `server_revision` for global server ordering and delta pulls
- `origin_device_id` to track source device
- `lamport_clock` for local write ordering/conflict comparison
- optional `entity_version` for user-facing history

## Per-record metadata
- `id`
- `tenant_id`
- `school_id`
- `server_revision`
- `origin_device_id`
- `lamport_clock`
- `updated_at`
- `deleted`
- `sync_status`

## Local queue schema
- `id`
- `entity_type`
- `entity_id`
- `operation` (create/update/delete)
- `payload_json`
- `status`
- `retry_count`
- `idempotency_key`
- `created_at`

## Sync flow
1. Save locally in SQLite
2. Create queue item
3. Push queue items when online
4. Server validates idempotency and commits
5. Server assigns new revision
6. Client updates local state and pulls later deltas

## Conflict rules
- Academic editable records: compare `server_revision`, then `lamport_clock`, then role-based merge rules; unresolved conflicts go to manual review queue.
- System reference data: server wins.
- Finance: posted records are immutable; corrections are reversal entries (not overwrite merges).
