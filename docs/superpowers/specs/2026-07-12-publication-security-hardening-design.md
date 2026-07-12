# Publication Security Hardening Design

## Goal

Prepare Cosmo Studio for publication without exposing local agent data or
weakening the security of user data. The work covers the source tree, runtime
security boundaries, regression tests, repository documentation, and a
separate Git-history rewrite.

## Scope and order

1. Remove locally generated agent databases and related state from the tracked
   tree; make them impossible to re-add through `.gitignore`.
2. Eliminate the public development route that combines `DEV_MODE=1` with a
   known JWT fallback. Development remains local-only; public deployments must
   require a configured secret.
3. Make organization boundaries canonical: every user lookup used for a
   mutation is scoped by `current_user.org_id`.
4. Store authentication data securely on every supported platform and reject
   plaintext HTTP server URLs in release builds.
5. Add focused regression coverage for organization isolation and client-side
   transport/storage policy.
6. Harden release configuration: environment ignore rules, safe local Compose
   defaults, and non-debug Android release signing configuration.
7. Add public-repository essentials: accurate root README, security/privacy
   guidance, license selection placeholder, and CI verification.
8. After all source changes are verified, rewrite Git history to remove the
   local databases, rescan history, then force-push only with explicit user
   authorization.

## Boundaries

- No real secrets, user records, or database contents are copied into code,
  tests, documentation, commits, or reports.
- Existing API response shapes are preserved unless a security fix requires a
  documented failure response.
- No production credentials, domain configuration, signing keys, or release
  artifacts are created by this work.
- Git-history rewrite is deferred until source changes pass checks; it is
  performed once, from a verified branch, with a backup reference retained
  locally until verification succeeds.

## Architecture

The backend remains the authorization authority. Router mutations identify the
current organization once and pass it into every lookup. The Flutter client
keeps tokens and cached identity data in platform secure storage; release URL
validation permits HTTPS only. Local development HTTP remains an explicit
debug-only capability and cannot silently become a release setting.

Repository hygiene is enforced by ignore rules and CI checks for prohibited
tracked paths. Security regression tests protect the tenant boundary and the
client transport/storage invariants.

## Verification

- Targeted backend API tests prove an admin cannot read, change role, rename,
  reset password, or otherwise mutate users outside its organization.
- Flutter tests prove release URL validation rejects HTTP and token storage
  uses the secure storage implementation on macOS as well as mobile.
- `flutter analyze` and `flutter test` pass.
- Backend tests run from a declared development dependency environment.
- `git ls-files` contains no local databases, journals, environment files,
  signing keys, or generated artifacts.
- After history rewrite, a history scan confirms the removed paths and known
  secret signatures do not remain in reachable commits.

## Risks and rollout

Changing storage on macOS may sign users out once, which is acceptable and
preferable to retaining a plaintext token. Restricting HTTP can affect local
desktop development; the debug-only path must be clearly documented. History
rewrite requires every collaborator to re-clone or reset their local clone.

