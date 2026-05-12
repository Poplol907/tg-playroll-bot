# 2026-05-05 UI + Architecture Handoff

## Goal

Stabilize the Flutter UI for desktop/mobile and start reducing architecture fragility around lesson-driven data refreshes.

## Implemented

### Desktop/mobile UI stabilization

- Fixed calendar constellation line geometry in `mobile/lib/features/calendar/presentation/widgets/constellation_calendar.dart`.
  - X coordinates now use real column width `byWidth`.
  - Y coordinates still use effective cell height `cellSize`.
- Updated schedule builder in `mobile/lib/features/students/presentation/widgets/schedule_builder_modal.dart`.
  - Desktop opens as centered `Dialog`.
  - Mobile still opens as bottom sheet.
  - Weekday header `Пн...Вс` is pinned.
  - Only time rows scroll.
  - Desktop grid uses compact row sizing.
- Updated `mobile/lib/shared/widgets/adaptive_modal.dart`.
  - Added `desktopWidth` so wide desktop dialogs can be used where needed.
- Updated `mobile/test/widget_test.dart`.
  - Replaced placeholder test with a widget test verifying desktop schedule builder opens as `Dialog`, not `DraggableScrollableSheet`.

### Reset-month safety

- Updated `backend/app/routers/reports_v2.py`.
  - `DELETE /reports/v2/reset-month` now handles `lessons.makeup_for_id` self-FK safely.
  - If resetting original lessons, linked makeup lessons are deleted first, even if they are in another month.
  - If resetting makeup lessons, their original lessons are returned to `makeup_status="none"` and `makeup_date=null`.

### Data refresh architecture

- Added `mobile/lib/shared/providers/data_refresh_provider.dart`.
  - New helper: `invalidateMonthData(ref, monthYear, extraMonthYears: [...])`.
  - Invalidates:
    - `lessonsProvider(month)`
    - `salaryProvider`
    - `studentsProvider`
    - `studentLessonsProvider`
    - `studentSubscriptionsProvider`
- Replaced manual refresh groups in:
  - `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`
  - `mobile/lib/features/calendar/presentation/widgets/lesson_modal.dart`
  - `mobile/lib/features/students/presentation/widgets/schedule_builder_modal.dart`
  - `mobile/lib/features/salary/presentation/screens/salary_screen.dart`

### Salary provider cleanup

- Added `mobile/lib/features/salary/presentation/providers/salary_provider.dart`.
  - Moved `SalaryData`, `RateEntry`, `salaryProvider`, and `ratesProvider` out of `salary_screen.dart`.
  - Calendar/student widgets no longer import `salary_screen.dart` just to access `salaryProvider`.
- Removed swallowed errors from `salaryProvider` and `ratesProvider`.
  - They now surface `AsyncError` instead of returning `null` or `[]`.
- Updated `salary_screen.dart`.
  - Salary errors show `parseApiError(...)`.
  - Rates errors show an inline warning with retry.
  - Removed unused empty-card state.

### Minor cleanup

- Fixed `prefer_const_declarations` in `mobile/lib/shared/widgets/orbit_loader.dart`.

## Verification

Passed:

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot/mobile
flutter analyze --no-pub
flutter test --no-pub
flutter build macos --debug --no-pub
```

Backend syntax checked:

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
.venv/bin/python -c "import ast, pathlib; ast.parse(pathlib.Path('backend/app/routers/reports_v2.py').read_text())"
```

Note: direct `py_compile` could not write `__pycache__` due local permissions, so AST parsing was used.

## Important Repo Note

`git status` currently shows many project files as untracked, including the whole `mobile/` tree and many backend files. Because of that, avoid a broad `git add .` or mixed commit until the repo index is cleaned up.

For now, use this handoff file plus the explicit file list below.

## Files Changed In This Workstream

- `backend/app/routers/reports_v2.py`
- `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`
- `mobile/lib/features/calendar/presentation/widgets/constellation_calendar.dart`
- `mobile/lib/features/calendar/presentation/widgets/lesson_modal.dart`
- `mobile/lib/features/salary/presentation/providers/salary_provider.dart`
- `mobile/lib/features/salary/presentation/screens/salary_screen.dart`
- `mobile/lib/features/students/presentation/widgets/schedule_builder_modal.dart`
- `mobile/lib/shared/providers/data_refresh_provider.dart`
- `mobile/lib/shared/widgets/adaptive_modal.dart`
- `mobile/lib/shared/widgets/orbit_loader.dart`
- `mobile/test/widget_test.dart`

## Recommended Next Step

Continue architecture cleanup with one of these small phases:

1. Move lesson mutation calls (`status`, `makeup`, `delete`, `create`) behind repository/service methods instead of calling raw `dio` from widgets.
2. Add backend tests for `reset-month` with original lessons and makeup lessons across different months.
3. Fix repo tracking/index state so changes can be committed cleanly without mixing unrelated untracked files.
