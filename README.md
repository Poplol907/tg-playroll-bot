# Cosmo Studio

## Project

Cosmo Studio is a music-studio management application with a Flutter client and a FastAPI backend.

## Problem

Small studios need one place to manage people, lessons, rooms, rates, payouts, and salary reporting without relying on disconnected spreadsheets and messages.

## Solution

The application provides role-aware operational workflows backed by an API and PostgreSQL database.

## Features

- Authentication and organization-aware user management.
- Student, teacher, lesson, room, and schedule management.
- Rates, payouts, salary calculations, and reports.
- Native Flutter interfaces for supported desktop and mobile targets.

## Screenshots

Screenshots will be added before the public product release.

## Stack

- Flutter/Dart with Riverpod and GoRouter.
- FastAPI and SQLAlchemy async.
- PostgreSQL, Docker Compose, and Caddy.
- Pytest and Flutter test tooling.

## Architecture

`mobile/` contains the Flutter client. `backend/` contains the FastAPI application, routers, services, and tests. `migrations/` contains ordered database migrations. Docker Compose provides a local PostgreSQL service; production deployment configuration remains separate in `docker-compose.prod.yml`.

## Setup

1. Install Python 3.12+, Flutter, and Docker Compose.
2. Create a virtual environment and install dependencies:

   ```sh
   python -m venv .venv
   .venv/bin/python -m pip install -r requirements.txt -r requirements-dev.txt
   ```

3. Set local environment variables, including `JWT_SECRET` and `POSTGRES_PASSWORD`.
4. Start the local database with `docker compose up -d db`.
5. Run the backend and Flutter client using their respective development workflows.

## Database migrations and pre-deploy

Migrations are ordered files in `migrations/`. Apply only migrations that the target database has not already received, one at a time and in numeric order; do not run a blind glob over an unknown production database.

Before any production migration:

1. Schedule a maintenance window, record the target revision, and take a backup that has been verified restorable. Keep backup artifacts outside the repository.
2. Restore that backup to staging and rehearse the same pending migrations there.
3. For migration 008, preflight global login uniqueness:

   ```sh
   psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -c \
     'SELECT login, COUNT(*) FROM users GROUP BY login HAVING COUNT(*) > 1;'
   ```

4. If the preflight returns any duplicate login, or migration 008 raises its duplicate-login error, STOP. Do not auto-delete or merge accounts. Report the duplicate logins and their organization/account context to the owner, agree on explicit corrections, take a fresh backup, and rerun the preflight.
5. When the preflight is empty, apply 008 with this exact command:

   ```sh
   psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -f migrations/008_global_user_login.sql
   ```

6. Confirm the command succeeds, record the applied revision, and verify the expected constraint before resuming application traffic.

## Environment variables

Use `.env.prod.example` as the production configuration template; do not commit a populated `.env` file. Important values include `DATABASE_URL`, `JWT_SECRET`, `ALLOWED_ORIGINS`, `DEV_MODE`, and the organization bootstrap settings. Local Compose also requires `POSTGRES_PASSWORD`; `POSTGRES_DB` and `POSTGRES_USER` have local defaults.

## Security and privacy

Secrets, signing material, databases, logs, and coverage artifacts are intentionally excluded from version control. Release Android builds require an ignored local `mobile/android/key.properties`; no keystore is included. The app requires an explicit JWT secret, stores client tokens in platform secure storage, and requires HTTPS server URLs in release builds.

## Tests

```sh
bash scripts/check_public_repo.sh
JWT_SECRET=test-only-jwt-secret .venv/bin/python -m pytest backend/tests -q
(cd mobile && flutter analyze && flutter test)
```

GitHub Actions runs the same hygiene, backend, and Flutter checks on pushes and pull requests.

## Status

Active development. This repository is being prepared for public release.

## Roadmap

- Add product screenshots and release notes.
- Define a public deployment and mobile-release process.
- Select a license before publishing a reusable open-source release.

## Limitations

The repository does not include production credentials, a production database, Android signing material, or release artifacts. Deployment still requires environment-specific configuration and operational review.

## License

No license has been selected. All rights are reserved until the owner explicitly chooses and adds a license.
