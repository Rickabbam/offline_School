# Step-by-Step Roadmap

Every step is numbered. Complete each step before moving to the next. When a step has sub-steps, complete them in order.

---

## Phase A — Foundation ✅ COMPLETE

The goal of Phase A is to have every developer working in the same environment with a running backend, a running desktop shell, and a working local database before any feature work starts.

### Step 1 — Set up the monorepo ✅

1. ✅ Created the root repository with the following top-level folders:
   - `apps/desktop_app/`
   - `apps/mobile_app/`
   - `apps/web_app/`
   - `apps/saas_admin/`
   - `backend/`
   - `packages/`
   - `docs/`
   - `scripts/`
   - `infra/`
2. ✅ Updated root `README.md` with workspace setup instructions.
3. ✅ Added `.gitignore` covering Flutter, Node.js, and common IDE files.
4. ✅ Added `CONTRIBUTING.md` with branch naming and pull request rules.

### Step 2 — Set up the backend skeleton ✅

1. ✅ NestJS project scaffolded inside `backend/` (`package.json`, `nest-cli.json`, `tsconfig.json`).
2. ✅ PostgreSQL connection configured via TypeORM (`src/database/database.module.ts`, `src/database/data-source.ts`).
3. ✅ Redis client configured via ioredis (`src/redis/redis.module.ts`).
4. ✅ Health-check endpoint `GET /health` added (`src/health/`).
5. ✅ Environment variable validation with `class-validator` (`src/config/env.validation.ts`).
6. ✅ Baseline migration created (`src/database/migrations/1700000000000-InitSchema.ts`).
7. ✅ Docker Compose for local PostgreSQL + Redis (`infra/docker-compose.yml`).

### Step 3 — Set up the Flutter desktop shell ✅

1. ✅ Flutter project created in `apps/desktop_app/` targeting Windows.
2. ✅ Drift + `sqlite3_flutter_libs` added to `pubspec.yaml`.
3. ✅ Local database with Drift migration strategy (`lib/database/app_database.dart`).
4. ✅ Blank main window with sidebar and top bar (`lib/ui/shell/`).
5. ⬜ Confirm the app builds and launches on Windows (run `flutter run -d windows`).

### Step 4 — Set up the sync queue baseline ✅

1. ✅ `sync_queue` table defined in `lib/database/tables/sync_queue.dart`.
2. ✅ `sync_state` table defined in `lib/database/tables/sync_state.dart`.
3. ✅ Background sync service with connectivity detection and push/pull loops (`lib/sync/sync_service.dart`, `lib/sync/connectivity_monitor.dart`).
4. ✅ Service starts in `main()` before the UI mounts — runs silently in background.

### Step 5 — Set up the Windows installer baseline ✅

1. ✅ `msix` package added and configured in `apps/desktop_app/pubspec.yaml`.
2. ✅ First-launch DB migration runs automatically via `AppDatabase.runMigrations()`.
3. ✅ Build script created at `scripts/build-installer.ps1`.
4. ⬜ Test on a clean Windows machine or VM (run `scripts\build-installer.ps1`).

### Step 6 — Developer workflow verified ✅

1. ✅ `scripts/dev-setup.sh` — installs all dependencies in one step (macOS/Linux).
2. ✅ `scripts/dev-setup.bat` — installs all dependencies in one step (Windows).
3. ⬜ Every developer runs the setup script and confirms everything starts.

---

## Phase B — Operational MVP (School Setup and People)

The goal of Phase B is to give one school the ability to configure itself and manage its students, staff, and daily attendance.

### Step 7 — Identity and access

1. Implement user authentication on the backend:
   - Email + password login with JWT.
   - Refresh token with device registration.
2. Implement offline trusted-device token support on the desktop:
   - Store a long-lived encrypted token on the local device.
   - Allow login without internet if the device is already registered.
3. Define and seed the initial roles: `admin`, `cashier`, `teacher`, `parent`, `student`, `support_technician`, `support_admin`.
4. Implement role-based route guards on the backend and screen guards on the desktop.

### Step 8 — Tenant and school setup

1. Add the backend modules for:
   - `tenants` (commercial account)
   - `schools` (institutional record)
   - `campuses` (operational unit)
2. Ensure every database query is scoped to `tenant_id` and `school_id`.
3. Add campus registration to the desktop installer flow.

### Step 9 — First-run onboarding wizard

Build the guided setup wizard inside the desktop app. Follow the 11-step sequence defined in `docs/23-onboarding-wizard.md`:

1. School profile
2. Campus setup
3. Academic year and terms
4. Classes, class arms, subjects
5. Grading scheme
6. Staff roles
7. Fee categories and structures
8. Receipt format
9. Notification settings
10. Device registration
11. First admin confirmation

The wizard must complete in under 30–45 minutes. Provide starter templates for Ghanaian school types (Basic, JHS, SHS).

### Step 10 — Students

1. Create student profile screens (create, view, edit).
2. Store students in local SQLite and queue changes for sync.
3. Implement guardian relationships (student ↔ guardian linking).
4. Implement class enrollment (assign student to class arm + academic year).
5. Add student list screen with local search.
6. Implement student status management (active, withdrawn, graduated, transferred).

### Step 11 — Staff

1. Create staff profile screens (create, view, edit).
2. Assign staff to departments, roles, and subjects.
3. Assign class teachers and subject teachers.
4. Store staff in local SQLite with sync queue support.

### Step 12 — Admissions

1. Create an applicant registration screen.
2. Implement the admission approval workflow (applicant → admitted → enrolled).
3. Record parent/guardian information during admission.
4. Allow document reference notes (physical document tracking).
5. On approval, automatically create the student record and class assignment.

### Step 13 — Attendance

1. Build the daily class attendance screen for teachers.
2. Allow marking: present, absent, late, excused.
3. Store attendance records locally with sync.
4. Build a daily attendance summary report.
5. Build a term attendance summary per student.

### Step 14 — Phase B verification

1. A school admin can log in, run the setup wizard, and configure the school in under 45 minutes.
2. A teacher can mark attendance offline.
3. All changes sync correctly to the backend when connectivity is restored.
4. Roll out to a pilot school for feedback.

---

## Phase C — Finance and Retention

The goal of Phase C is for the school to collect, record, and report on fees reliably, even offline.

### Step 15 — Fee structures

1. Build fee structure configuration screens (fee categories, items, amounts).
2. Support per-class and per-term fee variations.
3. Store fee structures in local SQLite with sync.

### Step 16 — Invoice generation

1. Auto-generate invoices per enrolled student per term on demand or in batch.
2. Invoice lifecycle: `draft → confirmed → posted`.
3. Allow cashier review before posting.

### Step 17 — Payment collection

1. Build the cashier payment entry screen.
2. Record payment against an invoice.
3. Payment lifecycle: `draft → confirmed → posted`.
4. Support payment modes: cash, mobile money (MTN MoMo, Telecel Cash), bank.
5. Posted payments are immutable. Corrections go through a reversal entry.

### Step 18 — Receipt printing

1. Generate a printable receipt on payment posting.
2. Support local printer output directly from the desktop app.
3. Support PDF export as an alternative to physical printing.

### Step 19 — Arrears tracking and reporting

1. Build an arrears report: students with outstanding balances per term.
2. Build a cashier daily collection report.
3. Build a fee collection summary per class/term.

### Step 20 — SMS payment notifications

1. Integrate an SMS gateway (start with one provider, e.g., Arkesel or mNotify for Ghana).
2. Send SMS receipt confirmation to parent on payment posting.
3. Send fee due reminders (configurable schedule).
4. SMS requires internet. Queue SMS jobs and send when connected.

### Step 21 — Phase C verification

1. Cashier can record and print receipts offline.
2. Posted records cannot be edited; reversal flow works correctly.
3. Arrears and daily collection reports are accurate.
4. SMS receipts are delivered when internet is available.

---

## Phase D — Exams, Results, and Mobility

The goal of Phase D is to complete the academic cycle and extend access to teachers and parents on mobile.

### Step 22 — Exams and assessments

1. Define exam/assessment types (end of term, mid-term, coursework).
2. Build score entry screens per class, subject, and assessment.
3. Apply the grading scheme configured in Step 9 to generate grades and remarks.
4. Lock scores after approval to prevent accidental edits.

### Step 23 — Report cards

1. Generate report cards per student per term from entered scores.
2. Print report cards directly from the desktop app.
3. Export to PDF for distribution.

### Step 24 — Class result sheets

1. Generate a class result sheet showing all students, scores, and rankings.
2. Support export to PDF and print.

### Step 25 — Flutter mobile app — teacher workflow

1. Initialise the Flutter mobile project inside `apps/mobile_app/`.
2. Implement teacher login with offline token support.
3. Build the attendance capture screen (mobile-optimised).
4. Build the marks entry screen (mobile-optimised).
5. Show school notices.
6. Sync with backend using the same sync queue model as desktop.

### Step 26 — Flutter mobile app — parent workflow

1. Allow parent login (linked to student guardian record).
2. Show fee balance and payment history.
3. Show result summary per term.
4. Show school notices and announcements.

### Step 27 — Phase D verification

1. Teachers can mark attendance and enter scores on mobile offline.
2. Report cards print correctly from desktop.
3. Parents can view balances and results on mobile.

---

## Phase E — SaaS Maturity

The goal of Phase E is to operate School OS as a commercial multi-school SaaS product.

### Step 28 — React web app

1. Initialise a React project inside `apps/web_app/`.
2. Build management dashboards: enrollment summary, attendance overview, fee collection.
3. Build reporting views: cross-term, cross-class, date-range filters.
4. This app is online-first and targets school owners, accountants, and management.

### Step 29 — Tenant management

1. Build the SaaS admin panel inside `apps/saas_admin/` (React).
2. Allow creating and managing tenant accounts.
3. Configure subscription plans and feature flags per tenant.
4. View per-tenant school/campus registrations.

### Step 30 — Billing

1. Integrate a payment provider for subscription billing.
2. Enforce subscription limits (number of students, campuses, users).
3. Handle trial periods, renewals, and plan upgrades.

### Step 31 — Support console

1. Build support technician tools:
   - View tenant health status.
   - Trigger sync reconciliation for a school.
   - Audit logs per tenant.
2. Build controlled impersonation for `support_admin` with full audit trail.

### Step 32 — Analytics and cross-campus reporting

1. Build cross-campus dashboards for school owners with multiple campuses.
2. Build platform-level analytics for internal SaaS monitoring.

### Step 33 — Phase E verification and launch

1. Onboard at least 3 paying schools.
2. Confirm billing, subscription enforcement, and tenant isolation all work correctly.
3. Run a full security review of tenant data separation.
4. Public launch.

---

## Ongoing — After Launch

These run continuously from Phase C onwards.

- **Backups**: Verify automated local backup is running on each installed device. Run quarterly restore drills.
- **Updates**: Ship online delta updates regularly. Prepare offline patch packages for schools with poor internet.
- **Support**: Track `support_technician` and `support_admin` activity logs for quality.
- **Deferred modules** (add when core is stable): Library, Hostel, Transport, Payroll, LMS/Assignments, Advanced Analytics.

---

## Summary table

| Step | Name | Phase |
|------|------|-------|
| 1 | Monorepo setup | A |
| 2 | Backend skeleton | A |
| 3 | Flutter desktop shell | A |
| 4 | Sync queue baseline | A |
| 5 | Windows installer baseline | A |
| 6 | Developer workflow verified | A |
| 7 | Identity and access | B |
| 8 | Tenant and school setup | B |
| 9 | Onboarding wizard | B |
| 10 | Students | B |
| 11 | Staff | B |
| 12 | Admissions | B |
| 13 | Attendance | B |
| 14 | Phase B verification | B |
| 15 | Fee structures | C |
| 16 | Invoice generation | C |
| 17 | Payment collection | C |
| 18 | Receipt printing | C |
| 19 | Arrears tracking and reporting | C |
| 20 | SMS payment notifications | C |
| 21 | Phase C verification | C |
| 22 | Exams and assessments | D |
| 23 | Report cards | D |
| 24 | Class result sheets | D |
| 25 | Mobile app — teacher | D |
| 26 | Mobile app — parent | D |
| 27 | Phase D verification | D |
| 28 | React web app | E |
| 29 | Tenant management | E |
| 30 | Billing | E |
| 31 | Support console | E |
| 32 | Analytics and cross-campus reporting | E |
| 33 | Verification and launch | E |
