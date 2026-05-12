# Cosmo UI/UX Progress

Last updated: 2026-05-10

## Current Stop Point

Stopped after completing:

- Phase 6: Large File Split And Legacy Removal.
- Step 5 complete: replaced selected raw controls with shared theme-aware components.

Next exact step:

- Phase 7 only when explicitly requested.

Do not start Phase 7, backend/VPS/API work, localization work, salary ring work, or theme/background phases without an explicit request.

## Progress Rule

Every time a phase is completed, update this file with:

- completed phase and steps
- exact next phase/step to start
- explicit scope boundaries for what must not be started yet
- latest verification status

## Completed

### Phase 1: Stabilize Current Dark UI

- Step 1 complete: salary ring layering fixed so ASCII/symbol ring is the visible body.
- Step 2 complete: analyzer warnings fixed.
- Step 3 complete: shared Nebula dialog/snackbar/button cleanup progressed; raw feature-level snackbar/dialog/button usages replaced.
- Step 4 complete: desktop/mobile modal variants covered by tests.
- Step 5 complete: `flutter analyze --no-pub` and `flutter test --no-pub` passed.

### Phase 2: Theme Architecture

- Step 1 complete: `AppVisualMode` and `appVisualModeProvider` added.
- Step 2 complete: `CosmoThemeTokens` theme extension added.
- Step 3 complete: `AppTheme.darkInternals` added; `AppTheme.dark` remains as compatibility alias.
- Step 4 complete: placeholder `AppTheme.lightShader` and `AppTheme.lightLite` added.
- Step 5 complete: `main.dart` no longer hardcodes `ThemeMode.dark`; it uses `appVisualModeProvider` and `AppTheme.themeModeFor`.

### Phase 3: Background Host

- Step 1 complete: `AppBackgroundHost` added.
  - `darkInternals` routes to existing `NebulaBackground`.
  - `lightLite` routes to the static low-load `PathFieldBackground`.
- Step 2 complete: existing dark background ownership moved behind `AppBackgroundHost`.
  - App shell and login use `AppBackgroundHost(darkBackground: AppDarkBackground.asciiWater)`.
  - Standalone admin screen uses default `AppBackgroundHost`/`NebulaBackground`.
  - Calendar, students, and salary no longer wrap content in transparent no-op `NebulaBackground`.
  - Direct feature/router background wrappers are removed; background implementations remain available behind the host.
- Step 3 complete: light shader mode now uses `PathFieldBackground`.
  - Added a Flutter `CustomPainter` path field based on the BackGround Path curved path pattern.
  - Path motion uses a quiet looping reveal/offset pulse and respects `MediaQuery.disableAnimations`.
- Step 4 complete: light lite mode now uses the same path field in static low-load mode.
  - Added an `animated` flag to `PathFieldBackground`.
  - `AppVisualMode.lightLite` passes `animated: false`, which keeps the path field at a calm static state.
- Step 5 complete: unused background experiments are marked for future deletion.
  - `nebula_shader_background.dart`
  - `warp_background.dart`
  - `animated_star_background.dart`
  - `fluid_ascii_background.dart`
  - Files were not deleted; each public widget class is annotated with a Phase 3 Step 5 deprecation marker.

### Phase 4: Light Shader Interaction

- Step 1 complete: added `InteractiveLightShaderBackground`.
  - `AppVisualMode.lightShader` wraps screen content with the interactive layer inside `PathFieldBackground`.
  - Pointer down and drag create short-lived soft splats that bloom from the white canvas and decay quickly.
  - `MediaQuery.disableAnimations` returns the child without registering pointer-driven shader paint.
  - `AppVisualMode.lightLite` remains static and does not include the interactive shader layer.
- Step 2 complete: added focused lifecycle and reduced-motion coverage.
  - Touch down creates a splat and the layer decays back to idle.
  - Drag creates additional splats and clears after the lifetime.
  - Reduced motion bypasses the pointer listener and does not register splats.
  - Splat aging now uses real elapsed frame time instead of a fixed per-frame delta.
- Step 3 complete: tuned interaction performance gates and splat budget.
  - Tiny pointer moves are throttled and do not create new splats.
  - Meaningful drag distance still creates additional splats.
  - The existing max active splat budget remains capped at 10.
- Step 4 complete: documented light shader fallback boundaries.
  - Added `docs/cosmo-light-shader-fallback-boundaries.md`.
  - Captures mode responsibilities for Dark Internals, Light Shader, and Light Lite.
  - Captures reduced-motion fallback rules, performance fallback rules, current implementation boundaries, and Phase 4 out-of-scope items.
- Step 5 complete: reviewed Phase 4 completion.
  - Confirmed `lightShader` routes through `PathFieldBackground` and `InteractiveLightShaderBackground`.
  - Confirmed `lightLite` remains `PathFieldBackground(animated: false)` and has no interactive shader layer.
  - Confirmed reduced-motion bypass, splat lifecycle, throttle, and budget are covered by tests.
  - Confirmed Phase 5 composition, login sphere, full fluid sim, and background deletion stayed out of scope.

### Phase 5: Optimus-Level Composition

- Step 1 complete: redesigned the login sphere/planet as `CosmoLoginSphere`.
  - Extracted the old private login planet painter into a reusable widget.
  - Reworked the visual into an Optimus-inspired rotating symbol sphere.
  - The sphere uses `CosmoThemeTokens`, supporting dark code-like color and light graphite-style treatment.
  - `MediaQuery.disableAnimations` freezes the sphere at a calm static state.
  - `LoginScreen` now uses `CosmoLoginSphere`.
- Step 2 complete: reworked the desktop shell to use proper content width and hierarchy.
  - Added shared `DesktopContentFrame`.
  - Desktop shell now places the global month bar and routed screen child inside the same constrained column.
  - Wide desktop windows get shared horizontal padding and a maximum content width instead of stretching mobile-oriented screens edge to edge.
  - Individual feature screens were not rewritten.
- Step 3 complete: reduced dense glowing effects in light modes.
  - Added `glowIntensity` to `CosmoThemeTokens`.
  - Dark Internals keeps full glow intensity; Light Shader and Light Lite use restrained lower values.
  - `StellarButton` removes dense text/icon glow shadows in light modes and uses a quieter light fill/border treatment.
  - `NebulaSurface`, `NebulaInput`, and `NebulaToggle` now scale or replace dense colored glow with lighter shadow/edge behavior in light themes.
  - Dark mode behavior remains expressive and token-driven.
- Step 4 complete: kept dark mode expressive but restrained.
  - Tuned shared `NebulaTokens` glow presets instead of rewriting individual screens.
  - `glowSoft`, `glowMedium`, and `glowFocus` still use the three-layer core/signal/falloff model.
  - Wide blur/spread values are now capped so focus and semantic states avoid heavy neon bloom.
  - Added coverage that dark glow presets stay bounded while preserving the soft -> medium -> focus intensity ramp.

### Phase 6: Large File Split And Legacy Removal

- Step 1 complete: split `salary_screen.dart`.
  - Kept public `SalaryScreen` and `_SalaryContent` in `screens/salary_screen.dart`.
  - Moved the salary ring painter/profile into `widgets/salary_ring.dart` as a `part`.
  - Moved salary presentation sub-widgets into `widgets/salary_components.dart` as a `part`.
  - Kept private widget names and behavior unchanged by using Dart part files.
  - Reduced `salary_screen.dart` from 1194 lines to 529 lines.
- Step 2 complete: split `calendar_screen.dart`.
  - Kept public `CalendarScreen` and route/modal orchestration in `screens/calendar_screen.dart`.
  - Moved month stats into `widgets/calendar_month_stats.dart` as a `part`.
  - Moved mobile day lesson sheet into `widgets/day_lessons_sheet.dart` as a `part`.
  - Moved add-lesson form into `widgets/add_lesson_sheet.dart` as a `part`.
  - Moved desktop day lesson dialog into `widgets/day_lessons_dialog.dart` as a `part`.
  - Kept private widget names and behavior unchanged by using Dart part files.
  - Reduced `calendar_screen.dart` from 1362 lines to 258 lines.
- Step 3 complete: split `student_detail_sheet.dart`.
  - Kept public `StudentDetailSheet` and drag/status orchestration in `widgets/student_detail_sheet.dart`.
  - Moved lesson/subscription loading and main body into `widgets/student_detail_content.dart` as a `part`.
  - Moved the animated status toggle into `widgets/student_status_toggle.dart` as a `part`.
  - Moved presentation sub-widgets into `widgets/student_detail_components.dart` as a `part`.
  - Kept private widget names and behavior unchanged by using Dart part files.
  - Reduced `student_detail_sheet.dart` from 1108 lines to 290 lines.
- Step 4 complete: deleted confirmed unused files.
  - Removed unused Phase 3 background experiments: `nebula_shader_background.dart`, `warp_background.dart`, `animated_star_background.dart`, and `fluid_ascii_background.dart`.
  - Removed old unused navigation widget `orbit_tab_bar.dart`.
  - Removed legacy unused color shim `cosmo_colors.dart`.
  - Removed unused shader asset `shaders/liquid_nebula.frag` and its `pubspec.yaml` shader entry.
  - Kept still-used `GlowMenuBar` and `MistModal`.

## Latest Verification

Latest checks during Phase 6 Step 5:

- `dart format lib/shared/widgets/nebula_text_button.dart lib/features/calendar/presentation/screens/calendar_screen.dart lib/features/students/presentation/screens/students_screen.dart lib/features/admin/presentation/screens/admin_screen.dart lib/features/salary/presentation/screens/salary_screen.dart lib/features/salary/presentation/widgets/salary_components.dart test/shared/widgets/nebula_text_button_test.dart`
  - Result: completed.
- `flutter analyze --no-pub`
  - Result: passed, no issues found.
- `flutter test --no-pub test/shared/widgets/nebula_text_button_test.dart`
  - Result: passed, 2/2 tests.
- `flutter test --no-pub`
  - Result: passed, 35/35 tests.

## Important Future Constraints

- Before light theme/background/login sphere work, read the reference files named in `docs/cosmo-ui-ux-optimization-plan.md`.
- Phase 5 is complete.
- Phase 6 Step 1 through Step 5 are complete.
- Do not start Phase 7 until explicitly requested.
- Keep working phase-by-phase.
