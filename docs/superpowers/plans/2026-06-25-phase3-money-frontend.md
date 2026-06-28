# Phase 3 «Деньги» (frontend trio, minus payouts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (project default — CLAUDE.md). One implementer per task, then spec + code-quality review. Steps use `- [ ]`.

**Goal:** Two admin money features, frontend-only (backend already supports both): (3.1) view/set a teacher's per-lesson rate on the profile screen; (3.3) export a monthly payout summary via the native share sheet. Partial payouts (3.2, new backend table) and month-reset (3.4, destructive) are intentionally OUT (deferred / dropped per product decision).

**Tech Stack:** Flutter, Riverpod, Dio, share_plus (new dep), flutter_test. Branch `feature/phase3-money` off `main`.

**Backend (already exists, no changes):**
- `GET /rates/teacher/{id}` → `{ teacher_user_id, teacher_name, rates: [...], default_rate: int }` (default_rate = the no-instrument fallback per-lesson rate).
- `POST /rates/teacher/{id}` body `RateCreateIn { teacher_user_id:int, instrument_id:int?=null, is_foreign:bool=false, rate_per_lesson:int, effective_from:"YYYY-MM-DD", note:str?=null }` → sets a new rate (admin only; history preserved).

---

### Task 1: Teacher per-lesson rate — view + set on the profile screen

**Files:**
- Create: `mobile/lib/features/admin/data/rates_repository.dart`
- Create: `mobile/lib/features/admin/presentation/widgets/set_rate_sheet.dart`
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart` (the `_TeacherProfileScreen` body — add a "Ставка за урок" section)
- Test: `mobile/test/features/admin/data/rates_repository_test.dart`

- [ ] **Step 1: Rates repository + provider** — create `rates_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Admin-side teacher per-lesson rate access.
class RatesRepository {
  final Dio _dio;
  RatesRepository(this._dio);

  /// Current default (no-instrument) per-lesson rate for a teacher, in whole
  /// currency units. Returns 0 if none set.
  Future<int> getDefaultRate(int teacherId) async {
    final r = await _dio.get('/rates/teacher/$teacherId');
    return (r.data['default_rate'] as int?) ?? 0;
  }

  /// Sets a new default per-lesson rate effective today. History is preserved
  /// server-side.
  Future<void> setDefaultRate(int teacherId, int ratePerLesson) async {
    final today = DateTime.now();
    final ymd =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _dio.post('/rates/teacher/$teacherId', data: {
      'teacher_user_id': teacherId,
      'instrument_id': null,
      'is_foreign': false,
      'rate_per_lesson': ratePerLesson,
      'effective_from': ymd,
    });
  }
}

final ratesRepositoryProvider = Provider<RatesRepository>(
  (ref) => RatesRepository(ref.watch(dioProvider)),
);

/// Current default rate for a teacher (family by teacher id).
final teacherDefaultRateProvider =
    FutureProvider.family<int, int>((ref, teacherId) async {
  return ref.watch(ratesRepositoryProvider).getDefaultRate(teacherId);
});
```

(Confirm `dioProvider` lives in `core/network/api_client.dart` — `admin_repository.dart` imports it from there. Match that import path.)

- [ ] **Step 2: Write the failing repository test** — `rates_repository_test.dart`: use a `Dio` with a `MockAdapter`/`DioAdapter` if the project has one, OR a simple fake `Dio` subclass that records the POST and returns a canned GET. Simplest: a fake that overrides `get`/`post`. Assert `getDefaultRate` parses `default_rate`, and `setDefaultRate` POSTs `rate_per_lesson` + an `effective_from` of today's date in YYYY-MM-DD. Check how existing repo tests construct a Dio (look for any `*_repository_test.dart` or `lessons_isolation_test.dart`'s `_RecordingRepo extends ... super(Dio())` pattern) and follow it. Run, confirm FAIL.

- [ ] **Step 3: SetRateSheet** — create `set_rate_sheet.dart`: a `NebulaModalSurface`-based bottom sheet (use `MistModal.show` or the existing sheet pattern from `set_password_sheet.dart` — READ that file and mirror its structure) with a numeric `NebulaInput`/`TextField` for the new rate (prefill with current), a save button calling `ratesRepositoryProvider.setDefaultRate`, returning `true` on success. Show a `NebulaSnackbar` on error. Title 'Ставка за урок'.

- [ ] **Step 4: Profile rate section** — in `_TeacherProfileScreen.build` (admin_screen.dart), between the payout island and the "Открыть как педагог" button, add a NebulaSurface row (mirror the payout island style) labelled 'Ставка за урок' showing `ref.watch(teacherDefaultRateProvider(user.id))` formatted via `Money.format(rate)` (with OrbitLoader while loading), and a trailing "Изменить" `NebulaTextButton`/icon that opens `SetRateSheet.show(context, user.id, currentRate)`; on success, `ref.invalidate(teacherDefaultRateProvider(user.id))`.

- [ ] **Step 5: Run the repo test → PASS. `flutter analyze && flutter test` clean + all pass.**

- [ ] **Step 6: Commit** scoped to the 4 files. Message: `feat(admin): view & set teacher per-lesson rate on the profile` + Co-Authored-By trailer.

---

### Task 2: Export monthly payout summary via share

**Files:**
- Modify: `mobile/pubspec.yaml` (add share_plus via `flutter pub add share_plus`)
- Create: `mobile/lib/features/admin/presentation/payout_summary.dart` (pure text builder)
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart` (Студия header — add a share action)
- Test: `mobile/test/features/admin/presentation/payout_summary_test.dart`

- [ ] **Step 1: Add the dependency** — run `cd mobile && flutter pub add share_plus` (let it pick a compatible version). Verify `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing pure-function test** — `payout_summary_test.dart`:

```dart
import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/payout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildPayoutSummary lists each teacher with payout + a studio total',
      () {
    const stats = StudioStats(
      month: '2026-06',
      totalLessonsDone: 20,
      totalLessonsMissed: 0,
      totalLessonsCancelled: 0,
      totalLessonsScheduled: 0,
      activeStudents: 5,
      activeTeachers: 2,
      teachers: [
        TeacherStats(
          teacherId: 1,
          teacherName: 'Аня',
          lessonsDone: 12,
          lessonsMissed: 0,
          lessonsDebt: 0,
          lessonsCancelledMakeup: 0,
          totalAmount: 48000,
        ),
        TeacherStats(
          teacherId: 2,
          teacherName: 'Олег',
          lessonsDone: 8,
          lessonsMissed: 0,
          lessonsDebt: 0,
          lessonsCancelledMakeup: 0,
          totalAmount: 32000,
        ),
      ],
    );

    final text = buildPayoutSummary(stats);

    expect(text, contains('2026-06'));
    expect(text, contains('Аня'));
    expect(text, contains('Олег'));
    expect(text, contains('48')); // 48 000 сум
    expect(text, contains('80')); // total 80 000
  });
}
```

- [ ] **Step 3: Run it, confirm FAIL** (`payout_summary.dart` missing).

- [ ] **Step 4: Implement** `payout_summary.dart`:

```dart
import '../../../core/money/currency.dart';
import '../data/admin_repository.dart';

/// Plain-text monthly payout summary for sharing with an accountant.
String buildPayoutSummary(StudioStats stats) {
  final lines = <String>[
    'Выплаты студии — ${stats.month}',
    '',
  ];
  for (final t in stats.teachers) {
    lines.add(
        '${t.teacherName}: ${Money.format(t.totalAmount)} (${t.lessonsDone} уроков)');
  }
  lines
    ..add('')
    ..add('Итого: ${Money.format(stats.totalAmount)}');
  return lines.join('\n');
}
```

- [ ] **Step 5: Wire the share action** — in `AdminScreen.build`, make the header `trailing` a `Row(mainAxisSize: MainAxisSize.min, children: [shareButton, addUserButton])`. The share button is an `IconButton(icon: Icon(Icons.ios_share_rounded / Icons.share_outlined), tooltip: 'Экспорт выплат', onPressed: ...)` that reads `statsAsync.valueOrNull`; if non-null, calls `Share.share(buildPayoutSummary(stats))` (import `package:share_plus/share_plus.dart`); if stats not loaded, show a NebulaSnackbar 'Статистика ещё загружается'. (AppScreenHeader.trailing has a maxWidth ~132 — two icon buttons fit.)

- [ ] **Step 6: Run the test → PASS. `flutter analyze && flutter test` clean + all pass.**

- [ ] **Step 7: Commit** scoped to pubspec.yaml, pubspec.lock, payout_summary.dart, admin_screen.dart, the test. Message: `feat(admin): export monthly payout summary via share` + Co-Authored-By trailer.

---

## Self-review (after both)
- Profile shows the teacher's per-lesson rate; "Изменить" sets a new rate and the displayed value refreshes.
- Студия header has a share action that opens the OS share sheet with the per-teacher payout summary + total.
- `flutter analyze` clean; full suite green.

## Out of scope
- 3.2 partial payouts (new backend `payout` table — needs a one-time prod CREATE TABLE since no Alembic). Separate effort.
- 3.4 month-reset button (the reset-month endpoint deletes lessons+subscriptions — too destructive to expose). Dropped.
