# Plan 005: Add regression gates for radii, top chrome, and scrolling headers

> **Executor instructions**: Execute only after Plans 002, 003, and 004 are
> DONE. This is a verification-hardening plan, not permission to redesign UI.
> Run every gate and stop instead of weakening assertions when a real mismatch
> appears. Update `plans/README.md` when complete.
>
> **Drift check (run first)**:
> `git diff --stat 6c4f853..HEAD -- mobile/lib/core/theme mobile/lib/core/router/app_router.dart mobile/lib/shared/widgets mobile/lib/features mobile/test`
>
> Drift is expected because this plan depends on three earlier plans. Confirm
> their status is DONE and use their resulting APIs. If any is incomplete,
> STOP.

## Status

- **Status**: DONE (2026-06-23)
- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: `plans/002-semantic-radius-contract.md`,
  `plans/003-stable-top-chrome-geometry.md`,
  `plans/004-scroll-away-screen-headers.md`
- **Category**: tests
- **Planned at**: commit `6c4f853`, 2026-06-22

## Why this matters

Current theme tests validate colors and blur policy, but they do not protect
the geometry users notice: matching border/clip radii, stable top-island
height, first-content clearance, and scroll-away headers. Recent shell/nav
history shows repeated changes in exactly this area, so analyzer success alone
cannot prevent visual regressions.

This plan adds deterministic widget and architecture tests. Prefer geometric
assertions over fragile full-screen goldens unless the repository gains a
stable golden workflow during execution.

## Current state

- `mobile/test/core/theme/nebula_surface_profile_test.dart` checks material
  colors and blur, but no radius mapping.
- `mobile/test/core/theme/nebula_tokens_test.dart` checks glow bounds, not
  geometry.
- `mobile/test/core/router/app_shell_test.dart` covers shell paging and blur,
  but not top-island/content intersection across viewports.
- No tests currently search feature code for raw application radii.
- No test proves that a screen header moves with its list and disappears before
  top chrome.

Existing test conventions:

- Use `AppPlatform.debugOverrideIsDesktop` for platform-specific widget tests.
- Use Riverpod overrides to avoid live network calls.
- `test/architecture/surface_architecture_test.dart` is the source-scanning
  pattern.
- Tests must not contact the configured production/VPS API.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused geometry | `flutter test --no-pub test/architecture/radius_architecture_test.dart test/core/router/app_shell_test.dart test/shared/widgets/app_screen_header_test.dart` from `mobile/` | all pass |
| Analyze | `flutter analyze --no-pub` from `mobile/` | `No issues found!` |
| Full tests | `flutter test --no-pub` from `mobile/` | all pass, no HTTP logs |
| Whitespace | `git diff --check` | no output |

## Scope

**In scope**:

- Tests under `mobile/test/architecture/`.
- Tests under `mobile/test/core/theme/`.
- `mobile/test/core/router/app_shell_test.dart`.
- Tests under `mobile/test/shared/widgets/` for radius/header/chrome primitives.
- Feature widget tests needed to verify Calendar, Students, Salary, Settings,
  and Admin mobile header behavior.
- Minimal `Key` additions to in-scope UI primitives only if geometry cannot be
  selected reliably without them.

**Out of scope**:

- Production redesign or token tuning.
- Updating assertions to accept known overlaps.
- Live HTTP requests, integration with VPS, or backend fixtures.
- Screenshot/golden infrastructure requiring new dependencies.
- Performance profiling and 120 FPS claims.

## Git workflow

- Branch: `test/ui-geometry-regressions`.
- Commit message: `test(ui): guard radius and top chrome geometry`.
- Do not push unless instructed. Do not stage generated build artifacts.

## Steps

### Step 1: Complete the radius architecture guard

Review Plan 002's architecture test and strengthen it to cover:

- No raw normal-surface numeric radii in feature code.
- No raw `999`; canonical pill semantics only.
- No feature-level `NebulaSurface(borderRadius:)` except documented
  micro-geometry allowlist.
- Profile radius mapping remains semantic.
- Modal outer border, clip, and sheen geometry remain equal.

The allowlist must list exact files/patterns and explain why each exception is
mathematical micro geometry. Do not use a broad directory exclusion.

**Verify**: focused radius test passes; a temporary forbidden raw card radius
causes failure, then remove the probe.

### Step 2: Add fixed top-island geometry tests

At minimum test mobile sizes:

- 320x720.
- 390x844.
- 430x932.

For each size and both current/non-current month states, assert:

- No Flutter overflow/exception.
- Top-island height is identical.
- Arrow controls are equal-sized circles.
- Month capsule stays between arrows and text fits.
- First route-header rectangle begins below the top-island rectangle plus the
  canonical gap.

Use keys on canonical primitives rather than searching by decoration type.

**Verify**: focused shell tests pass at all six combinations.

### Step 3: Add scroll-away header behavior tests

Build deterministic tests for the shared scroll composition:

- Record global header/title position at offset zero.
- Drag upward a fixed distance.
- Assert header/title Y decreases by the expected direction and list content
  follows the same controller.
- Continue scrolling and assert the header leaves the visible content area
  without a duplicate sticky title.
- Assert no header rectangle intersects the month capsule at rest.

Run at least one actual Calendar mobile composition and one lazy-list
composition (Students or Admin) with all providers overridden locally.

**Verify**: focused feature/header tests pass with no HTTP logger output.

### Step 4: Add semantic radius widget matrix tests

Pump representative primitives in dark and light themes:

- Card surface.
- Panel surface.
- Input/control.
- Dialog and mobile sheet.
- Top month pill and bottom navigation pill.
- Status badge.

Assert each resolves its semantic radius and that nested clip/decoration
geometry matches. Do not compare rendered pixel colors; this suite is about
geometry ownership.

**Verify**: focused shared/theme tests pass in both themes.

### Step 5: Prove tests are offline and deterministic

Every feature test must override auth/user/data providers. Run focused tests
with network unavailable or inspect captured logs; there must be no request to
the configured server. Avoid `pumpAndSettle` where ambient animation can keep
the test alive; use bounded pumps.

If stable full-screen goldens already exist by execution time, add a small
mobile-shell golden matrix. Otherwise do not introduce a new golden stack in
this plan; geometry assertions are the accepted verification mechanism.

**Verify**: focused tests run twice consecutively with identical success and no
network output.

### Step 6: Run full verification

```bash
cd mobile
flutter analyze --no-pub
flutter test --no-pub
cd ..
git diff --check
```

Expected: all commands exit 0 and tests emit no live HTTP requests.

## Test plan

- Architecture source scan for forbidden radius ownership.
- Profile/widget radius matrix in both themes.
- Six top-island viewport/state combinations.
- Shared header scroll behavior.
- Calendar and lazy-list real composition tests with provider overrides.
- Offline/deterministic double run.

## Done criteria

- [ ] Forbidden feature radius patterns fail an architecture test.
- [ ] Current and non-current top islands have equal height at three mobile
  widths.
- [ ] First route header never intersects top chrome at rest.
- [ ] Shared header demonstrably scrolls away with its content.
- [ ] No duplicate sticky header is rendered.
- [ ] Representative surfaces resolve semantic geometry in both themes.
- [ ] Focused tests run twice without HTTP output.
- [ ] Analyzer, full tests, and whitespace check pass.

## STOP conditions

Stop and report if:

- Plans 002, 003, or 004 are incomplete.
- A test requires live network access.
- Geometry cannot be selected without broad production instrumentation.
- Assertions fail because the accepted design still contains overlap; do not
  weaken the assertion to encode the bug.
- Adding goldens requires a new package or platform-specific baseline process.

## Maintenance notes

- Add every new semantic surface role to the radius matrix.
- Add every new shell screen to the scroll-header contract test.
- Keep allowlists narrow and reviewed; they are not a bypass for one-off UI.
- These tests validate geometry, not FPS. Performance requires separate profile
  evidence.
