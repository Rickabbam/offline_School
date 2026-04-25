# SYNC AND OFFLINE SPEC

## Sync model
Hybrid:
- server_revision for server ordering
- origin_device_id for source tracking
- lamport_clock for local ordering
- idempotency_key for replay safety

## Local write rule
Every local write must:
1. save durably in SQLite
2. enqueue a sync mutation in the same transaction or atomic durability boundary
3. preserve enough metadata to retry safely

## Push
- client sends mutation payload + idempotency key + origin device metadata
- server validates scope and stale-write rules
- server commits in transaction
- server returns canonical entity id and server revision
- client acknowledges and updates local state safely

## Pull
- delta by revision
- ordered ascending
- client must not overwrite entities with pending/conflicted local writes
- deferred inbound changes become durable reviewable evidence if necessary

## Conflict rules
- reference data: server wins
- mutable academic ops: base revision + lamport comparison + manual review fallback
- finance posted records: immutable, use reversal
- canonicalized natural-key records must preserve accepted local fields and queue completion

## Required reliability features
- queue compaction where safe
- durable claiming / in_progress recovery
- replay-safe receipts
- conflict log
- manual review actions
- restore reconciliation
