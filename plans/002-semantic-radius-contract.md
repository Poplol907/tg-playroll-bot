# Plan 002: Make every application radius follow one semantic contract

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report; do not improvise. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 6c4f853..HEAD -- mobile/lib/core/theme mobile/lib/shared/widgets mobile/lib/core/router/app_router.dart mobile/lib/features mobile/test/core/theme mobile/test/architecture`
>
> If any in-scope file changed, compare the current-state excerpts below with
> the live code. If the radius API or surface ownership changed materially,
> STOP and report instead of layering another radius system on top.

## Status

- **Status**: DONE (2026-06-22)
- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `6c4f853`, 2026-06-22

## Why this matters

Cosmo Studio already has radius tokens and surface profiles, but feature code
can freely override them and several widgets still use raw numeric radii. The
result is visually inconsistent nesting: related cards, borders, clips, modal
shells, controls, and pills do not always trace the same geometry. A global
radius change cannot currently propagate from one place.

The goal is not to make every shape use one number. The goal is a semantic
contract: cards share one radius, panels and modals share one radius, controls
share one radius, and pills/circles use shape semantics rather than arbitrary
large numbers.

## Current state

Relevant files and roles:

- `mobile/lib/core/theme/nebula_tokens.dart` — generic XS/SM/MD/LG/XL values.
- `mobile/lib/core/theme/nebula_surface_profile.dart` — maps surface roles to
  generic values.
- `mobile/lib/shared/widgets/nebula_surface.dart` — canonical surface, but
  accepts a free-form `borderRadius` override.
- `mobile/lib/shared/widgets/nebula_modal_surface.dart` — canonical modal
  chrome, currently resolves the card profile.
- `mobile/lib/core/theme/nebula_component_styles.dart` — semantic component
  geometry, including pill badges.
- `mobile/lib/core/router/app_router.dart` and
  `mobile/lib/shared/widgets/glow_menu_bar.dart` — top and bottom navigation
  islands with raw `999` radii.
- Feature presentation files under `mobile/lib/features/**` — approximately
  105 radius declarations at the planned commit; 72 are token-backed and 13
  are direct numeric declarations.

Current generic tokens (`mobile/lib/core/theme/nebula_tokens.dart:20-25`):

```dart
static const double radiusXS = 8;
static const double radiusSM = 12;
static const double radiusMD = 18;
static const double radiusLG = 24;
static const double radiusXL = 32;
```

Current profile mapping (`mobile/lib/core/theme/nebula_surface_profile.dart:115-123`):

```dart
NebulaSurfaceProfile.input => NebulaTokens.radiusSM,
NebulaSurfaceProfile.card => NebulaTokens.radiusMD,
NebulaSurfaceProfile.panel => NebulaTokens.radiusLG,
NebulaSurfaceProfile.modal => NebulaTokens.radiusLG,
NebulaSurfaceProfile.nav => NebulaTokens.radiusLG,
NebulaSurfaceProfile.status => NebulaTokens.radiusSM,
```

The modal wrapper contradicts its own ownership documentation
(`mobile/lib/shared/widgets/nebula_modal_surface.dart:36-40`):

```dart
final surface = NebulaSurfaceProfile.card.resolve(context);
final radius = borderRadius ?? _defaultRadius(surface.radius);
```

Examples of caller-owned surface radius decisions:

- `calendar_screen.dart:177-180` uses `radiusLG` for a normal
  `NebulaSurface`.
- `students_screen.dart:261-265` uses `radiusMD` for a repeated student card.
- `salary_components.dart` mixes SM, MD, and LG surface overrides.
- `app_router.dart:509,584`, `glow_menu_bar.dart:147,177,890`, and
  `view_as_banner.dart:63` use raw `999` for pills.
- `student_status_toggle.dart:70` derives a pill using raw `15` rather than a
  shape contract.

Repo conventions to preserve:

- Colors remain in `CosmoThemeTokens` / `NebulaSemantic`.
- Surface material remains in `NebulaSurfaceProfile`.
- Named component geometry belongs in `NebulaComponentStyles`.
- `NebulaSurface` remains blur-free by default.
- Use `BoxShape.circle` for circles and a canonical stadium/pill radius for
  capsules. Do not turn circles into rounded rectangles.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Radius inventory | `rg -n "BorderRadius\\.circular\\([0-9]|Radius\\.circular\\([0-9]|borderRadius:\\s*[0-9]+" mobile/lib -g '*.dart'` | only documented micro-geometry allowlist matches remain |
| Format | `dart format <changed Dart files>` from `mobile/` | exit 0 |
| Analyze | `flutter analyze --no-pub` from `mobile/` | `No issues found!` |
| Focused tests | `flutter test --no-pub test/core/theme test/architecture` from `mobile/` | all pass |
| Full tests | `flutter test --no-pub` from `mobile/` | all pass |
| Whitespace | `git diff --check` | no output |

## Scope

**In scope**:

- `mobile/lib/core/theme/nebula_tokens.dart`
- Create `mobile/lib/core/theme/nebula_radii.dart` if a separate semantic type
  is cleaner than adding semantic names to `NebulaTokens`.
- `mobile/lib/core/theme/nebula_surface_profile.dart`
- `mobile/lib/core/theme/nebula_component_styles.dart`
- `mobile/lib/shared/widgets/nebula_surface.dart`
- `mobile/lib/shared/widgets/nebula_modal_surface.dart`
- Shared widgets returned by the radius inventory command.
- `mobile/lib/core/router/app_router.dart`
- Feature presentation Dart files returned by the radius inventory command or
  containing `NebulaSurface(borderRadius: ...)`.
- `mobile/test/core/theme/nebula_surface_profile_test.dart`
- `mobile/test/core/theme/nebula_tokens_test.dart`
- `mobile/test/widget_test.dart` — update existing modal/card expectations to
  the canonical modal profile introduced by Step 2; do not change unrelated
  widget tests.
- Create `mobile/test/architecture/radius_architecture_test.dart`.

**Out of scope**:

- Colors, opacity, blur, shadows, typography, spacing, and animation redesign.
- Changing card content or feature behavior.
- Changing the top-island layout; Plan 003 owns that.
- Moving screen headers; Plan 004 owns that.
- Painter geometry where the value is mathematically derived from size, such
  as circles, shader radii, orbit radii, and salary-ring geometry.
- Backend/API changes.

## Git workflow

- Branch: `refactor/semantic-radius-contract`.
- Use conventional commit style: `refactor(ui): centralize semantic radii`.
- Do not push or open a PR unless explicitly instructed.
- Do not use `git add .`; stage only files from this plan.

## Steps

### Step 1: Add a semantic radius vocabulary

Create one canonical semantic API. Preferred shape:

```dart
abstract final class NebulaRadii {
  static const double micro = 4;
  static const double control = 12;
  static const double card = 18;
  static const double panel = 24;
  static const double modal = 24;
  static const double sheet = 24;
  static const double hero = 32;
  static const double pill = 999;

  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillBorder =
      BorderRadius.all(Radius.circular(pill));
}
```

Exact naming may follow existing style, but names must describe component
roles rather than sizes. Keep generic radius aliases only temporarily if
required to keep intermediate commits compiling; remove or deprecate them by
the end of this plan. Do not create two permanent sources of truth.

**Verify**: add unit assertions that card/control/panel/modal/pill semantics
resolve to the intended values, then run:

`flutter test --no-pub test/core/theme` → all tests pass.

### Step 2: Make profiles own surface radii

Update `NebulaSurfaceProfile` to resolve semantic radii directly:

- `input` and `status` → control.
- `card` and `frostedSmall` → card.
- `panel`, `modal`, and `nav` → their named semantic values.

Fix `NebulaModalSurface` to resolve `NebulaSurfaceProfile.modal`, not `card`.
Dialog chrome must use the resolved modal radius; mobile sheet chrome must use
the canonical top-sheet radius. The outer decoration, clip, sheen decoration,
and border painter must all receive the identical resolved geometry.

Add tests that assert profile-to-radius mapping in both themes and assert that
modal outer decoration and inner clip use the same `BorderRadius`.

**Verify**:

`flutter test --no-pub test/core/theme/nebula_surface_profile_test.dart test/widget_test.dart`
→ all tests pass.

### Step 3: Remove feature-level radius decisions from normal surfaces

Inventory every `NebulaSurface(borderRadius: ...)`. For each call:

- Repeated card → `profile: NebulaSurfaceProfile.card`, no radius override.
- Large grouped panel/hero section → `profile: NebulaSurfaceProfile.panel`, no
  radius override.
- Status/chip surface → status profile or `StatusBadge`.
- Modal/dialog/sheet → `NebulaModalSurface` / modal profile.
- Navigation island → nav profile plus canonical pill shape only where the
  geometry is truly a capsule.

Do not blindly replace every number with `card`. Preserve semantic hierarchy.
If a surface cannot be classified into one of the existing roles, STOP and
report the file and intended role before adding another profile.

**Verify**:

`rg -n -U "NebulaSurface\\([\\s\\S]{0,240}?borderRadius:" mobile/lib/features -g '*.dart'`

Expected: no matches except an explicit allowlist documented in the new
architecture test.

### Step 4: Replace raw pill/control constants

Replace raw `999` at application call sites with the canonical pill API.
Replace half-height constants such as the 30px toggle's raw radius `15` with
`StadiumBorder`, canonical pill border, or geometry derived from the component
height. Replace micro radii (`2`, `4`, `6`, `10`) only when they represent UI
shape semantics; mathematical painter values remain local.

The bottom bar container, its `ClipRRect`, and liquid pill must share the same
pill border object. The top month pill and view-as capsule must use that same
semantic object. Circular arrow/action buttons stay `BoxShape.circle`.

**Verify**: run the radius inventory command. Expected: remaining raw matches
are only documented micro/painter geometry.

### Step 5: Add an architecture guard

Create `mobile/test/architecture/radius_architecture_test.dart`, following the
source-scanning style of existing architecture tests. It must fail when:

- Feature code adds raw `BorderRadius.circular(<numeric literal>)` for a normal
  application surface.
- Feature code adds raw `borderRadius: 999`.
- A `NebulaSurface` in feature code overrides radius without being in a small,
  documented allowlist.
- `NebulaModalSurface` stops resolving the modal profile.

Allow derived painter geometry, progress bars, drag handles, and calendar-cell
micro geometry through explicit path-based exceptions with comments.

**Verify**:

`flutter test --no-pub test/architecture/radius_architecture_test.dart`
→ all tests pass and intentionally inserting a forbidden raw radius makes the
test fail before reverting the probe.

### Step 6: Run full verification and review the visual hierarchy

Run formatter, analyzer, focused tests, full tests, and `git diff --check`.
Review the diff to ensure it changes geometry ownership only; reject any
unrelated color, alpha, motion, or layout edits.

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

- Extend `nebula_surface_profile_test.dart` with every semantic profile radius.
- Add modal outer/inner radius equality coverage.
- Add `radius_architecture_test.dart` source guards.
- Preserve existing blur/profile tests.
- Use `mobile/test/architecture/surface_architecture_test.dart` as the
  structural pattern for source-scanning tests.

## Done criteria

- [ ] One semantic radius API owns card, panel, control, modal, sheet, hero,
  pill, and micro geometry.
- [ ] Surface profiles resolve semantic radii directly.
- [ ] `NebulaModalSurface` resolves the modal profile.
- [ ] Normal feature surfaces no longer choose arbitrary radii.
- [ ] Top/bottom navigation pills share one canonical pill border.
- [ ] Raw numeric radius inventory contains only documented micro/painter
  exceptions.
- [ ] Architecture guard exists and passes.
- [ ] `flutter analyze --no-pub` passes.
- [ ] Full Flutter tests pass.
- [ ] `git diff --check` passes.
- [ ] No out-of-scope behavior or visual-token changes are present.

## STOP conditions

Stop and report if:

- Another agent changed radius tokens, surface profiles, or navigation chrome
  after commit `6c4f853` and the excerpts no longer match.
- A feature surface cannot be classified without creating a new visual role.
- Removing a radius override changes layout dimensions rather than only corner
  geometry.
- Tests reveal that a public widget API outside this app depends on the old
  generic radius constants.
- The migration requires changing colors, opacity, blur, or feature behavior.

## Maintenance notes

- Reviewers should reject new feature-level raw radius constants unless they
  are mathematical painter geometry.
- Future visual tuning should change semantic values or profile mapping, not
  dozens of call sites.
- Plan 003 assumes this contract exists and must reuse it for the top island.
- Do not interpret "consistent" as "one radius everywhere"; hierarchy is part
  of the design language.
