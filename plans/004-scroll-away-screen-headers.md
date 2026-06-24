# Plan 004: Make mobile screen headers scroll away cleanly beneath top chrome

> **Executor instructions**: Follow this plan in order. Run every verification
> gate. If a STOP condition occurs, report it instead of inventing a local
> workaround. Update `plans/README.md` when done unless a reviewer owns it.
>
> **Drift check (run first)**:
> `git diff --stat 6c4f853..HEAD -- mobile/lib/shared/widgets/app_safe_layout.dart mobile/lib/features/calendar/presentation/screens/calendar_screen.dart mobile/lib/features/students/presentation/screens/students_screen.dart mobile/lib/features/salary/presentation/screens/salary_screen.dart mobile/lib/features/settings/presentation/screens/settings_screen.dart mobile/lib/features/admin/presentation/screens/admin_screen.dart mobile/lib/core/router/app_router.dart mobile/test`
>
> Plans 002 and 003 must be DONE. Compare the current-state excerpts to live
> code before editing. Stop if the shell/header architecture has drifted.

## Status

- **Status**: DONE (2026-06-22)
- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/003-stable-top-chrome-geometry.md`
- **Category**: bug
- **Planned at**: commit `6c4f853`, 2026-06-22

## Why this matters

Mobile screens currently disagree about who owns the title area. Calendar,
Students, and Admin keep a fixed header outside their scrollable content,
while Salary and Settings place titles inside `AppScrollView`. With a
transparent floating month island, fixed headers can collide with global
chrome and create a hard visual cut when list content scrolls.

The chosen interaction is deliberate: route title, teacher identity, and
route actions begin below the month island, then scroll away naturally and
dissolve at the top edge. They are not sticky and do not become a second app
bar beneath the transparent island.

## Current state

Relevant files:

- `mobile/lib/shared/widgets/app_safe_layout.dart` — contains
  `ScrollEdgeFade`, `AppScrollView`, and `AppListView`.
- `calendar_screen.dart:88-145` — fixed teacher name/subtitle/logout row above
  the calendar scroll view.
- `students_screen.dart:38-121` — fixed title/count/add row above a separate
  `AppListView`.
- `admin_screen.dart:70-130` — fixed Studio title/actions above body content.
- `salary_screen.dart:55-77` — title and teacher name already live inside
  `AppScrollView` and are the closest existing behavior exemplar.
- `settings_screen.dart:107-127` — title/login already live inside
  `AppScrollView`.
- `view_as_banner.dart` — separate bottom-right exit capsule for admin
  view-as mode; it must remain independent.

The existing canonical edge treatment (`app_safe_layout.dart:85-111`):

```dart
class ScrollEdgeFade extends StatelessWidget {
  ...
  return ShaderMask(
    shaderCallback: (rect) => const LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0.0, 0.04, 0.96, 1.0],
    ).createShader(rect),
    blendMode: BlendMode.dstIn,
    child: child,
  );
}
```

Calendar's fixed header (`calendar_screen.dart:92-144`) is not inside that
fade/scroll mechanism. It contains both identity and logout. Logout is already
available in Settings (`settings_screen.dart:247-255`), so the calendar copy
is redundant global account chrome.

Repo conventions:

- Mobile screen padding uses `AppSafeInsets`.
- Scroll physics use bouncing + always-scrollable behavior.
- Typography comes from `NebulaTypography` and colors from theme tokens.
- Shared primitives belong in `mobile/lib/shared/widgets/`.
- Desktop and mobile composition may differ; do not stretch mobile behavior
  onto desktop.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `dart format <changed Dart files>` from `mobile/` | exit 0 |
| Focused tests | `flutter test --no-pub test/shared/widgets test/core/router test/features` from `mobile/` | all pass |
| Analyze | `flutter analyze --no-pub` from `mobile/` | `No issues found!` |
| Full tests | `flutter test --no-pub` from `mobile/` | all pass |
| Whitespace | `git diff --check` | no output |

## Scope

**In scope**:

- `mobile/lib/shared/widgets/app_safe_layout.dart`
- Create `mobile/lib/shared/widgets/app_screen_header.dart`.
- Create a canonical sliver scroll wrapper under `mobile/lib/shared/widgets/`
  if `AppScrollView`/`AppListView` cannot compose a header and lazy list.
- `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`
- `mobile/lib/features/students/presentation/screens/students_screen.dart`
- `mobile/lib/features/salary/presentation/screens/salary_screen.dart`
- `mobile/lib/features/settings/presentation/screens/settings_screen.dart`
- `mobile/lib/features/admin/presentation/screens/admin_screen.dart`
- Focused widget tests under `mobile/test/shared/widgets/` and
  `mobile/test/features/`.

**Out of scope**:

- Global month-island geometry; Plan 003 owns it.
- Bottom navigation interaction/motion.
- Student-card, calendar-grid, salary-ring, or admin-card redesign.
- Desktop sidebar or desktop content rail redesign.
- View-as frame/capsule behavior.
- Account/logout backend behavior.
- New sticky/pinned app bars.

## Git workflow

- Branch: `refactor/scroll-away-screen-headers`.
- Commit message: `refactor(ui): unify mobile scroll-away headers`.
- Do not push unless instructed. Stage only in-scope files.

## Target behavior

At scroll offset zero:

- The month island remains floating at the top.
- The route header starts below the exact Plan 003 content inset.
- Title, subtitle/identity, counters, and route-local actions are readable.

During scroll:

- The route header moves with content.
- It fades/dissolves through the canonical top edge before passing under the
  transparent month island.
- No duplicate compact/sticky title appears.
- Content never hard-clips against a rectangular header boundary.

## Steps

### Step 1: Create one shared `AppScreenHeader`

Add a presentation-only primitive supporting:

- Required title.
- Optional subtitle/identity.
- Optional trailing actions.
- Optional leading action for desktop/detail contexts only.
- Stable min-height and spacing from existing typography/tokens.
- `maxLines`, ellipsis, and constrained trailing width on narrow phones.

The primitive must not own a background surface or sticky behavior. It is a
normal scroll child. It must use semantic radii/styles from Plan 002 for any
badge/action geometry and must not add raw `Container + BoxDecoration` glass.

Use Salary/Settings typography as the visual baseline. Remove the Students
light-theme one-off `ShaderMask`; the shared header must resolve text color
from semantic theme tokens.

**Verify**: widget tests at 320px and 430px widths render title, long subtitle,
badge, and two trailing actions with no overflow.

### Step 2: Add a canonical header-plus-scroll composition

Extend the shared scroll layer with a sliver-capable wrapper, for example
`AppCustomScrollView`, that owns:

- `ScrollEdgeFade`.
- Bouncing/always-scrollable physics.
- Keyboard dismiss behavior.
- `AppSafeInsets` top and bottom padding.
- A `SliverToBoxAdapter` header followed by lazy slivers.

Do not put a `ListView` inside `SingleChildScrollView`. Students/Admin require
a real `CustomScrollView` + `SliverList` to preserve lazy list construction.

Keep existing `AppScrollView` and `AppListView` APIs working until every
in-scope screen is migrated. Remove duplication only after callers pass.

**Verify**: shared widget test drags the custom scroll view and asserts the
header's global Y position decreases while the first list item follows it.

### Step 3: Migrate Calendar mobile composition

For mobile only:

- Move teacher display name and `Расписание уроков` into `AppScreenHeader`
  inside the same scroll viewport as the calendar and month stats.
- Remove the calendar logout button and `_confirmLogout`; Settings remains the
  single account logout location.
- Ensure loading/error/data states all begin below top chrome. Do not leave the
  loading/error state centered underneath the month island.
- Keep the desktop layout behavior and calendar sizing intact.

The header must scroll away; do not use `SliverAppBar(pinned: true)`.

**Verify**: calendar widget test confirms no logout icon exists on the mobile
calendar, header starts below top chrome, and header moves upward after drag.

### Step 4: Migrate Students mobile composition

Replace the fixed `Column` header + separate `AppListView` with the canonical
sliver composition:

- Header title `Ученики`.
- Student count badge.
- Add-student action.
- Lazy `SliverList` of student cards.
- Existing first-viewport stagger remains limited to the current 0..7 items.

Do not animate the shared header with parallax. Remove `NebulaParallaxFrame`
from the mobile header so header motion is owned solely by scrolling.

**Verify**: list remains lazy, item 8+ has no stagger delay, and header scrolls
away without overflow at 320px.

### Step 5: Migrate Admin, Salary, and Settings

- Admin: put Studio title/subtitle and add-user action in `AppScreenHeader`
  inside the canonical scroll flow on mobile. Preserve desktop/native header
  behavior and detail back navigation.
- Salary: replace the ad-hoc title/name block with `AppScreenHeader`; preserve
  all ring and entrance animations.
- Settings: replace the ad-hoc title/login block with `AppScreenHeader`; keep
  logout in the Account section.

All five shell screens must now use the same header primitive and top-spacing
contract on mobile.

**Verify**: source search finds no duplicate top-level mobile title blocks for
the five screens outside `AppScreenHeader` composition.

### Step 6: Tune the top fade without hiding initial content

The existing fixed 4% gradient may be too broad/narrow across device heights.
If necessary, make `ScrollEdgeFade` accept top/bottom fade extents expressed in
logical pixels and convert them to shader stops from `rect.height`. Use a
shared default; do not tune per screen.

At offset zero the header must be fully opaque. During upward scroll it should
fade before its text visibly intersects the month capsule.

**Verify**: focused scroll test samples header opacity/mask position at rest,
mid-scroll, and after the header exits. Expected: visible at rest, moving and
clipped/faded during scroll, absent after exit with no exception.

### Step 7: Run full verification

Run formatter, focused tests, analyzer, full suite, and whitespace check.

**Verify**:

```bash
cd mobile
flutter analyze --no-pub
flutter test --no-pub
cd ..
git diff --check
```

Expected: all exit 0.

## Test plan

- `AppScreenHeader` narrow-width overflow and ellipsis tests.
- Shared custom-scroll test proves header and content share one offset.
- Calendar mobile test: no calendar logout, header scrolls away.
- Students mobile test: header/count/add action share scroll and list stays
  lazy.
- Salary test: existing entrance animations/controllers remain present and no
  route-level animation is reintroduced.
- Settings test: logout remains available in Account section.
- Desktop tests: month/header layout and sidebar remain unchanged.

## Done criteria

- [ ] Calendar, Students, Salary, Settings, and Admin use one mobile header
  primitive.
- [ ] Every mobile route header is part of its scroll flow.
- [ ] No mobile route header is pinned beneath the transparent month island.
- [ ] Calendar logout is removed; Settings remains the account logout source.
- [ ] Initial header content does not intersect top chrome at supported sizes.
- [ ] Header scrolls/fades away without hard clipping.
- [ ] Lazy lists and salary animations remain intact.
- [ ] Analyzer, full tests, and whitespace check pass.

## STOP conditions

Stop and report if:

- Plans 002 or 003 are not DONE.
- A screen requires nested vertical scroll views to preserve behavior.
- Migrating Students/Admin would make lists eagerly build all rows.
- Calendar desktop sizing must change to support mobile scrolling.
- The only apparent solution is a pinned/sticky title under the month island.
- Provider/network behavior starts changing as part of the layout refactor.

## Maintenance notes

- New shell screens must compose `AppScreenHeader` inside the canonical scroll
  wrapper; they must not create a fixed title row above a list.
- Keep global actions in global destinations. Logout belongs in Settings, not
  every screen header.
- Reviewers should test both short and long Russian teacher names.
- View-as exit remains a separate overlay and should not be merged into the
  route header.
