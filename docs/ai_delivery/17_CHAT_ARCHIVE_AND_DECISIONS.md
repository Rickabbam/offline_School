# CHAT ARCHIVE AND DECISIONS — NORMALIZED

This file archives the key control decisions established during the prompt-design discussion.

## 1. The agent was over-optimizing for micro-fixes
Earlier prompts encouraged:
- one small “next step”
- drift fix
- stop

Result:
- real progress existed
- but visible progress felt too slow
- subsystems were not being finished end-to-end

Decision:
- unit of work must be a subsystem milestone, not an isolated patch.

## 2. The agent repeated already-green subsystems
Even after subsystems were green, repeated invocations kept re-verifying and restating completion.

Decision:
- add an advance/no-op guard
- do not restate green
- move directly to the next unfinished subsystem

## 3. The agent advanced into docs/process work too early
For offlinepos examples, once code looked green it moved into SOP/checklist/branch-protection work and declared phase complete.

Decision:
- docs/process work does not count while coding work remains

## 4. Completion cannot be inferred from local checks alone
Green local checks do not imply roadmap completion.

Decision:
- completion must be validated against roadmap documents

## 5. For this school repo, the system is broader than desktop-only
The repository docs define:
- desktop
- mobile
- web
- SaaS admin
- NestJS backend
- PostgreSQL
- Redis
- multi-tenant cloud model with tenant -> school -> campus

Decision:
- the production plan must include all of these surfaces
- backend creation is mandatory, not optional
- cloud scoping is part of the intended product model

## 6. The backend exists as a skeleton, not as a full business server
Decision:
- treat backend as “present but incomplete”
- roadmap must explicitly build auth, academic, people, attendance, exams, finance, reports, backups, sync

## 7. The agent needs a stronger roadmap than the conversation itself
Decision:
- create this AI delivery pack
- make it the execution control system
- bind the agent to phase-by-phase progression

## 8. Production grade means all critical layers, not UI-only progress
Decision:
- offline-first
- sync safety
- tenant/school/campus scope
- finance immutability rules
- restore safety
- auditing
- tests
are all release-blocking.
