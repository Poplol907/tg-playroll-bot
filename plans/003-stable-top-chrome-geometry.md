# Plan 003: Give the floating top island one stable geometry contract

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. Stop
> on any condition listed below; do not improvise. Update `plans/README.md`
> when complete unless a reviewer owns the index.
>
> **Drift check (run first)**:
> `git diff --stat 6c4f853..HEAD -- mobile/lib/core/router/app_router.dart mobile/lib/shared/widgets/app_safe_layout.dart mobile/lib/core/theme mobile/test/core/router mobile/test/shared/widgets`
>
> Plan 002 must be DONE. If it is not, stop. If the top island or radius API
> changed after this plan was written, reconcile the excerpts before editing.

## Status

- **Status**: DONE (2026-06-22)
- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/002-semantic-radius-contract.md`
- **Category**: bug
- **Planned at**: commit `6c4f853`, 2026-06-22

## Why this matters

The mobile month island is painted as a top overlay, while route content uses
an approximate 58px inset. The month capsule can grow when it adds a second
line, so the visible chrome and reserved content area are not guaranteed to
match. That creates the reported overlap between the month capsule and screen
headers/actions.

This plan makes top chrome fixed-format like the bottom navigation island: one
stable height, one metrics source, one material/profile, and no content-driven
height changes.

## Current state

- `mobile/lib/core/router/app_router.dart:409-421` positions the month bar over
  route content in a `Stack`.
- `mobile/lib/shared/widgets/app_safe_layout.dart:16-19` reserves an
  "approximate" `floatingTopBarHeight = 58.0`.
- `mobile/lib/core/router/app_router.dart:492-549` builds the bar with vertical
  padding and a month capsule.
- `app_router.dart:526-538` adds a second visible line when the selected month
  is not current, changing the capsule height.
- Desktop uses the same `_GlobalMonthBar` inside `DesktopContentFrame`; desktop
  composition must remain desktop-native and must not inherit mobile overlay
  assumptions.

Current dynamic content:

```dart
Text(label),
if (!isCurrentMonth) ...[
  const SizedBox(height: 1),
  Text('нажмите для возврата'),
],
```

Current approximate inset:

```dart
static const double floatingTopBarHeight = 58.0;
```

Repo conventions:

- Global shell chrome lives in `app_router.dart`.
- Screen padding is centralized in `AppSafeInsets`.
- Navigation material uses `NebulaSurfaceProfile.nav`.
- Pills and radii must use Plan 002's semantic radius contract.
- Visible instructional copy should not be added to chrome; use semantics,
  tooltip, icon state, or accent state.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `dart format lib/core/router/app_router.dart lib/shared/widgets/app_safe_layout.dart test/core/router test/shared/widgets` from `mobile/` | exit 0 |
| Focused tests | `flutter test --no-pub test/core/router/app_shell_test.dart test/shared/widgets` from `mobile/` | all pass |
| Analyze | `flutter analyze --no-pub` from `mobile/` | `No issues found!` |
| Full tests | `flutter test --no-pub` from `mobile/` | all pass |
| Whitespace | `git diff --check` | no output |

## Scope

**In scope**:

- `mobile/lib/core/router/app_router.dart`
- `mobile/lib/shared/widgets/app_safe_layout.dart`
- Create `mobile/lib/shared/widgets/app_chrome_metrics.dart` or place an
  equivalent single metrics type in an existing appropriate shared file.
- `mobile/test/core/router/app_shell_test.dart`
- Create focused top-island widget tests under `mobile/test/shared/widgets/`.

**Out of scope**:

- Moving feature headers into scroll content; Plan 004 owns that.
- Changing bottom navigation behavior or liquid-pill motion.
- Theme colors, background shaders, font redesign, or surface opacity.
- Desktop content layout beyond keeping the existing desktop month header
  working.
- Reintroducing a full-width top app bar.

## Git workflow

- Branch: `fix/stable-top-chrome-geometry`.
- Commit message: `fix(shell): stabilize floating top chrome geometry`.
- Do not push unless instructed. Do not stage unrelated files.

## Steps

### Step 1: Define exact chrome metrics

Introduce one shared metrics API used by both rendering and content insets.
It must distinguish at least:

- Mobile top-island visual height.
- Mobile outer vertical gap/padding.
- Total route-content top reservation.
- Floating bottom navigation reservation (move the existing 84px constant into
  the same contract if this can be done without changing behavior).

Do not keep "approximate" duplicate values in `AppSafeInsets` and
`app_router.dart`. `AppSafeInsets.screen/list` must consume the canonical
content reservation.

**Verify**: add a unit test asserting the inset equals the same metric used by
the top-island wrapper. Run focused tests; all pass.

### Step 2: Make the mobile month island fixed-height

Extract or reshape the mobile month bar so its outer layout has a stable
height. Keep:

- Left and right circular arrow buttons.
- Center month pill.
- Transparent space between the three islands.
- Nav surface profile and semantic pill/circle geometry from Plan 002.

Remove the second visible line `нажмите для возврата`; it is the source of
content-dependent height and is unnecessary instruction text. Preserve the
"tap to return to current month" behavior. Communicate non-current state with
accent color, a small semantic icon/dot, `Semantics`, and desktop tooltip where
appropriate, without changing height.

Use stable constraints (`SizedBox`, exact minimum/maximum height, and fixed
button size) so text, localization, or selected month cannot resize the shell.

**Verify**: widget tests pump current and non-current month states and assert
identical top-island heights.

### Step 3: Separate mobile overlay geometry from desktop header composition

Desktop may reuse month controls, but it must not depend on mobile overlay
padding or a mobile fixed-width assumption. If `_GlobalMonthBar` cannot serve
both without branching, extract a shared month-control core and create thin
mobile/desktop wrappers.

Do not stretch a mobile capsule across desktop content. Keep
`DesktopContentFrame` behavior unchanged.

**Verify**: existing desktop content-frame tests pass and a desktop month-bar
test has no overflow at 1024px and 1440px widths.

### Step 4: Connect shell placement and safe insets to the exact metric

Use the canonical metric for:

- The `Positioned`/`SafeArea` top-island wrapper.
- `AppSafeInsets.screen` and `AppSafeInsets.list` top reservation.
- Any test harness that calculates available body space.

Do not add another magic spacer inside feature screens. At initial scroll
offset, route content must begin below the island plus the designed gap.

**Verify**: at 320x720, 390x844, and 430x932 test surfaces, assert the top
island rectangle does not intersect a keyed first-content rectangle.

### Step 5: Run full verification

Run formatter, focused tests, analyzer, full tests, and whitespace check.

**Verify**:

```bash
cd mobile
flutter analyze --no-pub
flutter test --no-pub
cd ..
git diff --check
```

Expected: all commands exit 0.

## Test plan

- Current and non-current month produce identical height.
- Long Russian month names and year text fit at 320px width.
- Left/right arrow pucks stay circular and equal-sized.
- First route content does not intersect the top island at three mobile sizes.
- Desktop header has no overflow at compact and wide desktop widths.
- Existing navigation and theme tests remain green.

## Done criteria

- [ ] Top-island height is stable for every month state.
- [ ] Visible `нажмите для возврата` chrome copy is removed.
- [ ] Rendering and content padding consume one metric source.
- [ ] `floatingTopBarHeight` is no longer an approximate duplicate.
- [ ] Current/non-current, narrow-mobile, and desktop geometry tests pass.
- [ ] No feature screen gained a local top spacer.
- [ ] Analyzer, full tests, and `git diff --check` pass.

## STOP conditions

Stop and report if:

- Plan 002 is not complete or no semantic nav/pill geometry exists.
- The month island has been moved or redesigned since `6c4f853`.
- A fixed mobile extent cannot fit supported text at 320px without reducing
  text below the existing readable scale.
- Fixing overlap appears to require per-screen magic offsets.
- Desktop behavior would need to become a stretched mobile header.

## Maintenance notes

- Any future content added to top chrome must fit the fixed contract; it may
  not increase height conditionally.
- Keep shell chrome metrics separate from device `viewPadding`; SafeArea owns
  hardware insets, metrics own application chrome.
- Plan 004 relies on this exact top reservation when moving headers into the
  scroll flow.
