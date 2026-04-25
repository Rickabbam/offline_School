# offline_School

Offline-first school management system for Ghana schools.

> **Stack:** Flutter Desktop (Windows) · Flutter Mobile · React Web · NestJS Backend · PostgreSQL · SQLite · Redis

---

## Repository structure

```
offline_School/
├── apps/
│   ├── desktop_app/    # Flutter Windows desktop (primary operations client)
│   ├── mobile_app/     # Flutter mobile (teacher + parent workflows)
│   ├── web_app/        # React web (management dashboards)
│   └── saas_admin/     # React SaaS admin panel
├── backend/            # NestJS modular monolith API
├── packages/           # Shared Dart/TypeScript packages
├── scripts/            # Developer setup and build scripts
├── infra/              # Docker, CI, deployment configs
└── docs/               # Architecture and delivery documentation
```

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Node.js | 20 LTS | https://nodejs.org |
| npm | 10 | bundled with Node.js |
| Flutter | 3.19+ | https://flutter.dev/docs/get-started/install |
| Docker Desktop | 24+ | https://www.docker.com/products/docker-desktop |
| Git | 2.40+ | https://git-scm.com |

---

## Quick start (all workspaces)

Run the setup script once after cloning:

```bash
# macOS / Linux
bash scripts/dev-setup.sh

# Windows (PowerShell or Command Prompt)
scripts\dev-setup.bat
```

This installs all dependencies and verifies your environment.

---

## Starting individual workspaces

### Backend

```bash
cd backend
cp .env.example .env          # fill in your local PostgreSQL + Redis URLs
npm install
npm run migration:run         # run DB migrations
npm run seed:roles            # create/update the bootstrap admin user
npm run start:dev             # starts on http://localhost:3000
# health check: curl http://localhost:3000/health
```

If you stay at the repository root, use `npm --prefix backend ...` for these commands instead of `npm run ...`.

If the default admin login does not work, confirm `migration:run` and `seed:roles` were both run against the same database that `start:dev` uses.

**Requires:** PostgreSQL running on port 5432, Redis running on port 6379.
Use `docker compose up -d` from the `infra/` folder for local services.

### Desktop app

```bash
cd apps/desktop_app
flutter pub get
flutter run -d windows        # Windows only
```

### Mobile app

```bash
cd apps/mobile_app
flutter pub get
flutter run                   # Android or iOS simulator
```

### Web app

```bash
cd apps/web_app
npm install
npm run dev
```

---

## Local services (Docker)

```bash
cd infra
docker compose up -d
```

Starts PostgreSQL (port 5432) and Redis (port 6379) locally.

---

## Documentation

See `/docs` for architecture and delivery documentation, including:
- final stack and system design (`06-system-architecture.md`)
- step-by-step roadmap (`05-roadmap.md`)
- offline-first and sync model (`07-offline-first-strategy.md`, `08-sync-protocol.md`)
- deployment and installer strategy (`17-deployment-guide.md`, `17b-desktop-installer.md`)
- Ghana localisation and recovery plans (`21-ghana-localisation.md`, `22-backup-and-recovery.md`)

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for branch naming, PR rules, and code style.
