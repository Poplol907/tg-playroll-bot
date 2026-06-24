"""Reporting & payroll service.

All business logic for salary / studio reports lives here:

* `salary_v2`      — gamified per-teacher salary (goal / earned / pending / debt),
* `salary_report`  — legacy advance/final salary report,
* `studio_stats`   — org-wide monthly overview + per-teacher breakdown,
* `reset_month`    — destructive month wipe (lessons + subscriptions) for recalc.

Functions raise `services.errors.DomainError` subclasses on failure —
NEVER `HTTPException`. The router translates them at the boundary.

Each public function takes an `AsyncSession` and a `User` (the actor) plus
the request data, and returns plain dataclasses, not HTTP response models.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import (
    delete as sa_delete,
    func,
    select,
    update as sa_update,
)
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import Lesson, Student, StudentTeacher, Subscription, User
from backend.app.services.errors import Forbidden, NotFound, ValidationError
from backend.app.services.months import parse_month
from backend.app.services.rates import (
    build_rate_resolver,
    build_rate_resolvers_bulk,
)
from backend.app.services.salary import calculate_salary

VALID_REPORT_TYPES = {"advance", "final"}


# ─────────────────────────────────────────────────────────────────────────────
#  Result objects
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class TeacherSalary:
    """A teacher plus their computed `calculate_salary` result for a period."""

    teacher: User
    salary: object  # SalaryResult from services.salary
    period_start: date
    period_end: date
    report_type: str


@dataclass
class StudioResult:
    month: str
    total_done: int
    total_missed: int
    total_cancelled: int
    total_scheduled: int
    active_students: int
    active_teachers: int
    teacher_salaries: list[TeacherSalary] = field(default_factory=list)


@dataclass
class SalaryV2Result:
    period_start: date
    period_end: date
    goal_amount: int
    total_subscribed: int
    earned_amount: int
    pending_amount: int
    total_current: int
    lessons_done: int
    lessons_missed: int
    lessons_debt: int
    lessons_makeup_done: int
    advance_amount: int
    final_amount: int
    total_amount: int


@dataclass
class ResetMonthResult:
    teacher_id: int
    lessons_deleted: int
    subscriptions_deleted: int


# ─────────────────────────────────────────────────────────────────────────────
#  Internal helpers
# ─────────────────────────────────────────────────────────────────────────────


def _assert_self_or_admin(user: User, teacher_id: int) -> None:
    """Mirror of `require_teacher_self_or_admin`, as a domain rule."""
    if user.role == "ADMIN":
        return
    if user.role == "TEACHER" and user.id == teacher_id:
        return
    raise Forbidden("forbidden")


async def _require_teacher_in_org(
    session: AsyncSession, teacher_id: int, org_id: int
) -> User:
    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != org_id:
        raise NotFound("teacher not found")
    return teacher


async def _load_lessons(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    date_from: date,
    date_to: date,
) -> list[tuple[Lesson, StudentTeacher]]:
    result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_user_id,
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    return result.all()


# ─────────────────────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────────────────────


async def salary_v2(
    session: AsyncSession,
    user: User,
    *,
    month_year: str,
    teacher_id: int | None,
) -> SalaryV2Result:
    """Gamified salary for a month.

    Defaults to the caller's own salary; an ADMIN may pass `teacher_id` to
    view another teacher (view-as). A TEACHER may only see their own.
    """
    # Resolve which teacher we're reporting on.
    if teacher_id is not None and teacher_id != user.id:
        if user.role != "ADMIN":
            raise Forbidden(
                "Только админ может просматривать зарплату другого педагога"
            )
        effective_teacher_id = teacher_id
    else:
        effective_teacher_id = user.id

    mr = parse_month(month_year)
    date_from, date_to, date_mid = mr.start, mr.end, mr.midpoint

    await _require_teacher_in_org(session, effective_teacher_id, user.org_id)

    # ── is_foreign map + rate resolver (one query each) ──────────────────
    students_result = await session.execute(
        select(Student.id, Student.is_foreign).where(
            Student.org_id == user.org_id
        )
    )
    foreign_map: dict[int, bool] = {row[0]: row[1] for row in students_result.all()}

    rate_resolver = await build_rate_resolver(
        session, user.org_id, effective_teacher_id
    )

    rows = await _load_lessons(
        session, user.org_id, effective_teacher_id, date_from, date_to
    )

    # ── Goal: sum of rates over REAL regular lessons in the schedule ─────
    # Makeup lessons replace missed slots, so they don't add to the goal.
    goal_amount = 0
    total_subscribed = 0
    for lesson, st in rows:
        if getattr(lesson, "lesson_type", "regular") != "regular":
            continue
        goal_amount += rate_resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        total_subscribed += 1

    # ── Accruals ─────────────────────────────────────────────────────────
    earned_amount = 0
    pending_amount = 0
    lessons_done = 0
    lessons_missed = 0
    lessons_debt = 0
    lessons_makeup_done = 0

    for lesson, st in rows:
        rate = rate_resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        lesson_type = getattr(lesson, "lesson_type", "regular")

        if lesson.status == "attended":
            if lesson_type == "makeup":
                # Makeup lesson: counter only; money flows through the original.
                lessons_makeup_done += 1
            else:
                lessons_done += 1
                earned_amount += rate

        elif lesson.status == "missed":
            if lesson.makeup_status in ("done", "completed"):
                # Makeup happened → counted as taught (makeup already counted).
                earned_amount += rate
            else:
                # Real miss — paid at month end.
                lessons_missed += 1
                pending_amount += rate

        elif lesson.status == "cancelled" and lesson.cancelled_by == "teacher":
            if lesson.makeup_status in ("completed", "done"):
                earned_amount += rate
            else:
                lessons_debt += 1

    # ── Advance (days 1–15) ──────────────────────────────────────────────
    advance_rows = [(l, st) for l, st in rows if l.scheduled_date <= date_mid]
    advance = await calculate_salary(
        session,
        user.org_id,
        effective_teacher_id,
        advance_rows,
        date_from,
        date_mid,
        "advance",
        student_foreign_map=foreign_map,
        rate_resolver=rate_resolver,
    )
    advance_amount = advance.total_amount
    total_current = earned_amount + pending_amount
    final_amount = total_current - advance_amount

    return SalaryV2Result(
        period_start=date_from,
        period_end=date_to,
        goal_amount=goal_amount,
        total_subscribed=total_subscribed,
        earned_amount=earned_amount,
        pending_amount=pending_amount,
        total_current=total_current,
        lessons_done=lessons_done,
        lessons_missed=lessons_missed,
        lessons_debt=lessons_debt,
        lessons_makeup_done=lessons_makeup_done,
        advance_amount=advance_amount,
        final_amount=max(0, final_amount),
        total_amount=total_current,
    )


async def salary_report(
    session: AsyncSession,
    user: User,
    *,
    month: str,
    teacher_id: int,
    report_type: str,
) -> TeacherSalary:
    """Legacy advance/final salary report for one teacher."""
    _assert_self_or_admin(user, teacher_id)

    if report_type not in VALID_REPORT_TYPES:
        raise ValidationError(
            "report_type must be 'advance' or 'final'",
            details={"allowed": sorted(VALID_REPORT_TYPES)},
        )

    mr = parse_month(month)
    date_from, date_to = mr.start, mr.end
    if report_type == "advance":
        date_to = mr.midpoint

    teacher = await _require_teacher_in_org(session, teacher_id, user.org_id)

    rows = await _load_lessons(session, user.org_id, teacher_id, date_from, date_to)
    rate_resolver = await build_rate_resolver(session, user.org_id, teacher_id)
    salary = await calculate_salary(
        session,
        user.org_id,
        teacher_id,
        rows,
        date_from,
        date_to,
        report_type,
        rate_resolver=rate_resolver,
    )

    return TeacherSalary(
        teacher=teacher,
        salary=salary,
        period_start=date_from,
        period_end=date_to,
        report_type=report_type,
    )


async def studio_stats(
    session: AsyncSession, user: User, *, month: str
) -> StudioResult:
    """Org-wide monthly overview plus a per-teacher salary breakdown."""
    mr = parse_month(month)
    date_from, date_to = mr.start, mr.end

    teachers_result = await session.execute(
        select(User).where(User.org_id == user.org_id, User.role == "TEACHER")
    )
    teachers = teachers_result.scalars().all()

    all_rows_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.org_id == user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    all_rows = all_rows_result.all()

    by_teacher: dict[int, list[tuple[Lesson, StudentTeacher]]] = {}
    for lesson, st in all_rows:
        by_teacher.setdefault(st.teacher_user_id, []).append((lesson, st))

    # Makeup lessons are the same lesson rescheduled — exclude from studio stats.
    all_lessons = [l for l, _ in all_rows if l.lesson_type == "regular"]
    total_done = sum(1 for l in all_lessons if l.status == "attended")
    total_missed = sum(1 for l in all_lessons if l.status == "missed")
    total_cancelled = sum(1 for l in all_lessons if l.status == "cancelled")
    total_scheduled = sum(1 for l in all_lessons if l.status == "scheduled")

    # Active students = the studio's whole active roster (one row per student,
    # so no duplicates), independent of whether they had a lesson in the
    # selected month — mirrors active_teachers, which is the full teacher
    # roster. The previous query joined to lessons in the month, which both
    # missed enrolled students without a lesson that month and double-counted
    # via makeup lessons.
    active_students_result = await session.execute(
        select(func.count(Student.id)).where(
            Student.org_id == user.org_id,
            Student.status == "ACTIVE",
        )
    )
    active_students = active_students_result.scalar() or 0
    # Counter shows the studio's whole teacher roster, not just those who
    # happened to have lessons in the selected month.
    active_teachers = len(teachers)

    # Load every teacher's rates in one query → no N+1.
    teacher_ids = [t.id for t in teachers]
    resolvers = await build_rate_resolvers_bulk(session, user.org_id, teacher_ids)

    teacher_salaries: list[TeacherSalary] = []
    for teacher in teachers:
        rows = by_teacher.get(teacher.id, [])
        salary = await calculate_salary(
            session,
            user.org_id,
            teacher.id,
            rows,
            date_from,
            date_to,
            "final",
            rate_resolver=resolvers.get(teacher.id),
        )
        teacher_salaries.append(
            TeacherSalary(
                teacher=teacher,
                salary=salary,
                period_start=date_from,
                period_end=date_to,
                report_type="final",
            )
        )

    return StudioResult(
        month=month,
        total_done=total_done,
        total_missed=total_missed,
        total_cancelled=total_cancelled,
        total_scheduled=total_scheduled,
        active_students=active_students,
        active_teachers=active_teachers,
        teacher_salaries=teacher_salaries,
    )


async def reset_month(
    session: AsyncSession,
    user: User,
    *,
    month_year: str,
    teacher_id: int | None,
) -> ResetMonthResult:
    """Delete all lessons + subscriptions for a teacher's month (recalc tool).

    Handles the self-referential `makeup_for_id` FK: originals in other
    months get their makeup tracking reset, and makeups linked to deleted
    originals are removed even when scheduled in a different month.
    """
    effective_teacher_id = teacher_id or user.id
    _assert_self_or_admin(user, effective_teacher_id)

    await _require_teacher_in_org(session, effective_teacher_id, user.org_id)

    mr = parse_month(month_year)
    date_from, date_to = mr.start, mr.end

    lessons_result = await session.execute(
        select(Lesson)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == effective_teacher_id,
            StudentTeacher.org_id == user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    lessons = lessons_result.scalars().all()
    lesson_ids = [lesson.id for lesson in lessons]

    lessons_deleted = len(lesson_ids)
    if lesson_ids:
        # Makeups whose originals live in another month → reset those originals.
        original_ids = [
            lesson.makeup_for_id
            for lesson in lessons
            if lesson.makeup_for_id is not None
        ]
        if original_ids:
            await session.execute(
                sa_update(Lesson)
                .where(
                    Lesson.org_id == user.org_id,
                    Lesson.id.in_(original_ids),
                )
                .values(makeup_status="none", makeup_date=None)
            )

        # Delete makeups linked to originals in this month, even if scheduled
        # elsewhere.
        linked_makeups_result = await session.execute(
            select(Lesson.id).where(
                Lesson.org_id == user.org_id,
                Lesson.makeup_for_id.in_(lesson_ids),
                Lesson.id.notin_(lesson_ids),
            )
        )
        linked_makeup_ids = list(linked_makeups_result.scalars().all())
        if linked_makeup_ids:
            lessons_deleted += len(linked_makeup_ids)
            await session.execute(
                sa_delete(Lesson).where(Lesson.id.in_(linked_makeup_ids))
            )

        await session.execute(
            sa_delete(Lesson).where(
                Lesson.org_id == user.org_id,
                Lesson.id.in_(lesson_ids),
            )
        )

    subs_result = await session.execute(
        select(Subscription).where(
            Subscription.org_id == user.org_id,
            Subscription.teacher_user_id == effective_teacher_id,
            Subscription.month_year == month_year,
        )
    )
    subs = subs_result.scalars().all()
    subs_deleted = len(subs)
    for sub in subs:
        await session.delete(sub)

    await session.commit()

    return ResetMonthResult(
        teacher_id=effective_teacher_id,
        lessons_deleted=lessons_deleted,
        subscriptions_deleted=subs_deleted,
    )
