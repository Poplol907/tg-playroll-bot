# Surface Architecture Consolidation

This document tracks the current Nebula surface architecture and the remaining
migration debt. It is intentionally scoped: legacy code is not removed here
without a separate decision.

## Canonical API

- `CosmoThemeTokens` owns semantic theme colors for light and dark modes.
- `NebulaAlpha` owns every opacity value used by the design system. **All**
  glass plate transparency, border, glow and overlay values come from this
  single file. Feature code MUST use `NebulaAlpha.surface` etc., not raw
  numbers like `0.12`.
- `NebulaTokens` owns spacing, radii, blur limits, motion, and glow constants.
  Alpha constants are re-exported as `NebulaTokens.alphaSurface` etc. for
  call-site convenience.
- `NebulaSurfaceProfile.resolve(context, accent:)` turns theme tokens into a
  concrete surface recipe: fill, border, radius, padding, shadow, sheen, and
  blur policy.
- `NebulaSurface(profile:)` is the canonical card/panel/content primitive.
- `MistModal` and `AdaptiveModal` are the canonical modal hosts.
- `GlowMenuBar` and `DesktopSidebar` use `NebulaSurfaceProfile.nav` for shell
  chrome.
- `NebulaInput` uses `NebulaSurfaceProfile.input`.

Default surfaces must be cheap: no `BackdropFilter`, no fullscreen blur, no
always-running animation. Blur is opt-in only through explicit APIs such as
`NebulaSurface(frosted: true)` or `NebulaSurfaceProfile.frostedSmall`.

## Canonical Profiles

- `card`: repeated-safe cards and list items.
- `panel`: denser app panels and grouped content.
- `modal`: bottom sheets, desktop dialogs, and modal chrome.
- `input`: input fields and search fields.
- `nav`: bottom bar and desktop sidebar chrome.
- `status`: compact semantic status badges and helper callouts.
- `frostedSmall`: rare small-area blur, never a default.

## Legacy Bypasses

### Direct Blur

- `lib/features/auth/presentation/screens/login_screen.dart`
  - Uses direct `BackdropFilter` with `ImageFilter.blur`.
  - Keep as visual debt until login visual QA/performance pass.
- `lib/shared/widgets/jiggle_delete_wrapper.dart`
  - Uses `ui.ImageFilter.blur` for localized delete feedback.
  - Review separately because it may be interaction-specific rather than a
    surface.
- `lib/shared/widgets/nebula_surface.dart`
  - Canonical opt-in blur path. Do not treat this as debt.

### Direct Bottom Sheets / Dialogs

These are transition/modal-host debt. Do not delete or rewrite without a
separate transition decision.

- `lib/features/students/presentation/widgets/schedule_builder_modal.dart`
- `lib/features/students/presentation/widgets/student_detail_sheet.dart`
- `lib/features/calendar/presentation/widgets/day_lessons_sheet.dart`
- `lib/features/calendar/presentation/widgets/lesson_modal.dart`
- `lib/features/calendar/presentation/screens/calendar_screen.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/core/services/update_service.dart`
- `lib/shared/widgets/server_settings_modal.dart`

### Manual Feature Surfaces

These files still contain custom `Container + BoxDecoration`, hardcoded alpha,
radius, border, or glow values. They should migrate gradually to
`NebulaSurface`, `NebulaSurfaceProfile.status`, or a future shared primitive.

- `lib/features/students/presentation/screens/students_screen.dart`
- `lib/features/students/presentation/widgets/add_student_modal.dart`
- `lib/features/students/presentation/widgets/schedule_builder_modal.dart`
- `lib/features/students/presentation/widgets/student_detail_components.dart`
- `lib/features/students/presentation/widgets/student_detail_content.dart`
- `lib/features/students/presentation/widgets/student_status_toggle.dart`
- `lib/features/calendar/presentation/widgets/add_lesson_sheet.dart`
- `lib/features/calendar/presentation/widgets/day_lessons_sheet.dart`
- `lib/features/calendar/presentation/widgets/day_lessons_dialog.dart`
- `lib/features/calendar/presentation/widgets/lesson_modal.dart`
- `lib/features/calendar/presentation/widgets/calendar_month_stats.dart`
- `lib/features/calendar/presentation/widgets/constellation_calendar.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/features/admin/presentation/widgets/create_user_sheet.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/salary/presentation/widgets/salary_components.dart`
- `lib/features/salary/presentation/widgets/salary_ring.dart`
- `lib/core/services/update_service.dart`

### Legacy Warm Glass Tokens

`NebulaColors.warmGlass` and `NebulaColors.warmPearlBorder` still exist as
legacy tokens. The remaining allowlist is intentionally narrow so new usages do
not appear silently.

- `lib/core/router/app_router.dart`

`app_router.dart` currently uses `warmPearlBorder` as a nav glow color, not as a
surface. Treat this as semantic color cleanup, not surface migration.

### Shared Widgets Still Needing Follow-up

- `lib/shared/widgets/nebula_text_button.dart`
- `lib/shared/widgets/nebula_toggle.dart`
- `lib/shared/widgets/nebula_drum_picker.dart`
- `lib/shared/widgets/nebula_dialog.dart`
- `lib/shared/widgets/server_settings_modal.dart`
- `lib/shared/widgets/glow_menu_bar.dart`

These may intentionally use local interaction effects. Migrate only when the
style is truly a reusable surface/status/action pattern.

## Migration Order

1. Keep profile tests green: default profiles must not blur, frosted profile
   must be explicit, light profiles must stay cool.
2. Finish modal host consolidation:
   `AdaptiveModal`, `MistModal`, `ServerSettingsModal`, update dialogs.
3. Add shared status/action primitives before touching feature screens:
   status badge, icon callout, action row/button surface.
4. Migrate feature modals one family at a time:
   students sheets, calendar sheets, admin dialogs.
5. Migrate repeated cards/lists only after shared primitives exist.
6. Review direct blur hotspots separately with visual QA and performance checks.
7. Remove legacy APIs only after explicit confirmation.

## Performance Rules

- No mass blur.
- No blur in list cards.
- No blur in nav by default.
- No fullscreen `BackdropFilter`.
- No always-running animation just to make a surface feel alive.
- No feature-level `BackdropFilter` without an opt-in reason.
- Prefer token tint, border, sheen, and static shadow over blur.
- Expensive painters/backgrounds need bounded repaint behavior and tests where
  possible.

## Do Not Remove Without Confirmation

- `ServerSettingsModal`
- Direct `showModalBottomSheet` call sites
- Login screen blur/sphere visuals
- Delete feedback blur in `JiggleDeleteWrapper`

## Visual QA Targets

- Login screen: blur hotspot, input readability, light mode.
- Calendar sheets: bottom sheet transitions and repeated status surfaces.
- Students screens/sheets: repeated cards and status chips.
- Admin screen/dialogs: manual dialogs and action surfaces.
- Salary widgets: animated ring and custom highlight surfaces.
- Settings screen: warning/status rows and server status surface.
