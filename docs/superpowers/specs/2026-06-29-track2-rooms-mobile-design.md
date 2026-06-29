# Track 2 — Rooms Mobile UI — Design

- **Date:** 2026-06-29
- **Status:** Design approved (build phase).
- **Builds on:** `docs/superpowers/specs/2026-06-25-track2-rooms-spec.md` (the API contract — single source of truth). This doc covers only the **mobile UI** layer.
- **Branch:** `feature/rooms-mobile` (data layer already merged into the branch: `room_models.dart`, `rooms_repository.dart` with `roomsProvider` / `roomBlocksForDateProvider`).

## Product decisions (locked)

- **Board time grid:** 09:00–21:00, lesson step **45 min** (rows at 09:00, 09:45, 10:30 … 21:00).
- **Assign:** start + end via time pickers (default duration 45 min).
- **Recurrence:** toggle Разовый / Каждую неделю; default **Каждую неделю** (recurring weekday).
- **Block colors:** deterministic per teacher (hash `teacher_id` → Nebula palette). One teacher = one color across all days.
- **No edit:** block actions are delete / cancel only; re-assign is manual (tap an empty cell again). The contract has no PATCH for blocks, so we do not implement edit-as-recreate in v1.

## Design system constraints

- Nebula only — tokens via `CosmoThemeTokens` / `NebulaTypography` / `NebulaRadii` / `NebulaAlpha`. No raw `fontSize` / `alpha` (ratchet tests in `mobile/test/architecture/` enforce this).
- Reuse: `NebulaSurface`, `StellarButton`, `MistModal.show`, `NebulaInput`, `NebulaSegmentedControl`, `AppScreenHeader`, `AppCustomScrollView`, `OrbitLoader`, `AppErrorCard`, `nebula_snackbar`, `jiggle_delete_wrapper`.
- Repository / provider pattern mirrors `features/admin/data/rates_repository.dart` and the existing `rooms_repository.dart`. Admin sheets mirror `set_rate_sheet.dart` (ConsumerStatefulWidget + `MistModal.show` + `parseApiError`).

## Feature structure

```
features/rooms/
  data/                          ← exists
    room_models.dart
    rooms_repository.dart
  presentation/
    screens/
      room_board_screen.dart     — Day board (rooms × time)
      rooms_admin_screen.dart    — manage rooms (admin)
    widgets/
      room_board_grid.dart       — time gutter + room columns + positioned blocks
      room_block_tile.dart       — one colored teacher block
      assign_block_sheet.dart    — tap empty cell → create (POST /room-blocks)
      block_actions_sheet.dart   — tap block → cancel / delete
      rooms_today_card.dart      — "Мои кабинеты сегодня" (teacher)
    providers/
      room_board_providers.dart  — selected board date + calendar scope
    util/
      teacher_color.dart         — teacher_id → Nebula color (deterministic)
      block_conflicts.dart       — client-side overlap detection per room
```

## Components

### Day board (`room_board_screen` + `room_board_grid`)
- **Header:** date + weekday; swipe left/right = previous/next day; arrows on desktop.
- **Body:** horizontal scroll. Fixed left time gutter (09:00–21:00, 45-min rows). Rooms = columns (only `is_active`, ordered by `sort_order`, from `roomsProvider`). Blocks from `roomBlocksForDateProvider((date, teacherId))` positioned by absolute minute offset from 09:00 → `top` / `height`. Tile color = teacher color, label = teacher name + time range.
- **Conflicts:** computed client-side (`block_conflicts`): same `room_id`, overlapping `[start_time, end_time)`. Conflicting tiles get a red border/glow. Pure function, unit-tested.
- **Interactions (admin):** tap empty cell → `assign_block_sheet` (room from column, start from row); tap block → `block_actions_sheet`.
- **Interactions (teacher):** read-only board auto-filtered to self (server forces `teacher_id = self`); no assign/cancel.

### `assign_block_sheet`
Fields: teacher (picker over org teachers), start time, end time (default +45 min), recurrence toggle (default Каждую неделю → sends `weekday` from the date; Разовый → sends `specific_date`), optional note. Validates end > start. On submit → `createBlock(...)`, invalidate `roomBlocksForDateProvider`, haptic + snackbar.

### `block_actions_sheet`
Shows block details. one-off → «Удалить» (`deleteBlock`). recurring → «Отменить в этот день» (`cancelBlock(id, date)`) + «Удалить совсем» (`deleteBlock`). Confirm destructive via `nebula_dialog`. Invalidate provider after.

### Calendar integration
- `calendar_screen` gets `NebulaSegmentedControl [Ученики | Кабинеты]` at top, backed by a scope provider in `room_board_providers`.
- **Ученики** = existing `ConstellationCalendar` (+ for teachers, `rooms_today_card` on top).
- **Кабинеты** = `room_board_screen` (admin interactive, teacher read-only).

### `rooms_today_card` (teacher)
Compact card: today's blocks for the teacher via `roomBlocksForDateProvider((today, teacherId: self))`. Each row = room name + time. Empty state = "Сегодня кабинеты не назначены". Shown at top of the Ученики scope for teacher role.

### `rooms_admin_screen` (admin)
List from `roomsProvider`. Add (sheet like `set_rate_sheet`: `NebulaInput` + `StellarButton` → `createRoom`). Rename (`updateRoom(name:)`). Archive (`updateRoom(isActive:false)` via swipe/`jiggle_delete_wrapper`); toggle to show archived (`getRooms(includeInactive:true)`). Entry point from `admin_screen`.

## Role gating
- Admin vs teacher resolved from `currentUserProvider` (verify role field during impl). Admin: full board + assign + rooms admin. Teacher: read-only board + today card.

## Testing
- Unit-test pure logic with fakes: `teacher_color` (stable mapping), `block_conflicts` (overlap edge cases: touching `[start,end)` not a conflict, nested, partial). Repository already contract-verified (167 tests).
- Architecture ratchet tests must stay green (no raw fontSize/alpha).
- Widget tests where practical for grid positioning and sheet validation.

## Build order (subagent-driven, review between tasks)
1. `util/` (`teacher_color`, `block_conflicts`) + `room_board_providers` + unit tests.
2. `room_board_grid` + `room_board_screen` (render + conflicts + day swipe), read-only.
3. `assign_block_sheet` + `block_actions_sheet`, wired to repo.
4. Calendar `[Ученики | Кабинеты]` segmented control + routing + role gating.
5. `rooms_admin_screen` + entry from `admin_screen`.
6. `rooms_today_card` (teacher).

Each task: implement → spec-review → code-review before the next.

## Out of scope (v1)
- Edit block (delete+recreate). Drag-to-move. Month/week zoom. Auto-linking lessons to rooms.

## Follow-ups (after user review of v1)
- Big Nebula design-system refactor (outdated / diverges from current design).
- Security review (mobile Track 2 + rooms backend).
