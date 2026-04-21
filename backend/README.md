# Backend

NestJS modular monolith API for offline_School.

## Stack
- **Framework:** NestJS 10
- **Database:** PostgreSQL 16 via TypeORM
- **Queue/Cache:** Redis 7 via ioredis
- **Language:** TypeScript 5

## Setup

```bash
cp .env.example .env
# Edit .env with your local values (or use defaults with docker-compose)

npm install
npm run migration:run
npm run seed:roles
npm run start:dev
```

## Health check

```
GET http://localhost:3000/health
```

Returns `200 OK` with status of database, redis, and memory heap.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run start:dev` | Start with hot-reload |
| `npm run build` | Compile to `dist/` |
| `npm run start:prod` | Run compiled output |
| `npm run test` | Unit tests |
| `npm run test:e2e` | End-to-end tests |
| `npm run lint` | ESLint |
| `npm run format` | Prettier |
| `npm run migration:generate` | Generate a new migration from entity changes |
| `npm run migration:run` | Run all pending migrations |
| `npm run migration:revert` | Revert last migration |
| `npm run seed:roles` | Bootstrap the default admin user and list supported roles |

## Module structure

```
src/
├── config/           # Environment validation
├── database/         # TypeORM module + migrations
│   └── migrations/   # All migration files
├── health/           # GET /health endpoint
├── redis/            # Redis client module (global)
├── app.module.ts
└── main.ts
```

## Environment variables

Copy `.env.example` to `.env` and fill in the values.

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment | `development` |
| `PORT` | HTTP port | `3000` |
| `DATABASE_HOST` | PostgreSQL host | `localhost` |
| `DATABASE_PORT` | PostgreSQL port | `5432` |
| `DATABASE_NAME` | Database name | `offline_school` |
| `DATABASE_USER` | Database user | `postgres` |
| `DATABASE_PASSWORD` | Database password | `postgres` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `JWT_SECRET` | Signing secret for access and refresh tokens | none |

`seed:roles` uses these optional variables when creating the bootstrap admin:

| Variable | Description | Default |
|----------|-------------|---------|
| `DEFAULT_ADMIN_EMAIL` | Admin login email | `admin@offline-school.local` |
| `DEFAULT_ADMIN_PASSWORD` | Admin password | `ChangeMe123!` |
| `DEFAULT_ADMIN_FULL_NAME` | Admin display name | `Offline School Admin` |
