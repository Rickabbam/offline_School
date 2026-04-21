# System Architecture

## Final stack decisions
- Desktop app: **Flutter Desktop** (Windows first)
- Mobile app: **Flutter Mobile**
- Web app: **React**
- Backend: **NestJS** (modular monolith)
- Local DB: **SQLite**
- Cloud DB: **PostgreSQL**
- Queue/cache/jobs: **Redis**

## Architecture overview
- Desktop is the primary school operations client.
- Mobile supports teacher/parent workflows.
- React web supports management, onboarding, reporting, and SaaS admin.
- NestJS backend exposes auth, business, reporting, and sync APIs.

## Data and tenancy boundaries
- Multi-tenant cloud model: tenant -> school -> campus
- **One SQLite database per campus device installation**
- Desktop installs are registered to one active campus
- Cross-campus access is authorized online and constrained by permissions

## Operating model
- Local-first writes on SQLite
- Sync queue pushes to backend when connected
- Delta pull updates local state from server revisions
