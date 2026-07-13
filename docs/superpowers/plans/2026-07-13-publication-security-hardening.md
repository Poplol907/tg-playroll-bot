# Publication Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the repository safe to publish while preserving tenant isolation, secure client authentication storage, and reproducible release configuration.

**Architecture:** The backend scopes every mutable user lookup to the authenticated organization. Flutter keeps authentication material in secure platform storage and release builds accept HTTPS only. Source-tree hygiene precedes a separately verified history rewrite.

**Tech Stack:** FastAPI, SQLAlchemy async, pytest/httpx, Flutter/Dart, flutter_secure_storage, Docker Compose, GitHub Actions.

## Global Constraints

- Never copy real secrets, user data, or database contents into any source, test, documentation, commit, or report.
- Do not rewrite history or force-push before the source branch passes every verification gate.
- Do not create production credentials, signing keys, or release artifacts.
- Keep commits narrow and use explicit `git add` paths only.

---

### Task 1: Remove tracked local state and add a repository hygiene gate

**Files:**
- Modify: `.gitignore`
- Create: `scripts/check_public_repo.sh`
- Remove from index only: `.swarm/memory.db`, `.swarm/memory.db-shm`, `.swarm/memory.db-wal`, `ruvector.db`

- [ ] Write `scripts/check_public_repo.sh` to fail when `git ls-files` contains `.env` variants, databases, private keys/certificates, Android signing files, dumps, logs, or coverage artifacts.
- [ ] Run the script before cleanup; it must fail because the four local databases are tracked.
- [ ] Add ignore rules for `.env.*` while preserving `.env.prod.example`, signing material, databases, agent state, coverage, logs, and temporary artifacts.
- [ ] Run `git rm --cached` for exactly the four named databases; keep local files untouched.
- [ ] Run the hygiene script and `git check-ignore -v .env.prod release.jks ruvector.db`; all checks must pass.
- [ ] Commit only `.gitignore`, the script, and index removals with `chore: exclude local state from public repository`.

### Task 2: Remove public development authentication fallback

**Files:**
- Modify: `backend/app/auth.py`, `start.sh`, `.env.prod.example`
- Create: `backend/tests/test_auth_configuration.py`

- [ ] Write a failing pytest that imports a fresh auth module with `JWT_SECRET` absent and `DEV_MODE=1`; assert it raises `RuntimeError` mentioning `JWT_SECRET`.
- [ ] Run the single test and confirm it fails because the current development fallback is active.
- [ ] Remove the fallback key. Require a non-empty `JWT_SECRET` in every mode.
- [ ] Convert `start.sh` to local-only development: bind to loopback, remove the public quick-tunnel route, and document the required local secret without including one.
- [ ] Run the new test, then the full backend suite; both must pass.
- [ ] Commit these exact files with `fix(auth): require configured JWT secret in every mode`.

### Task 3: Enforce organization-scoped user mutations

**Files:**
- Modify: `backend/app/routers/admin.py`, `backend/app/routers/auth.py`, `backend/app/routers/users.py`
- Create: `backend/tests/test_user_tenant_isolation.py`

- [ ] Write failing API tests with two organizations. An admin in organization A must receive 404 when trying to reset a password, change the role, or rename a user in organization B; the B record must be unchanged.
- [ ] Run those tests and observe the current cross-organization mutation failure.
- [ ] Scope every mutable user lookup to both the requested login and `current_user.org_id`; scope login uniqueness checks to the same organization.
- [ ] Do not alter the login API to support duplicate logins across organizations without a separate product decision on organization selection.
- [ ] Run all backend tests; they must pass.
- [ ] Commit the router and test files with `fix(authz): scope user mutations to organization`.

### Task 4: Protect client tokens and reject release HTTP endpoints

**Files:**
- Modify: `mobile/lib/core/storage/app_storage.dart`, `mobile/lib/core/network/server_config.dart`, `mobile/lib/shared/widgets/server_settings_modal.dart`
- Create: `mobile/test/core/network/server_config_test.dart`, `mobile/test/core/storage/app_storage_test.dart`

- [ ] Write a failing Dart test asserting release URL policy rejects `http://example.test` and accepts HTTPS.
- [ ] Run it; the current validator must fail because it accepts HTTP.
- [ ] Extract a pure URL-policy API: HTTPS is always allowed; HTTP is allowed only in `kDebugMode` for loopback or private-LAN hosts. Surface a user-readable validation error.
- [ ] Write a failing storage-construction test asserting macOS selects `FlutterSecureStorage`, never `SharedPreferences`.
- [ ] Refactor construction behind an injectable platform predicate; remove the macOS SharedPreferences branch and use Keychain-backed storage.
- [ ] Run both new Flutter tests, `flutter analyze`, and `flutter test`; all must pass.
- [ ] Commit the changed Dart files and tests with `fix(mobile): protect tokens and require secure server URLs`.

### Task 5: Harden release configuration, documentation, and CI

**Files:**
- Modify: `docker-compose.yml`, `mobile/android/app/build.gradle.kts`, `Caddyfile`, `scripts/check_public_repo.sh`
- Create: `README.md`, `.github/workflows/verify.yml`
- Decision required: `LICENSE`

- [ ] Extend the hygiene script to reject a literal database password, externally bound PostgreSQL, and debug signing in Android release config; verify it fails first.
- [ ] Configure local Compose credentials through environment substitution and bind Postgres to `127.0.0.1`.
- [ ] Make Android release signing read only ignored local `key.properties` and fail release assembly with a clear message if unavailable; do not generate a keystore.
- [ ] Remove deployment-specific host/IP comments from `Caddyfile` while preserving its domain reverse-proxy behavior.
- [ ] Add root README sections: project, problem, solution, features, screenshots placeholder, stack, architecture, setup, environment variables, security/privacy, tests, status, roadmap, limitations, and license.
- [ ] Add CI that runs the hygiene check, installs declared backend dev dependencies, runs backend tests, `flutter analyze`, and `flutter test`.
- [ ] Do not create `LICENSE` until the owner explicitly selects one.
- [ ] Run hygiene, backend tests, Flutter analysis, and Flutter tests; all must pass.
- [ ] Commit this task with `chore: harden public release configuration`.

### Task 6: Rewrite history only after source verification

**Files:** Git history only; no source modifications.

- [ ] Create a local backup branch named `backup/pre-public-history`.
- [ ] Check `git filter-repo --version`; if unavailable, stop and request approval to install it rather than using an alternative rewrite command.
- [ ] Run `git filter-repo` with the four database paths and `--invert-paths`; do not rewrite author metadata or unrelated paths.
- [ ] Verify no reachable commit contains the removed paths; re-run the hygiene and secret-signature scans.
- [ ] Present the rewritten state for owner review before `git push --force-with-lease origin main`.
- [ ] After the approved force-push, notify collaborators to re-clone or reset their local clones.

## Plan self-review

- Tasks 1–6 cover every security and publication-readiness requirement from the approved design.
- The only deliberate deferrals are a license choice and a possible multi-tenant login-contract redesign; both require owner decisions.
- All behavior changes have a test-first gate and an exact verification command.
