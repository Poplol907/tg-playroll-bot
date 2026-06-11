# Plan 001: Make month reset and student detail data teacher-scoped and instantly consistent

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report; do not improvise. When done, update this plan's status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 3144d40..HEAD -- backend/app/routers/reports_v2.py backend/app/routers/students.py backend/app/routers/subscriptions.py mobile/lib/features/salary/presentation/screens/salary_screen.dart mobile/lib/features/students/presentation/providers/student_lessons_provider.dart mobile/lib/features/students/data/students_repository.dart mobile/lib/features/admin/presentation/screens/admin_screen.dart mobile/lib/shared/providers/data_refresh_provider.dart mobile/lib/features/students/presentation/widgets/student_detail_content.dart`
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts below against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `3144d40`, 2026-06-11

## Why this matters

Admin view-as currently does not have one coherent "effective teacher"
context. Salary already sends `teacher_id` when viewing as a teacher, but
month reset ignores that context, student detail lesson history does not send
that context, student subscriptions do not send that context, and the
admin-specific students listing does not return `student_teacher_id`.

That explains the observed behavior: salary can look reset while calendar or
student history still shows lessons; admin can open Люсине but not see the same
students/lessons a teacher sees; repeated retries eventually appear to work
because different providers refresh at different times and with different
query scopes. The fix is to make teacher scope explicit and shared across
backend endpoints, mobile requests, and cache invalidation.

## Current state

Relevant files:

- `backend/app/routers/reports_v2.py` — salary and reset-month endpoints.
- `backend/app/routers/students.py` — student listings, including admin
  `/students/teacher/{teacher_id}` view-as endpoint.
- `backend/app/routers/subscriptions.py` — student subscription listing.
- `mobile/lib/features/salary/presentation/screens/salary_screen.dart` —
  calls reset-month from the salary screen.
- `mobile/lib/features/students/presentation/providers/student_lessons_provider.dart`
  — loads lesson history/subscriptions in the student detail card.
- `mobile/lib/features/students/data/students_repository.dart` — loads students
  for teacher or admin view-as.
- `mobile/lib/features/admin/presentation/screens/admin_screen.dart` — sets
  `viewAsTeacherProvider`.
- `mobile/lib/shared/providers/data_refresh_provider.dart` — cross-screen cache
  invalidation helper.
- `mobile/lib/features/students/presentation/widgets/student_detail_content.dart`
  — consumes student lesson/subscription providers.

Evidence:

- `backend/app/routers/reports_v2.py:347-358` hardcodes reset to the current
  user:

```python
@router.delete("/v2/reset-month", status_code=200)
async def reset_month(
    month_year: str = Query(..., description="YYYY-MM, например 2026-05"),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin_or_teacher(current_user)
    teacher_id = current_user.id
```

- `mobile/lib/features/salary/presentation/screens/salary_screen.dart:211-216`
  calls reset without `teacher_id`, even though `salaryProvider` supports
  admin view-as:

```dart
final dio = ref.read(dioProvider);
await dio.delete(
  '/reports/v2/reset-month',
  queryParameters: {'month_year': monthYear},
);
```

- `mobile/lib/features/students/presentation/providers/student_lessons_provider.dart:6-11`
  loads all lessons for a student without teacher scope:

```dart
final studentLessonsProvider =
    FutureProvider.family<List<LessonModel>, int>((ref, studentId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/lessons', queryParameters: {
    'student_id': studentId,
  });
```

- `backend/app/routers/subscriptions.py:18-34` supports `student_id` and
  `month`, but not `teacher_id` for admin view-as:

```python
async def list_subscriptions(
    student_id: int | None = None,
    month: str | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    q = select(Subscription).where(Subscription.org_id == current_user.org_id)

    if current_user.role == "TEACHER":
        q = q.where(Subscription.teacher_user_id == current_user.id)
```

- `backend/app/routers/students.py:142-161` returns students for an admin's
  view-as teacher, but unlike the teacher listing at `students.py:91-107`, it
  does not include `student_teacher_id`:

```python
result = await session.execute(
    select(Student)
    .join(StudentTeacher, StudentTeacher.student_id == Student.id)
    .where(
        StudentTeacher.teacher_user_id == teacher_id,
        StudentTeacher.org_id == current_user.org_id,
    )
)
students = result.scalars().all()
return [StudentOut.model_validate(s) for s in students]
```

- `mobile/lib/shared/providers/data_refresh_provider.dart:12-25` invalidates
  providers broadly but cannot tell reset callers which teacher context was
  mutated:

```dart
void invalidateMonthData(
  WidgetRef ref,
  String monthYear, {
  Iterable<String> extraMonthYears = const [],
}) {
  ...
  ref.invalidate(salaryProvider);
  ref.invalidate(studentsProvider);
  ref.invalidate(studentLessonsProvider);
  ref.invalidate(studentSubscriptionsProvider);
}
```

Repo conventions to follow:

- Backend permission checks are centralized in
  `backend/app/services/permissions.py`. Use `require_teacher_self_or_admin`
  for optional target-teacher access; salary already uses this pattern in
  `backend/app/routers/reports_v2.py:213-218`.
- Flutter state uses Riverpod providers. Existing view-as scope is stored in
  `mobile/lib/features/admin/presentation/providers/view_as_teacher_provider.dart`.
- API errors in Flutter should use `parseApiError(...)` and Nebula snackbars;
  do not reintroduce raw Dio exception text.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Python syntax | `.venv/bin/python -c "import ast, pathlib; [ast.parse(p.read_text()) for root in ('backend','bot') for p in pathlib.Path(root).rglob('*.py')]; print('python ast ok')"` | prints `python ast ok`, exit 0 |
| Flutter analyze | `flutter analyze --no-pub` from `mobile/` | `No issues found!`, exit 0 |
| Flutter tests | `flutter test --no-pub` from `mobile/` | all tests pass, exit 0 |
| Whitespace | `git diff --check` | no output, exit 0 |

## Scope

**In scope**:

- `backend/app/routers/reports_v2.py`
- `backend/app/routers/students.py`
- `backend/app/routers/subscriptions.py`
- `mobile/lib/features/salary/presentation/screens/salary_screen.dart`
- `mobile/lib/features/students/presentation/providers/student_lessons_provider.dart`
- `mobile/lib/features/students/data/students_repository.dart`
- `mobile/lib/features/admin/presentation/screens/admin_screen.dart`
- `mobile/lib/shared/providers/data_refresh_provider.dart`
- `mobile/lib/features/students/presentation/widgets/student_detail_content.dart`
- Tests under `mobile/test/` and backend tests if a backend test harness exists.

**Out of scope**:

- Salary calculation formulas.
- Database schema migrations.
- Visual/theme changes.
- Replacing Riverpod architecture wholesale.
- Changing public lesson/subscription response shapes beyond adding optional
  request query parameters and populating already-existing `student_teacher_id`.

## Git workflow

- Branch: `fix/teacher-scoped-reset-refresh`.
- Commit message style in this repo is short imperative/conventional mixed,
  e.g. `fix(ui): ...` or `fix: ...`. Use one commit for this plan after all
  verification passes.
- Do not push unless explicitly instructed.

## Steps

### Step 1: Make backend reset-month accept an effective teacher id

In `backend/app/routers/reports_v2.py`, add an optional `teacher_id: int | None`
query parameter to `reset_month`, matching the semantics of
`salary_report_v2`:

- If `teacher_id` is absent, use `current_user.id`.
- If `teacher_id` is present, call
  `require_teacher_self_or_admin(current_user, teacher_id)`.
- Verify the target teacher exists in the same org before deleting.
- Use the effective teacher id for both lesson deletion and subscription
  deletion.
- Keep the existing `makeup_for_id` cleanup behavior.
- Include `teacher_id` in the JSON response for easier UI/debug verification.

Do not let an admin reset their own admin user id accidentally while in
view-as mode; the explicit `teacher_id` must control the deletion target.

**Verify**:

```bash
.venv/bin/python -c "import ast, pathlib; ast.parse(pathlib.Path('backend/app/routers/reports_v2.py').read_text()); print('reports_v2 ast ok')"
```

Expected: `reports_v2 ast ok`, exit 0.

### Step 2: Add teacher-scoped subscription listing

In `backend/app/routers/subscriptions.py`, add optional `teacher_id: int | None`
to `list_subscriptions`.

Rules:

- `TEACHER`: always restrict to `current_user.id`; ignore/forbid mismatched
  `teacher_id`. Prefer `require_teacher_self_or_admin(current_user, teacher_id)`
  if a query id is supplied.
- `ADMIN`: if `teacher_id` is supplied, filter
  `Subscription.teacher_user_id == teacher_id`; otherwise preserve current
  org-wide admin behavior.
- Preserve existing `student_id` and `month` filters.

**Verify**:

```bash
.venv/bin/python -c "import ast, pathlib; ast.parse(pathlib.Path('backend/app/routers/subscriptions.py').read_text()); print('subscriptions ast ok')"
```

Expected: `subscriptions ast ok`, exit 0.

### Step 3: Populate `student_teacher_id` in admin `/students/teacher/{teacher_id}`

In `backend/app/routers/students.py`, change `students_by_teacher` to mirror
the teacher branch at lines 91-107:

- Query `select(Student, StudentTeacher.id.label("st_id"))`.
- Build `StudentOut.model_validate(student)`.
- Set `data.student_teacher_id = st_id`.
- Return the list.

This is necessary because the student detail card uses `student.studentTeacherId`
to add schedules and should not infer it from stale lessons.

**Verify**:

```bash
.venv/bin/python -c "import ast, pathlib; ast.parse(pathlib.Path('backend/app/routers/students.py').read_text()); print('students ast ok')"
```

Expected: `students ast ok`, exit 0.

### Step 4: Pass view-as teacher id from reset-month UI

In `mobile/lib/features/salary/presentation/screens/salary_screen.dart`:

- Read `viewAsTeacherProvider` in `_resetMonth`.
- When calling `DELETE /reports/v2/reset-month`, include:

```dart
queryParameters: {
  'month_year': monthYear,
  if (viewAs != null) 'teacher_id': viewAs.id,
}
```

- Keep `invalidateMonthData(ref, monthYear)` after success.
- Keep success/error snackbar behavior, but if you touch error handling, use
  `parseApiError(...)` rather than raw Dio payload strings.

**Verify**:

```bash
cd mobile && flutter analyze --no-pub
```

Expected: no analyzer errors.

### Step 5: Make student detail lesson and subscription providers teacher-scoped

In `mobile/lib/features/students/presentation/providers/student_lessons_provider.dart`:

- Import `view_as_teacher_provider.dart`.
- Inside both `studentLessonsProvider` and `studentSubscriptionsProvider`, watch
  `viewAsTeacherProvider`.
- Include `teacher_id` in `/lessons` and `/subscriptions` queryParameters when
  view-as is active:

```dart
final viewAs = ref.watch(viewAsTeacherProvider);
final response = await dio.get('/lessons', queryParameters: {
  'student_id': studentId,
  if (viewAs != null) 'teacher_id': viewAs.id,
});
```

Do the analogous change for subscriptions.

This keeps the existing provider family key (`student.id`) but makes its
dependency graph include view-as, so Riverpod refreshes when view-as changes.

**Verify**:

```bash
cd mobile && flutter analyze --no-pub
```

Expected: no analyzer errors.

### Step 6: Tighten view-as transition invalidation

In `mobile/lib/features/admin/presentation/screens/admin_screen.dart`, after
setting `viewAsTeacherProvider`, invalidate the data families that can still
hold org/admin-scoped values:

- `studentsProvider`
- `studentLessonsProvider`
- `studentSubscriptionsProvider`
- `salaryProvider`
- `lessonsProvider` for the active month, preferably through
  `invalidateMonthData(ref, ref.read(globalMonthYearProvider))` if imports do
  not create cycles.

If importing `invalidateMonthData` into `admin_screen.dart` creates a cycle,
STOP and report; do not scatter manual invalidation without explaining the
cycle.

**Verify**:

```bash
cd mobile && flutter analyze --no-pub
```

Expected: no analyzer errors.

### Step 7: Add regression tests

Add or update tests with the repo's existing test style:

Flutter:

- Add a provider/unit-style test or widget test that overrides
  `viewAsTeacherProvider` and verifies student detail provider requests include
  `teacher_id`. If there is no existing Dio mock pattern, add a minimal fake
  Dio provider override near the provider tests; keep it local to the test.
- Add a test for reset-month request construction if an existing screen test
  pattern can intercept Dio calls. If not practical, at minimum add a small
  test around whatever helper/repository function you extract for reset.

Backend:

- If there is an existing pytest/httpx backend test harness, add tests for:
  - admin `DELETE /reports/v2/reset-month?month_year=2026-05&teacher_id=<T>`
    deletes the target teacher's lessons/subscriptions, not the admin's.
  - `/students/teacher/{teacher_id}` returns non-null `student_teacher_id`.
  - `/subscriptions?student_id=<S>&teacher_id=<T>` filters to that teacher.
- If no backend test harness exists, do not invent a large one in this plan;
  add a small `ast`/service-level test only if it matches existing patterns,
  otherwise document the missing backend harness in the PR notes.

**Verify**:

```bash
cd mobile && flutter test --no-pub
```

Expected: all tests pass, including new tests.

### Step 8: End-to-end manual acceptance

Use this exact manual flow against a dev server:

1. Log in as admin.
2. Open a teacher, e.g. Люсине, with "Открыть как педагог".
3. Confirm calendar shows that teacher's lessons for the selected month.
4. Open a student in that teacher's list and confirm:
   - `student_teacher_id` exists because "add schedule" is available when it
     should be.
   - history matches the selected teacher/month.
5. From salary screen, click "Удалить данные за месяц".
6. After success, without restarting the app:
   - salary is zero/empty for that teacher/month,
   - calendar no longer shows that teacher's month lessons,
   - student detail history no longer shows that teacher's deleted month
     lessons,
   - admin studio stats do not show stale teacher totals after returning to
     admin mode.

## Test plan

- Backend permission/scope tests should prove admin target-teacher reset does
  not use `current_user.id`.
- Flutter provider tests should prove `teacher_id` is attached to student
  detail lesson/subscription requests in view-as mode.
- Existing full mobile suite must keep passing.

## Done criteria

All must hold:

- [ ] `DELETE /reports/v2/reset-month` accepts optional `teacher_id` and
      deletes the effective teacher's rows.
- [ ] Non-admin teachers cannot reset another teacher's data.
- [ ] `/students/teacher/{teacher_id}` returns `student_teacher_id`.
- [ ] `/subscriptions` supports teacher-scoped admin view-as filtering.
- [ ] Student detail `/lessons` and `/subscriptions` requests include
      `teacher_id` in view-as mode.
- [ ] View-as transition invalidates month/student/salary caches.
- [ ] `cd mobile && flutter analyze --no-pub` exits 0.
- [ ] `cd mobile && flutter test --no-pub` exits 0.
- [ ] Python AST command exits 0.
- [ ] `git diff --check` exits 0.
- [ ] `plans/README.md` row for this plan is updated.

## STOP conditions

Stop and report back if:

- Any in-scope file no longer matches the current-state excerpts.
- `reset_month` has already been moved from router code into a service layer;
  in that case, plan the service-level change instead of duplicating logic in
  the router.
- Adding `invalidateMonthData` import to admin screen creates an import cycle.
- Backend tests require creating a new database fixture system from scratch.
- The fix appears to require schema migrations.

## Maintenance notes

- Any future view-as feature must pass the effective teacher context to both
  backend query parameters and provider dependencies. Do not rely on "current
  user" for admin view-as.
- Reviewers should scrutinize authorization: admins may target any teacher in
  their org; teachers may only target themselves.
- Reviewers should manually verify stale data behavior without restarting the
  app. This bug is mostly about cache/provider coherence, not just SQL delete.
