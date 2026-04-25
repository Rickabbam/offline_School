# EXECUTION SYSTEM — HOW THE AGENT MUST OPERATE

## Unit of work
The unit of work is a **documented coding subsystem milestone**, not a bug fix.

## Selection order
At every turn:
1. Identify the earliest unfinished phase from `02_PHASED_MASTER_ROADMAP.md`.
2. Within that phase, identify the earliest unfinished subsystem.
3. If the current subsystem is already green, advance immediately.
4. If all subsystems in the phase are green, advance to the next phase in the same response cycle.

## Mandatory start-of-response procedure
1. State current phase and subsystem.
2. Quote/paraphrase the subsystem definition of done from the roadmap.
3. Run drift check only for relevant areas:
   - schema
   - interfaces
   - backend/client contracts
   - offline guarantees
   - tenant/school/campus isolation
   - rollback/idempotency coverage
4. List only blocking or integrity-relevant gaps.
5. Fix those gaps before new implementation.

## Delivery loop
Repeat until subsystem is complete:
1. Implement next logical code increment.
2. Run checks:
   - Build/types
   - Contracts
   - Offline-first
   - Tenant boundary
   - Data integrity
   - Phase/subsystem output
3. If any RED:
   - fix immediately
   - re-run checks
   - do not advance
4. If all GREEN and blocking work remains:
   - continue inside same subsystem
5. If all GREEN and no blocking work remains:
   - mark subsystem complete
   - move immediately to next unfinished subsystem

## Advance guard
If the current subsystem is already GREEN from the previous run:
- do not re-run it
- advance directly to the next unfinished subsystem

Only emit `NO-OP: product coding complete` if:
- every coding subsystem in every phase is complete
- no blocking drift remains anywhere relevant

## Explicit restrictions
- No docs/process-only turns while coding work remains
- No verification-only narration after a subsystem is already green
- No “phase complete” unless the roadmap phase has zero unfinished coding items
- No “backend complete” while only a skeleton exists
- No “sync complete” while conflict resolution, retries, receipts, or restore handling remain partial

## Required response format
For each subsystem worked in the response:

1. Phase: [name]
2. Subsystem: [name]
3. Definition of done: [one line]
4. Drift check:
   - [blocking gaps only, or none]
5. Fixes applied:
   - [only pre-implementation fixes, or none]
6. Increment:
   - [code/changes only]
7. Check results:
   - Build/types: GREEN/RED
   - Contracts: GREEN/RED
   - Offline-first: GREEN/RED
   - Tenant boundary: GREEN/RED
   - Data integrity: GREEN/RED
   - Roadmap output: GREEN/RED
8. Next:
   - [next subsystem]
   - or [phase complete — advancing to: X]
   - or [NO-OP: product coding complete]
