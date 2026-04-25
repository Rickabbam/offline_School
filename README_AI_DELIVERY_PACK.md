# offline_school AI Delivery Pack

Generated: 2026-04-23

This pack is a **production-grade execution and specification layer** for the `offline_School` codebase.
It is designed to make an autonomous coding agent build the system end-to-end **without drifting**.

## What this pack assumes from the existing repo
The repository already defines:
- Flutter Desktop as the primary operations client
- Flutter Mobile for teacher/parent workflows
- React Web for management
- React SaaS admin
- NestJS backend
- PostgreSQL + Redis in cloud
- SQLite on device
- Offline-first sync as a first-class requirement

The pack below does **not replace** the existing docs under `/docs`.
It **extends and operationalizes** them.

## Recommended placement
Extract this zip into the repo root so these files land under:

- `README_AI_DELIVERY_PACK.md`
- `docs/ai_delivery/...`

## Start here
1. `docs/ai_delivery/00_MASTER_PROMPT.md`
2. `docs/ai_delivery/01_EXECUTION_SYSTEM.md`
3. `docs/ai_delivery/02_PHASED_MASTER_ROADMAP.md`
4. `docs/ai_delivery/17_CHAT_ARCHIVE_AND_DECISIONS.md`

## Source-of-truth relationship
Existing repo docs remain authoritative for original intent:
- `docs/05-roadmap.md`
- `docs/06-system-architecture.md`
- `docs/07-offline-first-strategy.md`
- `docs/08-sync-protocol.md`
- `docs/09-database-design.md`
- `docs/10-api-spec.md`
- `docs/11-security-model.md`
- `docs/12-roles-and-permissions.md`
- `docs/18-testing-strategy.md`
- `docs/22-backup-and-recovery.md`
- `docs/23-onboarding-wizard.md`

This pack translates them into:
- explicit phases
- subsystem milestones
- backend build plan
- mobile/web/admin completion plans
- agent control rules
- stop/advance logic
- release gates
