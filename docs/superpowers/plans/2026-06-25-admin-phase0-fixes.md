# Admin Phase 0 Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the cross-teacher lesson leak and make the view-as orange frame hug the visible screen on any device.

**Architecture:** Two surgical Flutter fixes. (1) Key the `lessonsProvider` family by `(monthYear, teacherId)` so each teacher context owns its cache slot — no shared entry to bleed across teachers. (2) Extract a pure frame-rect helper that insets by `MediaQuery.viewPadding` and feed it to the view-as painter.

**Tech Stack:** Flutter, Riverpod 2.5, flutter_test. All work under `mobile/`.

> Scope note: the backend student-count bug (`reports.py` `active_students` missing the `lesson_type='regular'` filter) is intentionally NOT in this plan — it needs a Python test harness + a backend deploy and is bundled into the later backend-touching plan. This plan is pure Flutter and fully verifiable via `flutter test`.

---

### Task 1: Key lessons by teacher context (fix the leak)

**Files:**
- Modify: `mobile/lib/features/calendar/presentation/providers/calendar_provider.dart`
- Modify: `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart:50-58`
- Modify: `mobile/lib/shared/providers/data_refresh_provider.dart`
- Test: `mobile/test/features/calendar/presentation/providers/lessons_isolation_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/features/calendar/presentation/providers/lessons_isolation_test.dart`:

```dart
import 'package:cosmo_studio/features/calendar/data/calendar_repository.dart';
import 'package:cosmo_studio/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:cosmo_studio/shared/models/lesson.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRepo extends CalendarRepository {
  _RecordingRepo() : super(Dio());
  final calls = <({String monthYear, int? teacherId})>[];

  @override
  Future<List<LessonModel>> getLessons({
    required String monthYear,
    int? teacherId,
  }) async {
    calls.add((monthYear: monthYear, teacherId: teacherId));
    return const [];
  }
}

void main() {
  test('lessonsProvider keeps a separate cache entry per teacher context',
      () async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(
      overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Admin (no view-as) and teacher 7 are distinct keys → two fetches.
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: null)).future);
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: 7)).future);
    // Re-reading teacher 7 is served from cache → no third fetch.
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: 7)).future);

    expect(repo.calls, const [
      (monthYear: '2026-06', teacherId: null),
      (monthYear: '2026-06', teacherId: 7),
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/calendar/presentation/providers/lessons_isolation_test.dart`
Expected: FAIL — `lessonsProvider(...)` currently takes a `String`, so passing a record key won't compile.

- [ ] **Step 3: Re-key the family + make the wrapper synchronous**

In `mobile/lib/features/calendar/presentation/providers/calendar_provider.dart`, replace the `lessonsProvider` and `currentMonthLessonsProvider` definitions (lines 12-31) with:

```dart
// Cache key for a month of lessons in a specific teacher context. Including
// teacherId means admin/view-as never shares a cache slot with another teacher
// — eliminates the "lessons of one teacher briefly show for everyone" leak.
typedef LessonsQuery = ({String monthYear, int? teacherId});

// Lessons for a month in an explicit teacher context.
final lessonsProvider =
    FutureProvider.family<List<LessonModel>, LessonsQuery>((ref, query) async {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.getLessons(
    monthYear: query.monthYear,
    teacherId: query.teacherId,
  );
});

// Derived: lessons for the currently selected month in the current view-as
// context. Synchronous Provider (not FutureProvider) so switching teacher
// returns the new context's AsyncValue immediately instead of lingering on the
// previous teacher's data during the refetch gap.
final currentMonthLessonsProvider =
    Provider<AsyncValue<List<LessonModel>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final monthYear = DateFormat('yyyy-MM').format(month);
  final viewAs = ref.watch(viewAsTeacherProvider);
  return ref.watch(
    lessonsProvider((monthYear: monthYear, teacherId: viewAs?.id)),
  );
});
```

- [ ] **Step 4: Update the calendar screen call sites**

In `mobile/lib/features/calendar/presentation/screens/calendar_screen.dart`, ensure the view-as provider is imported (add if missing, near the other imports):

```dart
import '../../../admin/presentation/providers/view_as_teacher_provider.dart';
```

Replace lines 50-58 (the `monthYear` / `lessonsAsync` / `ref.listen` block) with:

```dart
    final month = ref.watch(selectedMonthProvider);
    final monthYear = DateFormat('yyyy-MM').format(month);
    final viewAs = ref.watch(viewAsTeacherProvider);
    final lessonsQuery = (monthYear: monthYear, teacherId: viewAs?.id);
    final lessonsAsync = ref.watch(lessonsProvider(lessonsQuery));
    final user = ref.watch(currentUserProvider);

    // ── Haptic vibration scaled by unfilled lesson count ──
    ref.listen<AsyncValue<List<LessonModel>>>(
      lessonsProvider(lessonsQuery),
```

(Leave the body of the `ref.listen` callback unchanged.)

- [ ] **Step 5: Invalidate the active teacher's entry on mutation**

In `mobile/lib/shared/providers/data_refresh_provider.dart`, add the import:

```dart
import '../../features/admin/presentation/providers/view_as_teacher_provider.dart';
```

Replace the body of `invalidateMonthData` (the loop over `months`) so it invalidates the teacher-scoped key:

```dart
  final months = <String>{monthYear, ...extraMonthYears};
  final teacherId = ref.read(viewAsTeacherProvider)?.id;
  for (final month in months) {
    ref.invalidate(lessonsProvider((monthYear: month, teacherId: teacherId)));
  }
```

(Leave the `salaryProvider` / `studentsProvider` / `studentLessonsProvider` /
`studentSubscriptionsProvider` invalidations below it unchanged.)

- [ ] **Step 6: Run the new test to verify it passes**

Run: `cd mobile && flutter test test/features/calendar/presentation/providers/lessons_isolation_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full suite to catch regressions**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass (the existing 135 + the new one).

- [ ] **Step 8: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/features/calendar/presentation/providers/calendar_provider.dart \
        mobile/lib/features/calendar/presentation/screens/calendar_screen.dart \
        mobile/lib/shared/providers/data_refresh_provider.dart \
        mobile/test/features/calendar/presentation/providers/lessons_isolation_test.dart
git commit -m "fix(calendar): key lessons cache by teacher context to stop cross-teacher leak

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 2: View-as orange frame hugs the visible screen

**Files:**
- Modify: `mobile/lib/features/admin/presentation/widgets/view_as_banner.dart`
- Test: `mobile/test/features/admin/presentation/widgets/view_as_frame_rect_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/features/admin/presentation/widgets/view_as_frame_rect_test.dart`:

```dart
import 'package:cosmo_studio/features/admin/presentation/widgets/view_as_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewAsFrameRect insets by the safe area + margin so the frame '
      'traces the visible screen on any device', () {
    const size = Size(390, 844); // iPhone logical size
    const insets = EdgeInsets.only(top: 59, bottom: 34); // notch + home bar

    final rect = viewAsFrameRect(size, insets);

    expect(rect.left, 6); // 0 + margin
    expect(rect.top, 65); // 59 + margin
    expect(rect.right, 384); // 390 - 0 - margin
    expect(rect.bottom, 804); // 844 - 34 - margin
  });

  test('viewAsFrameRect collapses to empty when insets exceed the size', () {
    final rect = viewAsFrameRect(
      const Size(40, 40),
      const EdgeInsets.all(40),
    );
    expect(rect.width <= 0 || rect.height <= 0, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/admin/presentation/widgets/view_as_frame_rect_test.dart`
Expected: FAIL — `viewAsFrameRect` is not defined.

- [ ] **Step 3: Add the pure frame-rect helper**

In `mobile/lib/features/admin/presentation/widgets/view_as_banner.dart`, add this top-level function just above the `_ViewAsFramePainter` class:

```dart
/// Rect the view-as frame traces: the full surface inset by the device safe
/// area plus a small margin, so the outline hugs the visible screen on any
/// phone (notch, Dynamic Island, home indicator) instead of a fixed offset.
@visibleForTesting
Rect viewAsFrameRect(
  Size size,
  EdgeInsets safeInsets, {
  double margin = 6.0,
}) {
  return Rect.fromLTRB(
    safeInsets.left + margin,
    safeInsets.top + margin,
    size.width - safeInsets.right - margin,
    size.height - safeInsets.bottom - margin,
  );
}
```

- [ ] **Step 4: Run the helper test to verify it passes**

Run: `cd mobile && flutter test test/features/admin/presentation/widgets/view_as_frame_rect_test.dart`
Expected: PASS.

- [ ] **Step 5: Feed safe-area insets into the painter**

In the same file, update `_ViewAsFramePainter` to take and use `safeInsets`. Replace the class with:

```dart
/// Рамка-индикатор: скруглённый контур с мягким внутренним свечением.
/// Свет рассеивается внутрь, основная линия тонкая — режим считывается
/// мгновенно, но контент остаётся нетронутым. Контур повторяет видимый
/// экран устройства (safe area), а не фиксированный отступ.
class _ViewAsFramePainter extends CustomPainter {
  final Color color;
  final EdgeInsets safeInsets;

  const _ViewAsFramePainter({required this.color, required this.safeInsets});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = viewAsFrameRect(size, safeInsets);
    if (rect.width <= 0 || rect.height <= 0) return;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(NebulaRadii.hero),
    );

    // Мягкое рассеянное свечение внутрь — широкая размытая обводка.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = color.withValues(alpha: NebulaAlpha.mist),
    );

    // Основная тонкая линия.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: NebulaAlpha.high),
    );
  }

  @override
  bool shouldRepaint(_ViewAsFramePainter old) =>
      old.color != color || old.safeInsets != safeInsets;
}
```

- [ ] **Step 6: Pass insets from the widget**

In the same file, in `ViewAsOverlay.build`, the painter is constructed inside the
first `Positioned.fill`. Replace that `CustomPaint` construction:

```dart
              child: CustomPaint(
                painter: _ViewAsFramePainter(color: tokens.warning),
              ),
```

with (the `MediaQuery` is already read above as part of `bottomOffset`; reuse it):

```dart
              child: CustomPaint(
                painter: _ViewAsFramePainter(
                  color: tokens.warning,
                  safeInsets: MediaQuery.of(context).viewPadding,
                ),
              ),
```

- [ ] **Step 7: Run analyze + full suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/features/admin/presentation/widgets/view_as_banner.dart \
        mobile/test/features/admin/presentation/widgets/view_as_frame_rect_test.dart
git commit -m "fix(admin): view-as frame insets by device safe area so it hugs any screen

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

## Verification (manual, on iPhone)

After both tasks: hot restart, enter view-as as a teacher, confirm the orange
frame sits just inside the notch/home indicator on the real device. Add lessons
in view-as, exit view-as, and confirm those lessons no longer appear in another
teacher's calendar.

## Out of scope (tracked for later plans)

- Student-count backend fix (`reports.py` `active_students` + `lesson_type='regular'`).
- Phase 1.2 (profile redesign), Phase 2 (Поиск), Phase 3 (money).
