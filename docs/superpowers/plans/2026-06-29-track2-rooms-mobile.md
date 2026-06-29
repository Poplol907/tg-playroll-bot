# Track 2 — Rooms Mobile UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the mobile UI for Track 2 classroom scheduling — a Day board (rooms × time), assign/cancel sheets, calendar scope switcher, rooms admin screen, and a teacher "today" card — against the existing data layer and API contract.

**Architecture:** Riverpod providers + repository (already built: `rooms_repository.dart`). Pure logic (teacher colors, conflict detection) lives in `util/` and is unit-tested with fakes. Widgets follow the Nebula design system (tokens only) and reuse existing shared widgets. Role gating via `currentUserProvider` (`isAdmin`/`isTeacher`).

**Tech Stack:** Flutter, flutter_riverpod, dio, intl. Tests via `flutter test`. Design system: Nebula (`spacemorphism` skill).

**References:**
- Contract: `docs/superpowers/specs/2026-06-25-track2-rooms-spec.md`
- Design: `docs/superpowers/specs/2026-06-29-track2-rooms-mobile-design.md`
- Data layer: `mobile/lib/features/rooms/data/{room_models,rooms_repository}.dart`
- Pattern refs: `mobile/lib/features/admin/presentation/widgets/set_rate_sheet.dart`, `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`

**Cross-cutting rules:**
- Nebula tokens only — no raw `fontSize` / `alpha` literals (ratchet tests in `mobile/test/architecture/` enforce this). Use `CosmoThemeTokens`, `NebulaTypography`, `NebulaRadii`, `NebulaAlpha`, `NebulaColors`.
- **Weekday mapping:** contract uses 0=Mon … 6=Sun (Python `date.weekday()`). Dart `DateTime.weekday` is 1=Mon … 7=Sun. Always convert: `contractWeekday = date.weekday - 1`.
- Times on the wire are `"HH:MM"` strings; dates `"YYYY-MM-DD"` (use `DateFormat('yyyy-MM-dd')`).
- After every mutation, invalidate `roomBlocksForDateProvider` / `roomsProvider` so the board refreshes.
- Run `cd mobile && flutter test` before each commit; keep architecture ratchet tests green.

---

### Task 1: Pure logic — teacher colors + conflict detection + board providers

**Files:**
- Create: `mobile/lib/features/rooms/presentation/util/teacher_color.dart`
- Create: `mobile/lib/features/rooms/presentation/util/block_conflicts.dart`
- Create: `mobile/lib/features/rooms/presentation/providers/room_board_providers.dart`
- Test: `mobile/test/features/rooms/teacher_color_test.dart`
- Test: `mobile/test/features/rooms/block_conflicts_test.dart`

- [ ] **Step 1: Write failing test for `block_conflicts`**

```dart
// mobile/test/features/rooms/block_conflicts_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/presentation/util/block_conflicts.dart';

ResolvedRoomBlock _b({
  required int id,
  required int roomId,
  required String start,
  required String end,
}) =>
    ResolvedRoomBlock(
      id: id,
      roomId: roomId,
      roomName: 'R$roomId',
      teacherUserId: 1,
      startTime: start,
      endTime: end,
      isRecurring: true,
    );

void main() {
  test('hhmmToMinutes parses HH:MM', () {
    expect(hhmmToMinutes('09:00'), 540);
    expect(hhmmToMinutes('09:45'), 585);
    expect(hhmmToMinutes('21:00'), 1260);
  });

  test('touching intervals in same room are NOT a conflict (half-open)', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '09:45'),
      _b(id: 2, roomId: 1, start: '09:45', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), isEmpty);
  });

  test('overlapping intervals in same room flag both ids', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '10:00'),
      _b(id: 2, roomId: 1, start: '09:30', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), {1, 2});
  });

  test('overlapping intervals in DIFFERENT rooms are not a conflict', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '10:00'),
      _b(id: 2, roomId: 2, start: '09:30', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), isEmpty);
  });

  test('three mutually overlapping blocks all flagged', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '11:00'),
      _b(id: 2, roomId: 1, start: '09:30', end: '10:00'),
      _b(id: 3, roomId: 1, start: '10:30', end: '11:30'),
    ];
    expect(conflictingBlockIds(blocks), {1, 2, 3});
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/rooms/block_conflicts_test.dart`
Expected: FAIL — `block_conflicts.dart` / `hhmmToMinutes` not found.

- [ ] **Step 3: Implement `block_conflicts.dart`**

```dart
// mobile/lib/features/rooms/presentation/util/block_conflicts.dart
import '../../data/room_models.dart';

/// Converts a wire time string ("HH:MM") to minutes since midnight.
int hhmmToMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// True if two blocks share a room and their [start, end) intervals overlap.
bool blocksConflict(ResolvedRoomBlock a, ResolvedRoomBlock b) {
  if (a.id == b.id || a.roomId != b.roomId) return false;
  final aStart = hhmmToMinutes(a.startTime), aEnd = hhmmToMinutes(a.endTime);
  final bStart = hhmmToMinutes(b.startTime), bEnd = hhmmToMinutes(b.endTime);
  return aStart < bEnd && bStart < aEnd; // half-open: touching is OK
}

/// Ids of every block that overlaps at least one other block in its room.
Set<int> conflictingBlockIds(List<ResolvedRoomBlock> blocks) {
  final ids = <int>{};
  for (var i = 0; i < blocks.length; i++) {
    for (var j = i + 1; j < blocks.length; j++) {
      if (blocksConflict(blocks[i], blocks[j])) {
        ids..add(blocks[i].id)..add(blocks[j].id);
      }
    }
  }
  return ids;
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd mobile && flutter test test/features/rooms/block_conflicts_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Write failing test for `teacher_color`**

```dart
// mobile/test/features/rooms/teacher_color_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/features/rooms/presentation/util/teacher_color.dart';

void main() {
  test('same teacher id always yields the same color', () {
    expect(teacherColor(42), teacherColor(42));
  });

  test('color is drawn from the published palette', () {
    expect(teacherColorPalette.contains(teacherColor(7)), isTrue);
  });

  test('handles negative / zero ids without throwing', () {
    expect(() => teacherColor(0), returnsNormally);
    expect(() => teacherColor(-3), returnsNormally);
  });
}
```

- [ ] **Step 6: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/rooms/teacher_color_test.dart`
Expected: FAIL — `teacher_color.dart` not found.

- [ ] **Step 7: Implement `teacher_color.dart`**

```dart
// mobile/lib/features/rooms/presentation/util/teacher_color.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/nebula_colors.dart';

/// Distinguishable, on-brand colors for teacher blocks on the room board.
const List<Color> teacherColorPalette = [
  NebulaColors.nebulaPurple,
  NebulaColors.stellarBlue,
  NebulaColors.auroraCyan,
  NebulaColors.plasmaPink,
  NebulaColors.successMint,
  NebulaColors.warningAmber,
  NebulaColors.cosmicRose,
];

/// Deterministic color for a teacher — same id maps to the same color across
/// days, so the board reads consistently.
Color teacherColor(int teacherUserId) =>
    teacherColorPalette[teacherUserId.abs() % teacherColorPalette.length];
```

- [ ] **Step 8: Run test, verify it passes**

Run: `cd mobile && flutter test test/features/rooms/teacher_color_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 9: Implement board providers**

```dart
// mobile/lib/features/rooms/presentation/providers/room_board_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which scope the calendar tab shows.
enum CalendarScope { students, rooms }

final calendarScopeProvider =
    StateProvider<CalendarScope>((_) => CalendarScope.students);

/// The day currently shown on the room board (date-only, local).
final boardDateProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Board grid geometry (09:00–21:00, 45-minute slots).
class BoardGrid {
  static const int startMinutes = 9 * 60; // 09:00
  static const int endMinutes = 21 * 60; // 21:00
  static const int slotMinutes = 45;
  static const double slotHeight = 64; // px per 45-min slot
  static const double gutterWidth = 56;
  static const double columnWidth = 128;

  static int get slotCount =>
      ((endMinutes - startMinutes) / slotMinutes).ceil();
  static double get gridHeight => slotCount * slotHeight;

  /// Vertical offset (px) for an absolute minute value.
  static double topFor(int minutes) =>
      (minutes - startMinutes) / slotMinutes * slotHeight;

  /// Contract weekday (0=Mon … 6=Sun) for a Dart DateTime.
  static int contractWeekday(DateTime d) => d.weekday - 1;
}
```

- [ ] **Step 10: Commit**

```bash
cd mobile && flutter test test/features/rooms/ && cd .. && \
git add mobile/lib/features/rooms/presentation mobile/test/features/rooms && \
git commit -m "feat(rooms): teacher colors, conflict detection, board providers

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 2: Day board grid + screen (read-only render)

**Files:**
- Create: `mobile/lib/features/rooms/presentation/widgets/room_block_tile.dart`
- Create: `mobile/lib/features/rooms/presentation/widgets/room_board_grid.dart`
- Create: `mobile/lib/features/rooms/presentation/screens/room_board_screen.dart`
- Test: `mobile/test/features/rooms/room_board_grid_test.dart`

**Responsibilities:**
- `room_block_tile.dart` — a single positioned block: teacher color fill (`teacherColor`), name + `HH:MM–HH:MM` label, red border/glow when its id is in the conflict set. Optional `onTap`.
- `room_board_grid.dart` — stateless layout: fixed left time gutter (rows every 45 min, 09:00–21:00 labels) + horizontally scrollable room columns. Each column stacks its blocks via `Positioned(top: BoardGrid.topFor(start), height: span)`. Takes `rooms`, `blocks`, `conflictIds`, `onEmptyTap(roomId, startMinutes)`, `onBlockTap(block)`.
- `room_board_screen.dart` — `ConsumerWidget`: reads `boardDateProvider`, `roomsProvider`, `roomBlocksForDateProvider`, `currentUserProvider`. Header with date + weekday, day swipe (`GestureDetector` horizontal drag → ±1 day) and arrows. Admin → wires empty/block taps (Task 3); teacher → taps disabled (read-only). Loading → `OrbitLoader`; error → `AppErrorCard`.

- [ ] **Step 1: Write failing widget test for the grid**

```dart
// mobile/test/features/rooms/room_board_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/room_board_grid.dart';

void main() {
  testWidgets('renders a tile for each block with teacher + time label',
      (tester) async {
    final rooms = [
      const Room(id: 1, name: 'Зал A', sortOrder: 0, isActive: true),
    ];
    final blocks = [
      const ResolvedRoomBlock(
        id: 10,
        roomId: 1,
        roomName: 'Зал A',
        teacherUserId: 3,
        teacherName: 'Иван',
        startTime: '09:00',
        endTime: '09:45',
        isRecurring: true,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: RoomBoardGrid(
          rooms: rooms,
          blocks: blocks,
          conflictIds: const {},
          onEmptyTap: (_, __) {},
          onBlockTap: (_) {},
        ),
      ),
    ));
    expect(find.text('Иван'), findsOneWidget);
    expect(find.textContaining('09:00'), findsWidgets);
    expect(find.text('Зал A'), findsWidgets); // column header
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/rooms/room_board_grid_test.dart`
Expected: FAIL — `room_board_grid.dart` not found.

- [ ] **Step 3: Implement `room_block_tile.dart`**

Build a tile widget: container with `color = teacherColor(block.teacherUserId).withValues(alpha: NebulaAlpha.surface)`, `borderRadius: NebulaRadii.cardBorder` (use the existing radius role), border `NebulaColors.errorRose` when `isConflict`. Label: `Text(block.teacherName ?? '—', style: type.labelM…)` + time range `Text('${block.startTime}–${block.endTime}', style: type.bodyS…)` with `fontFeatures: [FontFeature.tabularFigures()]`. Wrap in `GestureDetector(onTap: onTap)` with a `scale(0.96)` press feedback (`AnimatedScale`). Follow `set_rate_sheet.dart` for token usage; consult `spacemorphism` for surface treatment.

- [ ] **Step 4: Implement `room_board_grid.dart`**

`Row(children: [ _TimeGutter(), Expanded(SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(room columns))) ])`. Time gutter: `Column` of `BoardGrid.slotCount` labels, each `SizedBox(height: BoardGrid.slotHeight)` showing the slot's `HH:MM`. Each room column: width `BoardGrid.columnWidth`, header = room name, body = `SizedBox(height: BoardGrid.gridHeight, child: Stack(children: [ ...empty-tap hit cells per slot..., ...positioned RoomBlockTile per block ]))`. Block position: `top = BoardGrid.topFor(hhmmToMinutes(b.startTime))`, `height = (hhmmToMinutes(b.endTime) - hhmmToMinutes(b.startTime)) / BoardGrid.slotMinutes * BoardGrid.slotHeight`. Empty cells call `onEmptyTap(room.id, slotStartMinutes)`; ensure hit area ≥44 (slotHeight=64 satisfies this). Import `block_conflicts.dart` for `hhmmToMinutes`.

- [ ] **Step 5: Run test, verify it passes**

Run: `cd mobile && flutter test test/features/rooms/room_board_grid_test.dart`
Expected: PASS.

- [ ] **Step 6: Implement `room_board_screen.dart`**

`ConsumerWidget` reading `boardDateProvider`. Compute `dateYmd = DateFormat('yyyy-MM-dd').format(date)`. Watch `roomsProvider` and `roomBlocksForDateProvider((date: dateYmd, teacherId: user.isTeacher ? user.id : null))`. Combine async states; compute `conflictIds = conflictingBlockIds(blocks)`. Render header (date + weekday via `DateFormat('EEEE, d MMMM', 'ru')`), prev/next arrows mutating `boardDateProvider`, and a `GestureDetector(onHorizontalDragEnd …)` for swipe. Pass `onEmptyTap`/`onBlockTap` only when `user.isAdmin` (else no-op). Loading → `OrbitLoader`, error → `AppErrorCard` with retry that invalidates the providers.

- [ ] **Step 7: Run full rooms tests + analyze**

Run: `cd mobile && flutter test test/features/rooms/ && flutter analyze lib/features/rooms`
Expected: PASS, no analyzer errors.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/rooms mobile/test/features/rooms && \
git commit -m "feat(rooms): day board grid + screen (read-only render)

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 3: Assign + block-actions sheets (admin mutations)

**Files:**
- Create: `mobile/lib/features/rooms/presentation/widgets/assign_block_sheet.dart`
- Create: `mobile/lib/features/rooms/presentation/widgets/block_actions_sheet.dart`
- Modify: `mobile/lib/features/rooms/presentation/screens/room_board_screen.dart` (wire taps)
- Test: `mobile/test/features/rooms/assign_block_sheet_test.dart`

**Responsibilities:**
- `assign_block_sheet.dart` — `ConsumerStatefulWidget` + `static Future<bool> show(context, {roomId, roomName, initialStartMinutes, date})` via `MistModal.show` (mirror `set_rate_sheet.dart`). Fields: teacher picker (from `orgUsersProvider`, filter `role=='TEACHER'`, show `displayName`); start time + end time (`showTimePicker` or `nebula_drum_picker`; default end = start + 45 min); recurrence toggle (`Разовый` / `Каждую неделю`, default recurring); optional note (`NebulaInput`). Validate end > start. Submit: if recurring → `createBlock(roomId, teacherUserId, start, end, weekday: BoardGrid.contractWeekday(date), note:)`; else → `createBlock(... specificDate: DateFormat('yyyy-MM-dd').format(date) ...)`. On success: haptic, `NebulaSnackbar`, `Navigator.pop(context, true)`.
- `block_actions_sheet.dart` — `ConsumerStatefulWidget` + `static Future<bool> show(...)`. Shows block details. If `block.isRecurring`: «Отменить в этот день» → `cancelBlock(block.id, dateYmd)`; «Удалить совсем» → `deleteBlock(block.id)`. Else (one-off): «Удалить» → `deleteBlock(block.id)`. Destructive confirm via `nebula_dialog`. On success: pop `true`.
- Screen wiring: `onEmptyTap` → show assign sheet; `onBlockTap` → show actions sheet; when either returns `true`, `ref.invalidate(roomBlocksForDateProvider(...))`.

- [ ] **Step 1: Write failing widget test for assign-sheet validation**

```dart
// mobile/test/features/rooms/assign_block_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/assign_block_sheet.dart';

void main() {
  testWidgets('assign sheet shows teacher field and a save action',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AssignBlockSheet(
            roomId: 1,
            roomName: 'Зал A',
            date: DateTime(2026, 6, 29),
            initialStartMinutes: 540,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('Зал A'), findsWidgets);
    expect(find.textContaining('Назначить'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/rooms/assign_block_sheet_test.dart`
Expected: FAIL — `assign_block_sheet.dart` not found.

- [ ] **Step 3: Implement `assign_block_sheet.dart`** (per responsibilities above; mirror `set_rate_sheet.dart` structure, tokens, error handling via `parseApiError`).

- [ ] **Step 4: Run test, verify it passes**

Run: `cd mobile && flutter test test/features/rooms/assign_block_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Implement `block_actions_sheet.dart`** (per responsibilities; recurring vs one-off branches, `nebula_dialog` confirm).

- [ ] **Step 6: Wire taps in `room_board_screen.dart`** — `onEmptyTap`/`onBlockTap` call the sheets and invalidate on `true`.

- [ ] **Step 7: Run rooms tests + analyze**

Run: `cd mobile && flutter test test/features/rooms/ && flutter analyze lib/features/rooms`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/rooms mobile/test/features/rooms && \
git commit -m "feat(rooms): assign + block-actions sheets wired to board

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 4: Calendar [Ученики | Кабинеты] scope switcher + role gating

**Files:**
- Modify: `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`
- Test: `mobile/test/features/calendar/calendar_scope_switcher_test.dart`

**Responsibilities:**
- Add a `NebulaSegmentedControl(segments: ['Ученики', 'Кабинеты'], selectedIndex: scope.index, onChanged: …)` at the top of the calendar body, backed by `calendarScopeProvider`.
- `CalendarScope.students` → the existing calendar content (unchanged) + `RoomsTodayCard` on top for teachers (added in Task 6 — leave a `// TODO(task6)` placeholder slot only if Task 6 not yet merged; otherwise include it).
- `CalendarScope.rooms` → `RoomBoardScreen`.
- Keep both desktop and mobile layouts working (the screen branches on `AppPlatform.isDesktop`).

- [ ] **Step 1: Write failing widget test**

```dart
// mobile/test/features/calendar/calendar_scope_switcher_test.dart
// Pump CalendarScreen inside ProviderScope with a fake auth/lessons override,
// expect both segment labels present, tap 'Кабинеты', expect the board header
// (date/weekday) to appear. (Mirror existing calendar tests for provider
// overrides — see test/features/calendar/.)
```

Fill this in by following the override pattern already used in `test/features/calendar/`. Assert: `find.text('Ученики')` and `find.text('Кабинеты')` both found; after `tester.tap(find.text('Кабинеты'))` + `pump`, a board-only element is shown.

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/calendar/calendar_scope_switcher_test.dart`
Expected: FAIL — switcher not present.

- [ ] **Step 3: Implement the switcher + routing in `calendar_screen.dart`.**

- [ ] **Step 4: Run test + full calendar suite + analyze**

Run: `cd mobile && flutter test test/features/calendar/ && flutter analyze lib/features/calendar`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/calendar mobile/test/features/calendar && \
git commit -m "feat(rooms): calendar Ученики/Кабинеты scope switcher

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 5: Rooms admin screen (list + add/rename/archive)

**Files:**
- Create: `mobile/lib/features/rooms/presentation/screens/rooms_admin_screen.dart`
- Create: `mobile/lib/features/rooms/presentation/widgets/room_edit_sheet.dart`
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart` (entry point)
- Test: `mobile/test/features/rooms/rooms_admin_screen_test.dart`

**Responsibilities:**
- `room_edit_sheet.dart` — add/rename sheet (mirror `set_rate_sheet.dart`): `NebulaInput` for name + `StellarButton`. `static Future<bool> show(context, {Room? existing})`. Create → `createRoom(name)`; rename → `updateRoom(id, name:)`.
- `rooms_admin_screen.dart` — `ConsumerWidget` over `roomsProvider`. List rooms (name, ordered). "Добавить кабинет" button → `room_edit_sheet`. Tap row → rename. Archive via swipe/`jiggle_delete_wrapper` → `updateRoom(id, isActive: false)` with `nebula_dialog` confirm. A toggle "Показать архивные" switches to `roomsRepositoryProvider.getRooms(includeInactive: true)` (use a local `FutureProvider` or `StateProvider<bool>` + watch). Invalidate `roomsProvider` after mutations. Loading/error via `OrbitLoader`/`AppErrorCard`.
- `admin_screen.dart` — add a navigation entry "Кабинеты" that pushes `RoomsAdminScreen` (follow existing nav-row pattern in that file).

- [ ] **Step 1: Write failing widget test** — pump `RoomsAdminScreen` in `ProviderScope` overriding `roomsProvider` with two fake rooms; expect both names and an "Добавить" affordance present.

- [ ] **Step 2: Run test, verify it fails**

Run: `cd mobile && flutter test test/features/rooms/rooms_admin_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `room_edit_sheet.dart`.**
- [ ] **Step 4: Implement `rooms_admin_screen.dart`.**
- [ ] **Step 5: Run test, verify it passes.**

Run: `cd mobile && flutter test test/features/rooms/rooms_admin_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Add entry point in `admin_screen.dart`.**
- [ ] **Step 7: Run rooms suite + analyze.**

Run: `cd mobile && flutter test test/features/rooms/ && flutter analyze lib/features/rooms lib/features/admin`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/rooms mobile/lib/features/admin mobile/test/features/rooms && \
git commit -m "feat(rooms): admin rooms management screen

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 6: Teacher "Мои кабинеты сегодня" card

**Files:**
- Create: `mobile/lib/features/rooms/presentation/widgets/rooms_today_card.dart`
- Modify: `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart` (show card for teachers in Ученики scope)
- Test: `mobile/test/features/rooms/rooms_today_card_test.dart`

**Responsibilities:**
- `rooms_today_card.dart` — `ConsumerWidget`. Reads `currentUserProvider`; if not a teacher, renders `SizedBox.shrink()`. Else watches `roomBlocksForDateProvider((date: todayYmd, teacherId: user.id))`. Renders a `NebulaSurface` titled "Мои кабинеты сегодня" listing each block as `room_name · HH:MM–HH:MM` (tabular figures). Empty → "Сегодня кабинеты не назначены". Loading → small inline loader; error → compact retry.
- `calendar_screen.dart` — in `CalendarScope.students`, render `RoomsTodayCard()` above the calendar for teachers (replace the Task 4 placeholder if one was left).

- [ ] **Step 1: Write failing widget test** — override `currentUserProvider` (teacher) + `roomBlocksForDateProvider` with one fake block; expect the title and the block's room name + time.

- [ ] **Step 2: Run test, verify it fails.**

Run: `cd mobile && flutter test test/features/rooms/rooms_today_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `rooms_today_card.dart`.**
- [ ] **Step 4: Run test, verify it passes.**

Run: `cd mobile && flutter test test/features/rooms/rooms_today_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the card into the calendar Ученики scope for teachers.**
- [ ] **Step 6: Run full suite + analyze.**

Run: `cd mobile && flutter test && flutter analyze`
Expected: PASS (whole suite incl. architecture ratchet tests green).

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/rooms mobile/lib/features/calendar mobile/test/features/rooms && \
git commit -m "feat(rooms): teacher 'Мои кабинеты сегодня' card

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

## Final verification (after Task 6)

- [ ] `cd mobile && flutter test` — entire suite green (incl. `test/architecture/`).
- [ ] `cd mobile && flutter analyze` — no errors.
- [ ] Manual smoke on device/simulator once backend is deployed (Task 1 of the session): switch Ученики/Кабинеты, assign a recurring + a one-off block, verify conflict highlight on overlap, cancel a recurring on one day, delete a one-off, archive a room, view teacher "today" card as a teacher account.
- [ ] Merge `feature/rooms-mobile` → `main`, push.

## Notes for the implementer
- The data layer and its 167 tests already exist and pass — do **not** rewrite them.
- Verify exact reusable APIs against the reference files before inventing new ones (`MistModal.show`, `NebulaSnackbar`, `nebula_dialog`, `nebula_drum_picker`, `AppCustomScrollView`).
- UI polish (scale-on-press, concentric radii, tabular numbers, staggered enters, ≥44 hit areas) follows the `make-interfaces-feel-better` skill principles, translated to Flutter — apply lightly now, deep polish is a later phase.
