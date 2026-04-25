# TEST STRATEGY — EXPANDED

## Required test layers
1. unit tests
2. service/repository tests
3. offline persistence tests
4. sync replay/conflict tests
5. integration tests (backend + DB)
6. restore/recovery tests
7. role/scope tests
8. finance integrity tests
9. installer/upgrade tests
10. performance tests on large queues / low-end hardware

## Mandatory scenarios
- no internet startup
- trusted-device offline login
- queue retries and poison mutations
- stale writes
- canonical id remapping
- restore after unsynced local work
- finance post/reverse invariants
- role leakage attempts
