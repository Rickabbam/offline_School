# PHASED MASTER ROADMAP — PRODUCTION BUILD ORDER

This file expands the repository roadmap into a full end-to-end production build order.

---

# PHASE 0 — CONTROL, TRUTH, AND REPO SHAPE
## Goal
Establish execution discipline so the AI cannot drift.

## Subsystems
### 0.1 Source-of-truth enforcement
Done when:
- agent follows repo docs + `docs/ai_delivery/*`
- subsystem/phase advance logic is working
- no docs/process work occurs while coding work remains

### 0.2 Monorepo truth pass
Done when:
- repo layout matches documented apps/backend/packages/infra
- readmes and setup commands reflect actual codebase
- missing placeholders are identified

---

# PHASE 1 — FOUNDATION HARDENING
## Goal
Make the baseline architecture reliable enough for full feature work.

## Subsystems
### 1.1 Backend skeleton hardening
Done when:
- NestJS app boots cleanly
- config validation works
- TypeORM migrations run
- PostgreSQL and Redis health checks pass
- module boundaries exist for future domains

### 1.2 Desktop shell + local DB hardening
Done when:
- desktop app builds and launches
- Drift migrations are stable
- sync service starts safely
- trusted-device and auth storage have safe fallbacks

### 1.3 Shared conventions
Done when:
- IDs, timestamps, revision semantics, and error envelopes are standardized
- package/module boundaries are explicit

---

# PHASE 2 — IDENTITY, ACCESS, AND DEVICE TRUST
## Goal
Make authentication, authorization, and trusted-device behavior production safe.

## Subsystems
### 2.1 Auth model and token lifecycle
Done when:
- login, refresh, logout, offline token redemption, and session recovery are fully defined and implemented
- device-bound token behavior is enforced

### 2.2 Role and permission enforcement
Done when:
- server-side RBAC exists for all documented roles
- client-side visibility is advisory only and consistent
- role leakage paths are closed

### 2.3 Device trust and revocation
Done when:
- workstation/device registration is scoped and audited
- current-device revoke works
- admin/support revoke works
- stale/fingerprint-mismatch cases are blocked

---

# PHASE 3 — TENANT / SCHOOL / CAMPUS DOMAIN FOUNDATIONS
## Goal
Make the multi-tenant cloud model and per-campus device model real.

## Subsystems
### 3.1 Tenant / school / campus entities
Done when:
- cloud entities exist with migrations, APIs, services, and client caches
- every read/write path is scoped to tenant/school/campus as documented

### 3.2 Workspace cache and bootstrap
Done when:
- school and campus metadata are durable locally
- onboarding/bootstrap seeds local cache and sync cursors correctly
- offline startup uses real workspace identity, not placeholders

### 3.3 SaaS admin baseline
Done when:
- SaaS admin surface can list tenants, schools, and status
- no operational school data leaks into platform-only views

---

# PHASE 4 — ACADEMIC CONFIGURATION
## Goal
Make a school operational through structure and academic setup.

## Subsystems
### 4.1 Onboarding wizard completion
Done when all 11 first-run steps are fully wired:
- school profile
- campus setup
- academic year + terms
- classes/arms/subjects
- grading scheme
- staff roles
- fee categories / fee setup
- receipt format
- notifications
- device registration
- first admin confirmation

### 4.2 Academic reference data sync
Done when:
- years, terms, class levels, class arms, subjects, grading schemes sync correctly
- offline cache and server revisions are reliable
- stale-write and replay rules hold

---

# PHASE 5 — PEOPLE LIFECYCLE
## Goal
Support admissions, students, guardians, staff, and enrollment end-to-end.

## Subsystems
### 5.1 Admissions
Done when:
- applicants can be created/edited offline
- admissions decisions sync
- applicant-to-student enrollment is atomic and replay-safe

### 5.2 Students and guardians
Done when:
- student CRUD works offline and online
- guardian links are safe and scoped
- enrollment natural-key reconciliation holds

### 5.3 Staff
Done when:
- staff CRUD works offline and online
- teaching assignments are scoped and conflict-safe

---

# PHASE 6 — ATTENDANCE
## Goal
Make attendance capture reliable offline across staff/mobile/desktop flows.

## Subsystems
### 6.1 Attendance data model + server
Done when:
- attendance entities, APIs, sync, and revisions are complete

### 6.2 Attendance desktop workspace
Done when:
- capture/edit works offline
- base revision conflict detection works
- pull does not overwrite pending local changes

### 6.3 Mobile attendance capture
Done when:
- teacher mobile attendance works offline
- sync queue and conflict behavior match desktop rules where applicable

---

# PHASE 7 — EXAMS, SCORES, RESULTS, REPORT CARDS
## Goal
Support academic outcomes end-to-end.

## Subsystems
### 7.1 Assessments and exam structures
### 7.2 Score entry and moderation
### 7.3 Result computation
### 7.4 Report card generation
Done when:
- marks entry works offline where required
- grade calculations are deterministic
- moderation/history/audit exists where required
- report cards generate accurately

---

# PHASE 8 — FINANCE
## Goal
Ship a production-safe finance lifecycle.

## Subsystems
### 8.1 Fee categories, structures, invoices
### 8.2 Payments and receipts
### 8.3 Posting lifecycle
### 8.4 Reversals and arrears
### 8.5 Finance reporting
Done when:
- draft → confirmed → posted → reversed lifecycle is enforced
- posted records are immutable
- reversals are additive and audited
- offline payment recording is safe
- receipt printing is reliable
- arrears and finance reports are trustworthy

---

# PHASE 9 — REPORTS AND OPERATIONAL INSIGHT
## Goal
Provide usable school and admin reporting.

## Subsystems
### 9.1 Desktop reports workspace
### 9.2 Web management dashboards
### 9.3 Export pipelines
Done when:
- operational summaries are real
- sync conflict / queue / backup status is visible
- school reports and exports are aligned with permissions

---

# PHASE 10 — BACKUP, RESTORE, AND RECOVERY
## Goal
Make catastrophic recovery safe and operator-usable.

## Subsystems
### 10.1 Local backup engine
### 10.2 Encrypted external exports
### 10.3 Restore validation + migrations
### 10.4 Unsynced record reconciliation
### 10.5 Recovery operator workflows
Done when:
- backup/restore follows documented flow
- version/checksum validation works
- unresolved unsynced writes are safely flagged and reviewable
- restore operations are audited

---

# PHASE 11 — WEB ADMIN + SAAS ADMIN COMPLETION
## Goal
Complete online administration surfaces.

## Subsystems
### 11.1 Web admin school management
### 11.2 Web reporting and settings
### 11.3 SaaS admin tenant operations
### 11.4 Controlled impersonation + support
Done when:
- web and SaaS admin surfaces align with roles and scoping
- support/admin actions are fully audited

---

# PHASE 12 — MOBILE EXPERIENCES
## Goal
Deliver teacher and parent mobile capabilities.

## Subsystems
### 12.1 Teacher mobile workflows
### 12.2 Parent mobile workflows
### 12.3 Notifications and delivery status
Done when:
- mobile has a scoped offline-capable subset where needed
- online-required behavior is explicit and safe

---

# PHASE 13 — HARDENING, OBSERVABILITY, AND RELEASE
## Goal
Make the system production-ready.

## Subsystems
### 13.1 Audit and observability
### 13.2 Performance + large-data testing
### 13.3 Installer and upgrade validation
### 13.4 Pilot validation + truth pass
### 13.5 Release gates
Done when:
- operational logging is sufficient
- low-end hardware and queue pressure scenarios are tested
- installer + upgrades work
- pilot validation is real
- release checklist is enforceable
