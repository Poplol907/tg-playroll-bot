# Admin Overhaul — Design (Track 1)

- **Date:** 2026-06-25
- **Status:** Approved scope, pending spec review
- **Track:** 1 of 2. Track 2 (Calendar & Rooms) is committed as the next track and is specced separately.
- **Platform:** Flutter mobile, iPhone-first. Backend: FastAPI + PostgreSQL.

## Context

The admin screen (`mobile/lib/features/admin/`) today shows a studio stats card,
a flat searchable teacher list, a cramped teacher-profile dialog (stats, payout,
view-as, password, disable, delete), and user creation. View-as-teacher mode
draws a full-screen orange frame.

Goals: fix correctness bugs that erode trust in the data, polish what feels
janky, turn the flat list into a real in-app search, and add money management
(rates, partial payouts, export, month close). Analytics is explicitly out of
scope.

## Locked decisions (from brainstorm)

- "Люди" concept is named **«Поиск»** — an in-system search engine over teachers
  and students.
- Payouts support **partial payments** (a payments ledger; amount + date; shows
  "paid / remaining" per teacher per month).
- No analytics track.
- Design system: Nebula/Spacemorphism. All surfaces via `NebulaSurface` /
  `NebulaModalSurface`; tokens via `NebulaTokens` / `CosmoThemeTokens`; ratchet
  tests in `mobile/test/architecture/` continue to gate magic numbers.

## Phases

### Phase 0 — Correctness bugs (do first)

**0.1 Lesson leak across teachers (root cause found).**
`lessonsProvider` is `FutureProvider.family<List<LessonModel>, String>` keyed
**only by `monthYear`** (`calendar_provider.dart`), but its result depends on
`viewAsTeacherProvider.id` (passed as `teacherId` to `/lessons`). When the admin
switches teacher context (enter/exit view-as), the single cache entry for a month
is reused, so one teacher's lessons briefly appear for everyone during the async
refetch window.
*Fix:* key the family by a `(monthYear, teacherId)` record so each teacher context
has its own cache entry — no shared slot, no cross-teacher bleed. Update
`invalidateMonthData` and all `lessonsProvider(month)` call sites to the new key.
*Test:* two distinct teacher contexts yield independent cached lists; switching
context never surfaces the other teacher's lessons.

**0.2 Student count miscounts.**
`reports.py` `active_students` counts `distinct StudentTeacher.student_id` joined
to lessons in the month, **without** the `lesson_type == "regular"` filter the
sibling lesson-fact aggregates use — so students whose only lessons are makeup
get counted, inflating/diverging the number.
*Fix:* align the active-student query with the studio's intended definition
(students with ≥1 regular lesson in the month) and add the `lesson_type='regular'`
filter; verify against a known dataset.
*Test:* backend unit test on the studio report with mixed regular/makeup lessons.

### Phase 1 — Polish

**1.1 Orange view-as frame adapts to the device.**
`_ViewAsFramePainter` (`view_as_banner.dart`) paints to the full Stack size with a
fixed `deflate(5)` and `NebulaRadii.hero` (32) radius, ignoring the device safe
area — so on notched/rounded screens the frame doesn't hug the visible display.
*Fix:* inset the frame by `MediaQuery.viewPadding` (+ a small margin) so it traces
the usable screen on any device, and use a corner radius that reads as following
the physical screen. Keep the soft inner-glow + thin line look.
*Test:* widget test asserting the painted rect respects injected safe-area insets.

**1.2 Teacher profile redesign (cramped → full screen).**
The profile is a dense dialog overloaded with buttons. Promote it to a full screen
(`SpacePageRoute`) with clear sections: identity header, month stats island,
payout island, primary action (open as teacher), secondary actions (password,
disable), destructive (delete) clearly separated. Same actions, more breathing
room, design-system components only.

### Phase 2 — «Поиск» (rename + search engine)

Rename the admin people surface to **«Поиск»**. Structure:
- Segmented **Педагоги / Ученики**.
- **Педагоги:** existing teacher list; tap a teacher → their students (drill-in).
- **Ученики:** studio-wide student search by name; result → student context.
- Search box filters the active segment; student search works across the whole
  studio (not just within one teacher).

*Backend:* needs an admin-scoped "all students of the org (with their teacher)"
read. Reuse an existing endpoint if one fits; otherwise add `GET /org/students`
(admin-only) returning students + teacher binding. Detail in the plan.

### Phase 3 — Money

**3.1 Teacher rates.** A `rates` router already exists in the backend. Add admin
UI to view and edit a teacher's current rate (with the existing rate-history
semantics preserved). Wire/confirm the edit endpoint.

**3.2 Partial payouts (new backend table).** Introduce a payouts ledger:
`payout(id, org_id, teacher_id, month_year, amount, paid_at, note?)`. API: list
payouts for a month, create a payment, delete a payment (admin-only). UI: per
teacher per month show **computed-owed** (from the salary/studio report) vs
**paid sum**, with "осталось" remaining; add-payment action (amount + date).
History falls out of the ledger naturally (no separate history screen).

**3.3 Export / share.** Build a month payout summary client-side (per teacher:
owed, paid, remaining, totals) and hand it to the OS share sheet as text/file.
No backend.

**3.4 Close month.** Wire the existing `DELETE /reports/v2/reset-month` behind a
clearly destructive, confirmed admin action with an explanation of what it does.

## Architecture & boundaries

- Stay within the existing feature structure (`features/admin/...`,
  `features/calendar/...`). Data in `data/`, providers in `presentation/providers/`.
- New money UI lives under `features/admin/`. The payouts ledger gets its own
  repository + provider; rates reuse/extend the existing rates client.
- Keep files focused; the current `admin_screen.dart` (~833 lines) should be split
  as we extract the profile screen and the search surface.
- Backend changes are additive (new payout table + endpoints, a student-list read,
  a corrected studio query) — no destructive migrations to existing data.

## Testing

- Provider-level test for the lesson-leak fix (per-teacher cache isolation).
- Backend unit tests for the corrected student count and the payout ledger
  (owed/paid/remaining math).
- Widget tests for the safe-area frame and the redesigned profile/search surfaces.
- Architecture ratchet tests stay green (alpha/fontSize/radii only go down).

## Out of scope

- Analytics / trends / charts.
- Track 2: Calendar & Rooms overhaul (zoom levels, scope switcher, room booking
  blocks with mixed weekly-template + per-date overrides, "my rooms today",
  conflict detection). Committed as the next track, specced separately.

## Open questions for the plan

- Exact owed-amount source for payouts: reuse `/reports/v2/salary` per teacher, or
  the studio report's per-teacher `totalAmount`? (Pick one source of truth.)
- Student-list endpoint: existing vs new `GET /org/students`.
- Rate edit endpoint shape in the existing `rates` router.
