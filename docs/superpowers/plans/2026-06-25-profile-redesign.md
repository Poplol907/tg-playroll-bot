# Teacher Profile Redesign Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (the project default — see CLAUDE.md). One implementer subagent per task, then spec + code-quality review. Steps use checkbox (`- [ ]`).

**Goal:** Turn the cramped teacher-profile `Dialog` into a full-screen route with breathing room: app background + `AppScreenHeader`, an identity card, a 2×2 month-stats grid, the payout island, and clearly sectioned actions (primary view-as, secondary password/disable, divider, destructive delete).

**Architecture:** Replace `_TeacherProfileDialog` (a `Dialog` wrapping `NebulaModalSurface`) with `_TeacherProfileScreen` (a `Scaffold` → `AppBackgroundHost` → `SafeArea` → `AppScreenHeader` + scrollable sectioned body), opened via `Navigator.push(SpacePageRoute(...))` instead of `showDialog`. Money already formats via `Money.format`. Reuse the existing payout island, action buttons, `_DialogStatRow`, and the `_confirmAndDisable`/`_confirmAndDelete` helpers (with navigation adjusted for a pushed route).

**Tech Stack:** Flutter, Riverpod, go_router, flutter_test. All under `mobile/`. Branch `feature/profile-redesign` off `main`.

**File:** everything is in `mobile/lib/features/admin/presentation/screens/admin_screen.dart`. Imports already present in that file: `AppScreenHeader` (app_screen_header.dart), `SpacePageRoute` (space_page_transition.dart), `go_router`, `Money` (currency.dart), `NebulaSurface`, `NebulaTextButton`, `NebulaColors`, `NebulaAlpha`, `NebulaRadii`. You must ADD one import: `AppBackgroundHost`.

---

### Task 1: Profile dialog → full-screen route

**Files:**
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart`
- Test: `mobile/test/features/admin/presentation/teacher_profile_screen_test.dart`

- [ ] **Step 1: Write the failing test** — create `mobile/test/features/admin/presentation/teacher_profile_screen_test.dart`:

```dart
import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
      'tapping a teacher opens a full-screen profile (not a Dialog) with the '
      'key sections and actions', (tester) async {
    final user = OrgUser(
      id: 7,
      login: 'anya',
      role: 'TEACHER',
      teacherName: 'Аня Петрова',
      hasPassword: true,
    );
    final stats = TeacherStats(
      teacherId: 7,
      teacherName: 'Аня Петрова',
      lessonsDone: 12,
      lessonsMissed: 2,
      lessonsCancelledMakeup: 1,
      lessonsDebt: 0,
      totalAmount: 48000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TeacherProfileEntry.button(
                context: context,
                user: user,
                stats: stats,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-profile'));
    // NOT pumpAndSettle: the app background (AppBackgroundHost) runs an ambient
    // animation that never settles. Pump once to start the push, then advance
    // past the SpacePageRoute transition with a fixed duration.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // It is a pushed screen, not a Dialog.
    expect(find.byType(Dialog), findsNothing);
    // Key content + actions are present.
    expect(find.text('Аня Петрова'), findsWidgets);
    expect(find.text('К выплате'), findsOneWidget);
    expect(find.textContaining('48'), findsWidgets); // 48 000 сум
    expect(find.text('Открыть как педагог'), findsOneWidget);
    expect(find.text('Удалить навсегда'), findsOneWidget);
  });
}
```

Note: this test needs a tiny public test seam. In Step 3 you will add a small
`TeacherProfileEntry` helper with a `button(...)` that renders a button labelled
`open-profile` which pushes the profile screen — so the test can drive the real
navigation without depending on the private `_TeacherTile`.

- [ ] **Step 2: Run the test, confirm it fails**

Run: `cd mobile && flutter test test/features/admin/presentation/teacher_profile_screen_test.dart`
Expected: FAIL — `TeacherProfileEntry` undefined.

- [ ] **Step 3: Build the full-screen profile + navigation seam**

In `mobile/lib/features/admin/presentation/screens/admin_screen.dart`:

(a) Add the import near the other shared-widget imports:
```dart
import '../../../../shared/widgets/app_background_host.dart';
```

(b) Replace the `_openProfile` method on `_TeacherTile` (currently using `showDialog`) with a push:
```dart
  void _openProfile(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    TeacherProfileEntry.open(
      context,
      user: user,
      stats: stats,
      onUpdated: onUpdated,
    );
  }
```

(c) Add a small public entry helper (test seam + single push point), just above
`_TeacherProfileScreen`:
```dart
/// Opens the full-screen teacher profile. Public so tests can drive the real
/// navigation without reaching into private tile internals.
abstract final class TeacherProfileEntry {
  static void open(
    BuildContext context, {
    required OrgUser user,
    required TeacherStats? stats,
    required VoidCallback onUpdated,
  }) {
    Navigator.of(context).push(
      SpacePageRoute(
        builder: (_) => _TeacherProfileScreen(
          user: user,
          stats: stats,
          onUpdated: onUpdated,
        ),
      ),
    );
  }

  /// Test-only convenience: a button that opens the profile with a no-op
  /// onUpdated. Labelled "open-profile".
  @visibleForTesting
  static Widget button({
    required BuildContext context,
    required OrgUser user,
    required TeacherStats? stats,
  }) {
    return ElevatedButton(
      onPressed: () => open(context, user: user, stats: stats, onUpdated: () {}),
      child: const Text('open-profile'),
    );
  }
}
```
(Add `import 'package:flutter/foundation.dart';` if `@visibleForTesting` is not
already available — `material.dart` re-exports it, so it should be.)

(d) Replace the entire `_TeacherProfileDialog` class with `_TeacherProfileScreen`
below. It REUSES the existing payout island, action buttons, and the
`_confirmAndDisable` / `_confirmAndDelete` helpers (kept as methods on the new
class), with navigation adjusted for a pushed route:

```dart
class _TeacherProfileScreen extends ConsumerWidget {
  final OrgUser user;
  final TeacherStats? stats;
  final VoidCallback onUpdated;

  const _TeacherProfileScreen({
    required this.user,
    required this.stats,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundHost(
        interactive: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppScreenHeader(
                  title: user.displayName,
                  subtitle: '@${user.login}',
                  leading: IconButton(
                    tooltip: 'Назад',
                    onPressed: () => Navigator.pop(context),
                    icon:
                        Icon(Icons.arrow_back_rounded, color: tokens.mutedText),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Identity card ──
                      NebulaSurface(
                        dense: true,
                        radiusRole: NebulaRadiusRole.card,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: NebulaColors.stellarBlue
                                    .withValues(alpha: NebulaAlpha.surface),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: NebulaColors.stellarBlue
                                        .withValues(alpha: NebulaAlpha.accent)),
                              ),
                              child: const Icon(Icons.school_outlined,
                                  color: NebulaColors.stellarBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.displayName,
                                      style: type.titleL
                                          .copyWith(color: tokens.primaryText)),
                                  Text('педагог · @${user.login}',
                                      style: type.labelM.copyWith(
                                          color: tokens.secondaryText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Stats island — 2×2 grid ──
                      NebulaSurface(
                        dense: true,
                        radiusRole: NebulaRadiusRole.card,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('СТАТИСТИКА МЕСЯЦА',
                                style: type.overline
                                    .copyWith(color: tokens.mutedText)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _DialogStatRow(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Проведено',
                                value: '${s?.lessonsDone ?? 0}',
                                color: tokens.success,
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _DialogStatRow(
                                icon: Icons.warning_amber_rounded,
                                label: 'Пропусков',
                                value: '${s?.lessonsMissed ?? 0}',
                                color: tokens.error,
                              )),
                            ]),
                            Row(children: [
                              Expanded(
                                  child: _DialogStatRow(
                                icon: Icons.repeat_rounded,
                                label: 'Отработок',
                                value: '${s?.lessonsCancelledMakeup ?? 0}',
                                color: tokens.focusAccent,
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _DialogStatRow(
                                icon: Icons.cancel_outlined,
                                label: 'Долгов',
                                value: '${s?.lessonsDebt ?? 0}',
                                color: tokens.warning,
                              )),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Payout island ──
                      NebulaSurface(
                        dense: true,
                        radiusRole: NebulaRadiusRole.card,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        accent: tokens.success,
                        child: Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                color: tokens.success, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('К выплате',
                                  style: type.bodyM
                                      .copyWith(color: tokens.secondaryText)),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  Money.format(s?.totalAmount ?? 0),
                                  maxLines: 1,
                                  style: type.titleM.copyWith(
                                    color: tokens.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Primary action: view as teacher ──
                      SizedBox(
                        width: double.infinity,
                        child: NebulaTextButton(
                          label: 'Открыть как педагог',
                          icon: Icons.visibility_outlined,
                          onPressed: () {
                            final router = GoRouter.of(context);
                            ref.read(viewAsTeacherProvider.notifier).state =
                                ViewAsTeacher(
                              id: user.id,
                              displayName: user.displayName,
                            );
                            ref.invalidate(studioStatsProvider);
                            invalidateMonthData(
                                ref, ref.read(globalMonthYearProvider));
                            Navigator.pop(context);
                            router.go('/calendar');
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Secondary actions ──
                      Row(
                        children: [
                          Expanded(
                            child: NebulaTextButton(
                              label: 'Сменить пароль',
                              icon: Icons.lock_outline_rounded,
                              onPressed: () async {
                                final ok =
                                    await SetPasswordSheet.show(context, user);
                                if (ok) onUpdated();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NebulaTextButton(
                              label: 'Отключить',
                              icon: Icons.archive_outlined,
                              onPressed: () => _confirmAndDisable(context, ref),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Divider(
                          height: 1,
                          thickness: 1,
                          color: tokens.surfaceBorder),
                      const SizedBox(height: 16),

                      // ── Destructive: permanent delete ──
                      SizedBox(
                        width: double.infinity,
                        child: NebulaTextButton(
                          label: 'Удалить навсегда',
                          icon: Icons.delete_forever_outlined,
                          color: tokens.error,
                          onPressed: () => _confirmAndDelete(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

(e) Move the EXISTING `_confirmAndDisable` and `_confirmAndDelete` methods into
`_TeacherProfileScreen` (they currently live on `_TeacherProfileDialog`). Change
ONLY their success branches so that, after `onUpdated()` and the success
snackbar, the screen pops back to the (refreshed) list. Concretely, in EACH of
the two methods, the success branch currently is:

```dart
      HapticFeedback.mediumImpact();
      onUpdated();
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          ...
        );
      }
```
change it to:
```dart
      HapticFeedback.mediumImpact();
      onUpdated();
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          ...
        );
        Navigator.pop(context);
      }
```
(Keep the snackbar arguments exactly as they are. The `ScaffoldMessenger` is
above the route, so the snackbar survives the pop.)

Keep the `_DialogStatRow` class as-is (reused by the 2×2 grid).

- [ ] **Step 4: Run the test, confirm it passes**

Run: `cd mobile && flutter test test/features/admin/presentation/teacher_profile_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze + full suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze clean (no leftover `_TeacherProfileDialog`, no unused imports); all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/features/admin/presentation/screens/admin_screen.dart \
        mobile/test/features/admin/presentation/teacher_profile_screen_test.dart
git commit -m "feat(admin): teacher profile as a full screen (identity, 2x2 stats, sectioned actions)

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

## Notes / pitfalls

- `GoRouter.of(context)` is captured BEFORE `Navigator.pop` in the view-as
  handler because the profile is a `Navigator.push` route sitting on top of the
  go_router shell; popping it first then calling `router.go('/calendar')` avoids
  using a deactivated context and leaves the user on the calendar (not stuck
  under the popped profile).
- `_TeacherProfileDialog` must be fully removed (its key
  `'teacher-profile-modal-surface'` disappears — no test references it; verified).
- Only this one lib file + the new test change.

## Out of scope

- Adding new profile data (phone, student count, notes) — not requested for this pass.
- Phase 2 (Поиск), Phase 3 (money). The `_LegendDot`/`_RatesCard` symbol-after
  tech-debt noted in Plan A is also separate.
