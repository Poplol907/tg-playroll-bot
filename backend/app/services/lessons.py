"""Lesson management service.

All business logic for lessons lives here:

* listing with role-based filters,
* single + bulk creation with conflict detection,
* status transitions (attended / missed / cancelled),
* makeup scheduling and auto-completion,
* deletion with cascading cleanup of subscriptions and makeup links.

Functions raise `services.errors.DomainError` subclasses on failure —
NEVER `HTTPException`. The router translates them at the boundary.

Each public function takes an `AsyncSession` and a `User` (the actor),
and the request payload. They return domain objects (SQLAlchemy models
or simple dataclasses), not HTTP response models.
"""

from __future__ import annotations

import calendar as cal_mod
from dataclasses import dataclass
from datetime import date, time as dt_time
from typing import Iterable

from sqlalchemy import delete as sa_delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import Lesson, Student, StudentTeacher, Subscription, User
from backend.app.services.errors import (
    BusinessRuleViolation,
    Conflict,
    Forbidden,
    NotFound,
    ValidationError,
)

# ─────────────────────────────────────────────────────────────────────────────
#  Constants (domain vocabulary)
# ─────────────────────────────────────────────────────────────────────────────

VALID_STATUSES = {"scheduled", "attended", "missed", "cancelled"}
VALID_CANCELLED_BY = {"student", "teacher"}
VALID_MAKEUP_STATUSES = {"none", "scheduled", "done"}


# ─────────────────────────────────────────────────────────────────────────────
#  Result objects
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class LessonWithStudent:
    """Lesson plus its denormalised student handle for response building."""

    lesson: Lesson
    student: Student | None


@dataclass
class BulkResult:
    lessons: list[Lesson]
    subscription_id: int
    warnings: list[str]
    student: Student


# ─────────────────────────────────────────────────────────────────────────────
#  Internal helpers (kept private to the service)
# ─────────────────────────────────────────────────────────────────────────────


def _ensure_teacher_owns(user: User, st: StudentTeacher) -> None:
    """A teacher can only touch lessons that belong to their own students."""
    if user.role == "TEACHER" and st.teacher_user_id != user.id:
        raise Forbidden("You can only manage your own students' lessons")


def _time_key(raw) -> str | None:
    """Normalise time to 'HH:MM' for set-based comparisons."""
    if raw is None:
        return None
    return str(raw)[:5]


async def _load_student_teacher(
    session: AsyncSession, st_id: int, org_id: int
) -> tuple[StudentTeacher, Student]:
    result = await session.execute(
        select(StudentTeacher, Student)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(
            StudentTeacher.id == st_id,
            StudentTeacher.org_id == org_id,
        )
    )
    row = result.first()
    if row is None:
        raise NotFound("student_teacher not found")
    return row


async def _load_lesson_with_st(
    session: AsyncSession, lesson_id: int, user: User
) -> tuple[Lesson, StudentTeacher, Student]:
    result = await session.execute(
        select(Lesson, StudentTeacher, Student)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(Lesson.id == lesson_id, Lesson.org_id == user.org_id)
    )
    row = result.first()
    if row is None:
        raise NotFound("lesson not found")

    lesson, st, student = row
    _ensure_teacher_owns(user, st)
    return lesson, st, student


# ─────────────────────────────────────────────────────────────────────────────
#  Listing
# ─────────────────────────────────────────────────────────────────────────────


async def list_lessons(
    session: AsyncSession,
    user: User,
    *,
    teacher_id: int | None = None,
    month_range: tuple[date, date] | None = None,
    student_id: int | None = None,
) -> list[LessonWithStudent]:
    """List lessons honouring role-based visibility rules.

    * TEACHER sees only their own lessons.
    * ADMIN sees the whole org, optionally filtered by teacher_id.
    """
    q = (
        select(Lesson, Student)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(Lesson.org_id == user.org_id)
    )

    if user.role == "TEACHER":
        q = q.where(StudentTeacher.teacher_user_id == user.id)
    elif teacher_id is not None:
        q = q.where(StudentTeacher.teacher_user_id == teacher_id)

    if student_id is not None:
        q = q.where(StudentTeacher.student_id == student_id)

    if month_range is not None:
        start, end = month_range
        q = q.where(Lesson.scheduled_date >= start, Lesson.scheduled_date <= end)

    result = await session.execute(
        q.order_by(Lesson.scheduled_date, Lesson.scheduled_time)
    )
    return [LessonWithStudent(l, s) for l, s in result.all()]


# ─────────────────────────────────────────────────────────────────────────────
#  Single create
# ─────────────────────────────────────────────────────────────────────────────


async def create_lesson(
    session: AsyncSession,
    user: User,
    *,
    student_teacher_id: int,
    subscription_id: int | None,
    scheduled_date: date,
    scheduled_time: dt_time | None,
    notes: str | None = None,
) -> LessonWithStudent:
    """Create a single lesson, refusing time-slot conflicts."""
    st, student = await _load_student_teacher(session, student_teacher_id, user.org_id)
    _ensure_teacher_owns(user, st)

    if scheduled_time is not None:
        conflict_res = await session.execute(
            select(Lesson)
            .join(StudentTeacher, Lesson.student_teacher_id == StudentTeacher.id)
            .where(
                StudentTeacher.teacher_user_id == st.teacher_user_id,
                StudentTeacher.org_id == user.org_id,
                Lesson.scheduled_date == scheduled_date,
                Lesson.scheduled_time == scheduled_time,
            )
        )
        if conflict_res.scalar_one_or_none() is not None:
            raise Conflict(
                "Это время уже занято другим учеником. Выберите другое время."
            )

    lesson = Lesson(
        org_id=user.org_id,
        student_teacher_id=student_teacher_id,
        subscription_id=subscription_id,
        scheduled_date=scheduled_date,
        scheduled_time=scheduled_time,
        notes=notes,
    )
    session.add(lesson)
    await session.commit()
    await session.refresh(lesson)
    return LessonWithStudent(lesson, student)


# ─────────────────────────────────────────────────────────────────────────────
#  Bulk create
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class BulkSlot:
    weekday: int  # 0=Mon … 6=Sun
    time: str  # "HH:MM"


async def bulk_create_lessons(
    session: AsyncSession,
    user: User,
    *,
    student_teacher_id: int,
    month_year: str,
    slots: Iterable[BulkSlot],
) -> BulkResult:
    """Create lessons for a whole month from weekly slot patterns.

    Steps:
      1. Validate the student_teacher link and authorisation.
      2. Expand slots to concrete (date, time) pairs for the month.
      3. Skip dates that already have a lesson at the same time (warnings).
      4. Upsert the monthly Subscription row.
      5. Create the new lessons linked to that subscription.
    """
    slots = list(slots)
    if not slots:
        raise ValidationError("slots list is empty")

    st, student = await _load_student_teacher(session, student_teacher_id, user.org_id)
    _ensure_teacher_owns(user, st)

    year, month = map(int, month_year.split("-"))
    _, days_in_month = cal_mod.monthrange(year, month)

    by_weekday: dict[int, list[str]] = {}
    for slot in slots:
        by_weekday.setdefault(slot.weekday, []).append(slot.time)

    desired: list[tuple[date, str]] = []
    for day_num in range(1, days_in_month + 1):
        d = date(year, month, day_num)
        for t_str in by_weekday.get(d.weekday(), []):
            desired.append((d, t_str))
    desired.sort()

    if not desired:
        raise ValidationError(
            "No matching dates found for the given slots in this month"
        )

    date_from = date(year, month, 1)
    date_to = date(year, month, days_in_month)

    # Lessons for the same student (skip duplicates)
    existing_res = await session.execute(
        select(Lesson).where(
            Lesson.student_teacher_id == student_teacher_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    existing_keys = {
        (l.scheduled_date, _time_key(l.scheduled_time))
        for l in existing_res.scalars().all()
    }

    # Lessons for OTHER students of the same teacher (time conflicts)
    conflict_res = await session.execute(
        select(Lesson.scheduled_date, Lesson.scheduled_time)
        .join(StudentTeacher, Lesson.student_teacher_id == StudentTeacher.id)
        .where(
            StudentTeacher.teacher_user_id == st.teacher_user_id,
            StudentTeacher.org_id == user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
            Lesson.student_teacher_id != student_teacher_id,
        )
    )
    conflict_keys = {(row[0], _time_key(row[1])) for row in conflict_res.all()}

    warnings: list[str] = []
    to_create: list[tuple[date, str]] = []
    for d, t_str in desired:
        t_key = t_str[:5]
        if (d, t_key) in existing_keys:
            warnings.append(
                f"{d.strftime('%d.%m.%Y')} {t_str} — урок уже существует у этого ученика"
            )
        elif (d, t_key) in conflict_keys:
            warnings.append(
                f"{d.strftime('%d.%m.%Y')} {t_str} — время занято другим учеником"
            )
        else:
            to_create.append((d, t_str))

    if not to_create:
        raise BusinessRuleViolation(
            "all selected slots already have lessons in this month"
        )

    # Upsert Subscription — keep a single authoritative row per
    # (student, teacher, month) so repeated calls don't inflate goal_amount.
    existing_sub_res = await session.execute(
        select(Subscription).where(
            Subscription.org_id == user.org_id,
            Subscription.student_id == student.id,
            Subscription.teacher_user_id == st.teacher_user_id,
            Subscription.month_year == month_year,
        )
    )
    sub = existing_sub_res.scalars().first()

    if sub is None:
        sub = Subscription(
            org_id=user.org_id,
            student_id=student.id,
            teacher_user_id=st.teacher_user_id,
            month_year=month_year,
            lessons_count=len(to_create),
        )
        session.add(sub)
    else:
        sub.lessons_count += len(to_create)

    await session.flush()  # populate sub.id before linking lessons

    created: list[Lesson] = []
    for lesson_date, t_str in to_create:
        h, m = map(int, t_str.split(":"))
        lesson = Lesson(
            org_id=user.org_id,
            student_teacher_id=student_teacher_id,
            subscription_id=sub.id,
            scheduled_date=lesson_date,
            scheduled_time=dt_time(h, m),
        )
        session.add(lesson)
        created.append(lesson)

    await session.commit()
    for l in created:
        await session.refresh(l)

    return BulkResult(
        lessons=created,
        subscription_id=sub.id,
        warnings=warnings,
        student=student,
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Status transition
# ─────────────────────────────────────────────────────────────────────────────


async def update_lesson_status(
    session: AsyncSession,
    user: User,
    *,
    lesson_id: int,
    status: str,
    cancelled_by: str | None = None,
    notes: str | None = None,
) -> LessonWithStudent:
    """Move a lesson into a new lifecycle status, applying side-effects.

    Side-effects:
      * Cancelled → record `cancelled_by`.
      * Attended → flip `payment_counted`; if THIS is an attended makeup, close
        its original.
      * EVERY transition runs `_sync_makeup`, which reconciles the lesson's
        makeup rows + derived cache: makeups of a now-resolved original are
        deleted (no orphans), a still-owed original keeps its makeup and mirrors
        its state (no duplicates).
    """
    lesson, _st, student = await _load_lesson_with_st(session, lesson_id, user)

    if status not in VALID_STATUSES:
        raise ValidationError(f"invalid status: {status}")

    if status == "cancelled":
        if cancelled_by not in VALID_CANCELLED_BY:
            raise ValidationError("cancelled_by must be 'student' or 'teacher'")
        lesson.cancelled_by = cancelled_by
    else:
        lesson.cancelled_by = None

    lesson.status = status

    if status == "attended":
        lesson.payment_counted = True

    if notes is not None:
        lesson.notes = notes

    # Auto-close the original when THIS lesson is an attended makeup.
    if (
        lesson.lesson_type == "makeup"
        and status == "attended"
        and lesson.makeup_for_id
    ):
        original = (
            await session.execute(
                select(Lesson).where(Lesson.id == lesson.makeup_for_id)
            )
        ).scalar_one_or_none()
        if original:
            original.payment_counted = True
            await _sync_makeup(session, original)

    # Reconcile THIS lesson's own makeup links for EVERY transition — not just
    # →scheduled — so a corrected original can never orphan a makeup and a
    # re-cancelled original can never spawn a duplicate.
    await _sync_makeup(session, lesson)

    await session.commit()
    await session.refresh(lesson)
    return LessonWithStudent(lesson, student)


# ─────────────────────────────────────────────────────────────────────────────
#  Makeup lifecycle
# ─────────────────────────────────────────────────────────────────────────────


async def _sync_makeup(session: AsyncSession, original: Lesson) -> None:
    """Reconcile a lesson's makeup rows + its derived makeup cache to its status.

    Invariant: the makeup `Lesson` row is the source of truth; the original's
    `makeup_status`/`makeup_date` are a derived cache written ONLY here (and via
    the attended-makeup auto-close, which delegates here).

      * original resolved (attended / scheduled) → any makeup is spurious:
        delete every makeup row and clear the cache.
      * original still owes a makeup (missed / cancelled) → keep the rows and
        derive the cache from the surviving row (done > scheduled > none).
    """
    rows = (
        await session.execute(
            select(Lesson).where(Lesson.makeup_for_id == original.id)
        )
    ).scalars().all()

    if original.status not in ("missed", "cancelled"):
        for makeup in rows:
            await session.delete(makeup)
        original.makeup_status = "none"
        original.makeup_date = None
        return

    done = next((m for m in rows if m.status == "attended"), None)
    pending = next((m for m in rows if m.status == "scheduled"), None)
    if done is not None:
        original.makeup_status = "done"
        original.makeup_date = done.scheduled_date
    elif pending is not None:
        original.makeup_status = "scheduled"
        original.makeup_date = pending.scheduled_date
    else:
        original.makeup_status = "none"
        original.makeup_date = None


async def schedule_makeup(
    session: AsyncSession,
    user: User,
    *,
    lesson_id: int,
    makeup_date: date,
) -> LessonWithStudent:
    """Create a new makeup lesson linked to the missed/cancelled original."""
    original, _st, student = await _load_lesson_with_st(session, lesson_id, user)

    if original.status not in ("missed", "cancelled"):
        raise BusinessRuleViolation(
            "makeup only available for missed or cancelled lessons"
        )

    # Guard on an existing makeup ROW, not the cached status field, so a stale
    # cache can never let a duplicate makeup slip through.
    existing = (
        await session.execute(
            select(Lesson).where(
                Lesson.makeup_for_id == original.id,
                Lesson.status.in_(("scheduled", "attended")),
            )
        )
    ).scalars().first()
    if existing is not None:
        raise BusinessRuleViolation(
            "lesson already has a pending or completed makeup"
        )

    makeup_lesson = Lesson(
        org_id=original.org_id,
        student_teacher_id=original.student_teacher_id,
        subscription_id=None,
        lesson_type="makeup",
        makeup_for_id=original.id,
        scheduled_date=makeup_date,
        scheduled_time=original.scheduled_time,
        status="scheduled",
        payment_counted=False,
    )
    session.add(makeup_lesson)

    original.makeup_status = "scheduled"
    original.makeup_date = makeup_date

    await session.commit()
    await session.refresh(makeup_lesson)
    return LessonWithStudent(makeup_lesson, student)


# ─────────────────────────────────────────────────────────────────────────────
#  Deletion
# ─────────────────────────────────────────────────────────────────────────────


async def delete_lesson(
    session: AsyncSession,
    user: User,
    *,
    lesson_id: int,
) -> None:
    """Delete a lesson and clean up related state.

    Handles three cases:
      1. Deleting an original lesson → also cascade-delete its makeups.
      2. Deleting a makeup → clear makeup_status / makeup_date on original.
      3. Always decrement the subscription's lesson count (delete sub at 0)
         so the salary `goal_amount` stays accurate.

    Uses LEFT JOIN so orphaned lessons (whose student_teacher was deleted)
    can still be removed instead of 404-ing.
    """
    result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(
            StudentTeacher,
            StudentTeacher.id == Lesson.student_teacher_id,
            isouter=True,
        )
        .where(Lesson.id == lesson_id, Lesson.org_id == user.org_id)
    )
    row = result.first()
    if row is None:
        raise NotFound("lesson not found")

    lesson, st = row

    if st is not None and user.role == "TEACHER" and st.teacher_user_id != user.id:
        raise Forbidden("You can only delete your own students' lessons")

    # Cascade-delete makeup lessons of this lesson (if any).
    await session.execute(
        sa_delete(Lesson).where(Lesson.makeup_for_id == lesson.id)
    )

    # If THIS is a makeup, clear makeup tracking on its original.
    if lesson.makeup_for_id is not None:
        original_res = await session.execute(
            select(Lesson).where(Lesson.id == lesson.makeup_for_id)
        )
        original = original_res.scalar_one_or_none()
        if original:
            original.makeup_status = "none"
            original.makeup_date = None

    # Decrement subscription count; drop empty subscriptions.
    if lesson.subscription_id is not None:
        sub = await session.get(Subscription, lesson.subscription_id)
        if sub is not None:
            sub.lessons_count = max(0, sub.lessons_count - 1)
            if sub.lessons_count == 0:
                await session.delete(sub)

    await session.delete(lesson)
    await session.commit()
