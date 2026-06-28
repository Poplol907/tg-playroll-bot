# Phase 2 «Поиск» (Search Tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (project default — see CLAUDE.md). One implementer subagent per task, then spec + code-quality review. Steps use checkbox (`- [ ]`).

**Goal:** Give admins a third nav tab «Поиск» — a search hub with a [Педагоги | Ученики] segmented control: Педагоги lists teachers (tap → that teacher's students, with a button to the full profile), Ученики searches all studio students. The teacher list moves here from «Студия», which becomes a clean stats-only overview.

**Architecture:** New admin route `/search` + nav item; a reusable `NebulaSegmentedControl`; a `SearchScreen` hosting the two segments; a teacher→students drill screen; new `studentsByTeacherProvider`. Reuses `studentsProvider`, `StudentsRepository.getStudents(teacherId:)`, `StudentDetailSheet.show`, and `TeacherProfileEntry.open` (Plan B). Backend already has `GET /students` (all org students for admin) and `GET /students/teacher/{id}` — no backend changes.

**Tech Stack:** Flutter, Riverpod, go_router, flutter_test. All under `mobile/`. Branch `feature/search-tab` off `main`.

**Order matters:** Task 4 (slim Студия) runs LAST so the teacher list never disappears between steps.

---

### Task 1: Reusable segmented control + «Поиск» nav tab + SearchScreen scaffold

**Files:**
- Create: `mobile/lib/shared/widgets/nebula_segmented_control.dart`
- Create: `mobile/lib/features/admin/presentation/screens/search_screen.dart`
- Modify: `mobile/lib/core/router/app_router.dart`
- Test: `mobile/test/shared/widgets/nebula_segmented_control_test.dart`
- Test: `mobile/test/core/router/admin_search_tab_test.dart`

- [ ] **Step 1: Write the failing segmented-control test** — `mobile/test/shared/widgets/nebula_segmented_control_test.dart`:

```dart
import 'package:cosmo_studio/shared/widgets/nebula_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NebulaSegmentedControl shows segments and reports taps',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NebulaSegmentedControl(
              segments: const ['Педагоги', 'Ученики'],
              selectedIndex: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Педагоги'), findsOneWidget);
    expect(find.text('Ученики'), findsOneWidget);

    await tester.tap(find.text('Ученики'));
    await tester.pump();
    expect(selected, 1);
  });
}
```

- [ ] **Step 2: Run it, confirm it fails** — `cd mobile && flutter test test/shared/widgets/nebula_segmented_control_test.dart` (FAIL: file missing).

- [ ] **Step 3: Implement `nebula_segmented_control.dart`:**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_typography.dart';

/// A simple two-or-more segment switcher (pill with a sliding-less active fill).
/// One mechanism for "pick one of N peer views" — reused by the search tab
/// (Педагоги / Ученики) and later the calendar scope switcher.
class NebulaSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const NebulaSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.denseSurface.withValues(alpha: NebulaAlpha.surface),
        borderRadius: NebulaRadii.pillBorder,
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? tokens.primaryAccent.withValues(alpha: NebulaAlpha.surface)
                        : Colors.transparent,
                    borderRadius: NebulaRadii.pillBorder,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    segments[i],
                    style: type.labelM.copyWith(
                      color: i == selectedIndex
                          ? tokens.primaryText
                          : tokens.mutedText,
                      fontWeight:
                          i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it, confirm PASS.**

- [ ] **Step 5: Write the failing router test** — `mobile/test/core/router/admin_search_tab_test.dart`:

```dart
import 'package:cosmo_studio/features/admin/presentation/screens/search_screen.dart';
import 'package:cosmo_studio/shared/widgets/nebula_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SearchScreen shows the Педагоги/Ученики segmented control',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(NebulaSegmentedControl), findsOneWidget);
    expect(find.text('Педагоги'), findsWidgets);
    expect(find.text('Ученики'), findsWidgets);
  });
}
```

- [ ] **Step 6: Run it, confirm it fails** (SearchScreen missing).

- [ ] **Step 7: Create `SearchScreen` scaffold** — `mobile/lib/features/admin/presentation/screens/search_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_segmented_control.dart';

/// Admin search hub: teachers (with drill to their students) and a studio-wide
/// student search, behind a segmented control.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  int _segment = 0; // 0 = Педагоги, 1 = Ученики

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppScreenHeader(
                title: 'Поиск',
                subtitle: 'Педагоги и ученики студии',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NebulaSegmentedControl(
                segments: const ['Педагоги', 'Ученики'],
                selectedIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
            Expanded(
              child: _segment == 0
                  ? const _TeachersSearchTab()
                  : const _StudentsSearchTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder tabs — filled in by Tasks 2 and 3.
class _TeachersSearchTab extends StatelessWidget {
  const _TeachersSearchTab();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Педагоги'));
}

class _StudentsSearchTab extends StatelessWidget {
  const _StudentsSearchTab();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Ученики'));
}
```

(The SearchScreen sits inside the shell, which already provides `AppBackgroundHost`, so it does not wrap its own background — matching `AdminScreen`. If the test needs a background it still renders fine without one.)

- [ ] **Step 8: Wire the «Поиск» tab into the router** — in `mobile/lib/core/router/app_router.dart`:

(a) Add a nav item near `_adminMenuItem`:
```dart
  GlowMenuItem _searchMenuItem(CosmoThemeTokens t) => GlowMenuItem(
        icon: Icons.search_rounded,
        label: 'Поиск',
        glowColor: t.secondaryAccent,
      );
```
(b) Add a desktop sidebar item near `_adminSidebarItem`:
```dart
  static const _searchSidebarItem = DesktopSidebarItem(
    icon: Icons.search_rounded,
    label: 'Поиск',
  );
```
(c) In `_routesForRole`, change the admin branch:
```dart
    if (isAdmin && !viewingAs) return ['/admin', '/search', '/settings'];
```
(d) Where mobile admin nav items are built (`[_adminMenuItem(tokens), _settingsMenuItem(tokens)]`), insert search:
```dart
        ? [_adminMenuItem(tokens), _searchMenuItem(tokens), _settingsMenuItem(tokens)]
```
(e) Where the desktop admin sidebar items are built (`[_adminSidebarItem, _settingsSidebarItem]`), insert search:
```dart
        ? [_adminSidebarItem, _searchSidebarItem, _settingsSidebarItem]
```
(f) In the `ShellRoute` builder's `showAdminTabs` index mapping, replace:
```dart
            index = loc.startsWith('/settings') ? 1 : 0;
```
with:
```dart
            index = loc.startsWith('/settings')
                ? 2
                : loc.startsWith('/search')
                    ? 1
                    : 0;
```
(g) Add the `/search` GoRoute next to the `/admin` route:
```dart
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const SearchScreen(),
            ),
          ),
```
(h) Add the import at the top of app_router.dart:
```dart
import '../../features/admin/presentation/screens/search_screen.dart';
```
(i) In the router `redirect`, the existing admin-only guard blocks non-admins from `/admin`. Extend it to also cover `/search`. Find:
```dart
      if (isAuth && !isAdmin && state.matchedLocation.startsWith('/admin')) {
        return '/calendar';
      }
```
and change the condition to also catch `/search`:
```dart
      if (isAuth &&
          !isAdmin &&
          (state.matchedLocation.startsWith('/admin') ||
              state.matchedLocation.startsWith('/search'))) {
        return '/calendar';
      }
```

- [ ] **Step 9: Run the router test, confirm PASS.**

- [ ] **Step 10: Run `flutter analyze && flutter test`** — clean + all pass.

- [ ] **Step 11: Commit**
```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/shared/widgets/nebula_segmented_control.dart \
        mobile/lib/features/admin/presentation/screens/search_screen.dart \
        mobile/lib/core/router/app_router.dart \
        mobile/test/shared/widgets/nebula_segmented_control_test.dart \
        mobile/test/core/router/admin_search_tab_test.dart
git commit -m "feat(search): add admin Поиск tab + reusable segmented control

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 2: «Педагоги» segment — teacher list + drill to their students

**Files:**
- Modify: `mobile/lib/features/admin/presentation/screens/search_screen.dart`
- Create: `mobile/lib/features/admin/presentation/screens/teacher_students_screen.dart`
- Modify: `mobile/lib/features/students/data/students_repository.dart` (add a by-teacher family provider)
- Test: `mobile/test/features/admin/presentation/search_teachers_test.dart`

Context: the existing teacher list logic lives in `_TeachersList`/`_TeacherTile` inside `admin_screen.dart` (it merges `orgUsersProvider` + `studioStatsProvider`, filters non-admins by a query). For Поиск we render the SAME teacher list but tapping a teacher DRILLS to their students (not the profile). The profile stays reachable via a button on the drill screen (`TeacherProfileEntry.open`).

- [ ] **Step 1: Add a by-teacher students provider** in `students_repository.dart`, next to `studentsProvider`:
```dart
/// Students of a specific teacher (admin drill). Keyed by teacher user id.
final studentsByTeacherProvider =
    FutureProvider.family<List<StudentModel>, int>((ref, teacherId) async {
  return ref.watch(studentsRepositoryProvider).getStudents(teacherId: teacherId);
});
```

- [ ] **Step 2: Write the failing test** — `mobile/test/features/admin/presentation/search_teachers_test.dart`: pump `SearchScreen` with `orgUsersProvider` overridden to return one teacher + admin, assert the teacher's name shows in the Педагоги segment and an admin is filtered out. (Use `ProviderScope(overrides: [orgUsersProvider.overrideWith((ref) async => [<one TEACHER OrgUser>, <one ADMIN OrgUser>]), studioStatsProvider.overrideWith(...empty...)])`. Pump, then `expect(find.text('<teacher name>'), findsWidgets)`.) Build the test using the real `OrgUser`/`StudioStats` constructors (OrgUser requires `hasPassword`).

- [ ] **Step 3: Implement `_TeachersSearchTab`** in `search_screen.dart` — a stateful widget with a search `TextField` (reuse the look of the old `_SearchField`: a `Container` with `NebulaColors.nebulaSurface` fill, `NebulaRadii.cardBorder`, `TextField` hint "Поиск по педагогам...") and a list. Read `orgUsersProvider` + `studioStatsProvider`, filter non-admins by the query (same logic as the current `_TeachersList`: `users.where((u) => !u.isAdmin)`, case-insensitive name/login contains). Render each teacher as a tappable tile (name + login + student/payout summary). On tap: `Navigator.of(context).push(SpacePageRoute(builder: (_) => TeacherStudentsScreen(user: teacher)))`. Use `OrbitLoader` while loading, `AppErrorCard` on error, `AppEmptyState` when empty — mirror the current `_TeachersList`.

- [ ] **Step 4: Create `TeacherStudentsScreen`** — `teacher_students_screen.dart`: a `ConsumerWidget` showing `AppScreenHeader(title: user.displayName, subtitle: 'Ученики педагога', leading: back, trailing: a "Профиль" text button → `TeacherProfileEntry.open(context, user: user, stats: null, onUpdated: () {})`)`, then `ref.watch(studentsByTeacherProvider(user.id))` rendering the student list. Each student tile → `StudentDetailSheet.show(context, student)`. Loading/error/empty via OrbitLoader/AppErrorCard/AppEmptyState. Wrap the body so it sits in the shell (no own background needed when pushed over the shell — but since this is a `Navigator.push` over the shell, wrap in `Scaffold(backgroundColor: Colors.transparent, body: AppBackgroundHost(interactive: false, child: SafeArea(...)))` like the profile screen).

- [ ] **Step 5: Run the test, confirm PASS.**
- [ ] **Step 6: `flutter analyze && flutter test`** clean + pass.
- [ ] **Step 7: Commit** (scoped: search_screen.dart, teacher_students_screen.dart, students_repository.dart, the test) with message `feat(search): Педагоги list drills to a teacher's students`.

---

### Task 3: «Ученики» segment — studio-wide student search

**Files:**
- Modify: `mobile/lib/features/admin/presentation/screens/search_screen.dart`
- Test: `mobile/test/features/admin/presentation/search_students_test.dart`

Context: `studentsProvider` returns ALL org students for an admin (no view-as). Render them with a search field; tap → `StudentDetailSheet.show`.

- [ ] **Step 1: Write the failing test** — `search_students_test.dart`: pump `SearchScreen`, switch to the Ученики segment (`tester.tap(find.text('Ученики'))`), override `studentsProvider` to return two students, assert both names show and that typing in the search field filters to one. (Use the real `StudentModel` constructor.)

- [ ] **Step 2: Implement `_StudentsSearchTab`** in `search_screen.dart` — a stateful widget with a search `TextField` (hint "Поиск по ученикам...") and `ref.watch(studentsProvider)`. Filter by case-insensitive `firstName`/`lastName` contains the query. Render each as a tappable tile (full name + optional teacher/instrument hint from `StudentModel`) → `StudentDetailSheet.show(context, student)`. OrbitLoader/AppErrorCard/AppEmptyState states.

- [ ] **Step 3: Run the test, confirm PASS.**
- [ ] **Step 4: `flutter analyze && flutter test`** clean + pass.
- [ ] **Step 5: Commit** (`feat(search): studio-wide student search in the Ученики segment`).

---

### Task 4: Slim «Студия» to a stats-only overview

**Files:**
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart`
- Test: `mobile/test/features/admin/presentation/admin_studio_overview_test.dart`

Context: now that teachers/students live in Поиск, remove the search field + teacher list from `AdminScreen` (Студия). Keep the header (with the add-user action), the `_StudioStatsCard`, and the add-user flow. Remove the now-unused `_SearchField`, `_TeachersList`, `_TeacherTile`, and the `_query` state.

- [ ] **Step 1: Write the failing test** — `admin_studio_overview_test.dart`: pump `AdminScreen` (with `studioStatsProvider`/`orgUsersProvider` overrides), assert `_StudioStatsCard` content (e.g. 'СТАТИСТИКА СТУДИИ') is present AND that there is no teacher-search field (e.g. `find.text('Поиск по имени или логину...')` findsNothing, and no `_TeacherTile`). Since `_TeacherTile` is private, assert via the absence of a known teacher-list-only string, or assert `find.byType(TextField)` findsNothing on the studio screen.

- [ ] **Step 2: Edit `AdminScreen.build`** — remove the `_SearchField` and `_TeachersList`/`teachers` slivers from both the desktop and mobile layouts; keep header + `_StudioStatsCard`. Remove the `_query` field and its `setState`. Delete the now-unused `_SearchField`, `_TeachersList`, and `_TeacherTile` classes (verify no other references first with grep). Keep `_StudioStatsCard`, `_DialogStatRow` is already in the profile file (Plan B) — confirm it's not duplicated here. Remove imports that become unused (e.g. `orbit_loader` if only the list used it — verify with analyze).

- [ ] **Step 3: Run the test, confirm PASS.**
- [ ] **Step 4: `flutter analyze && flutter test`** clean + pass.
- [ ] **Step 5: Commit** (`refactor(admin): Студия becomes a stats-only overview; people move to Поиск`).

---

## Self-review checklist (after all tasks)
- Admin nav shows three tabs [Студия | Поиск | Настройки]; `/search` is admin-only (non-admins redirect to /calendar).
- Студия = stats card only; teacher list + search are gone from it.
- Поиск: Педагоги → tap → teacher's students (+ Профиль button → full profile); Ученики → search → all students → detail sheet.
- `grep -rn "_TeachersList\|_TeacherTile\|_SearchField" mobile/lib` → only inside search_screen.dart (or gone from admin_screen.dart).
- `flutter analyze` clean; full suite green.

## Out of scope
- Phase 3 «Деньги». The reusable `NebulaSegmentedControl` is intentionally built shared so Track 2 (calendar scope switcher) can reuse it.
- Reconciling `admin_screen.dart` file size (the spawned "extract profile" task covers that separately).
