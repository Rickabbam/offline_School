# Contributing to offline_School

Thank you for contributing! Please read these rules before opening branches or pull requests.

---

## Branch naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/<short-description>` | `feat/student-profile` |
| Bug fix | `fix/<short-description>` | `fix/sync-retry-loop` |
| Chore/refactor | `chore/<short-description>` | `chore/upgrade-nestjs` |
| Docs | `docs/<short-description>` | `docs/update-roadmap` |
| Release | `release/<version>` | `release/1.0.0` |

Branch names must be lowercase and use hyphens, not underscores or spaces.

---

## Pull request rules

1. **One concern per PR.** A PR should do one thing. Don't mix feature work with refactors.
2. **Base branch is `main`.** All PRs target `main` unless they are part of a named release branch.
3. **Title format:** `<type>(<scope>): <short description>` — e.g., `feat(students): add enrollment screen`.
4. **Description must include:**
   - What this PR does (2–3 sentences).
   - How to test it locally.
   - Any migrations or environment variable changes required.
5. **All CI checks must pass** before requesting review.
6. **At least one approval** is required before merging.
7. **Squash merge** into `main`. Delete the branch after merge.

---

## Commit message format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`

---

## Workspace setup

See the root `README.md` for full setup instructions for each workspace.

---

## Code style

- **Backend (NestJS/TypeScript):** ESLint + Prettier. Run `npm run lint` and `npm run format` before pushing.
- **Desktop/Mobile (Flutter/Dart):** `flutter analyze` and `dart format .` before pushing.
- **Web (React/TypeScript):** ESLint + Prettier. Run `npm run lint` before pushing.

---

## Database migrations

- **Never** edit an existing migration file after it has been merged to `main`.
- Always create a new migration for schema changes.
- Migration file names: `<timestamp>-<kebab-description>.ts` for NestJS, numbered `.dart` files for Drift.

---

## Secrets

Never commit secrets, API keys, tokens, or credentials. Use `.env` files locally (they are gitignored). Raise a PR with only the `.env.example` key (no value) when adding new environment variables.
