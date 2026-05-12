import calendar as cal_mod
from datetime import date, time as dt_time

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Lesson, StudentTeacher, Student, Subscription
from backend.app.schemas.lessons import (
    LessonBulkIn,
    LessonBulkOut,
    LessonCreateIn,
    LessonStatusIn,
    LessonMakeupIn,
    LessonOut,
)
from backend.app.services.months import parse_month
from backend.app.services.permissions import require_admin_or_teacher

router = APIRouter(prefix="/lessons", tags=["lessons"])

VALID_STATUSES = {"scheduled", "attended", "missed", "cancelled"}
VALID_CANCELLED_BY = {"student", "teacher"}
VALID_MAKEUP_STATUSES = {"scheduled", "done", "transferred"}


@router.get("", response_model=list[LessonOut])
async def list_lessons(
    teacher_id: int | None = None,
    month: str | None = None,   # '2026-04'
    student_id: int | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    q = (
        select(Lesson, Student)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(Lesson.org_id == current_user.org_id)
    )

    if current_user.role == "TEACHER":
        q = q.where(StudentTeacher.teacher_user_id == current_user.id)
    elif teacher_id is not None:
        q = q.where(StudentTeacher.teacher_user_id == teacher_id)

    if student_id is not None:
        q = q.where(StudentTeacher.student_id == student_id)

    if month is not None:
        mr = parse_month(month)
        q = q.where(
            Lesson.scheduled_date >= mr.start,
            Lesson.scheduled_date <= mr.end,
        )

    result = await session.execute(q.order_by(Lesson.scheduled_date, Lesson.scheduled_time))
    rows = result.all()

    return [_to_out(lesson, student) for lesson, student in rows]


@router.post("", response_model=LessonOut)
async def create_lesson(
    payload: LessonCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    # Загружаем student_teacher + student одним JOIN-запросом
    st_q = await session.execute(
        select(StudentTeacher, Student)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(
            StudentTeacher.id == payload.student_teacher_id,
            StudentTeacher.org_id == current_user.org_id,
        )
    )
    row = st_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="student_teacher not found")
    st, student = row

    if current_user.role == "TEACHER" and st.teacher_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    # Check if this teacher already has a lesson with ANY student at the same date+time
    if payload.scheduled_time is not None:
        conflict_res = await session.execute(
            select(Lesson)
            .join(StudentTeacher, Lesson.student_teacher_id == StudentTeacher.id)
            .where(
                StudentTeacher.teacher_user_id == st.teacher_user_id,
                StudentTeacher.org_id == current_user.org_id,
                Lesson.scheduled_date == payload.scheduled_date,
                Lesson.scheduled_time == payload.scheduled_time,
            )
        )
        if conflict_res.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=409,
                detail="Это время уже занято другим учеником. Выберите другое время.",
            )

    lesson = Lesson(
        org_id=current_user.org_id,
        student_teacher_id=payload.student_teacher_id,
        subscription_id=payload.subscription_id,
        scheduled_date=payload.scheduled_date,
        scheduled_time=payload.scheduled_time,
        notes=payload.notes,
    )
    session.add(lesson)
    await session.commit()
    await session.refresh(lesson)

    return _to_out(lesson, student)


@router.post("/bulk", response_model=LessonBulkOut)
async def create_bulk_lessons(
    payload: LessonBulkIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Bulk-create lessons for one student for a given month.

    Algorithm:
    1. Validate the student_teacher link.
    2. For each slot (weekday + time) iterate every day of the month —
       collect all matching (date, time) pairs.
    3. Skip dates that already have a lesson at the same time (return as warnings).
    4. Create a Subscription with lessons_count = # of new lessons.
    5. Create all new Lesson rows linked to the subscription.
    """
    require_admin_or_teacher(current_user)

    if not payload.slots:
        raise HTTPException(status_code=422, detail="slots list is empty")

    # ── 1. Validate student_teacher ──────────────────────────────────────────
    st_q = await session.execute(
        select(StudentTeacher, Student)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(
            StudentTeacher.id == payload.student_teacher_id,
            StudentTeacher.org_id == current_user.org_id,
        )
    )
    row = st_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="student_teacher not found")
    st, student = row

    if current_user.role == "TEACHER" and st.teacher_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    # ── 2. Generate (date, time) pairs ──────────────────────────────────────
    year, month = map(int, payload.month_year.split("-"))
    _, days_in_month = cal_mod.monthrange(year, month)

    # slot.weekday → list of "HH:MM" strings
    by_weekday: dict[int, list[str]] = {}
    for slot in payload.slots:
        by_weekday.setdefault(slot.weekday, []).append(slot.time)

    desired: list[tuple[date, str]] = []
    for day_num in range(1, days_in_month + 1):
        d = date(year, month, day_num)
        wd = d.weekday()  # 0=Mon, 6=Sun
        for t_str in by_weekday.get(wd, []):
            desired.append((d, t_str))

    desired.sort()

    if not desired:
        raise HTTPException(
            status_code=422,
            detail="No matching dates found for the given slots in this month",
        )

    # ── 3. Check for existing lessons on the same date+time ─────────────────
    date_from = date(year, month, 1)
    date_to = date(year, month, days_in_month)

    def _time_key(raw) -> str | None:
        if raw is None:
            return None
        s = str(raw)
        return s[:5]  # "HH:MM"

    # Lessons for the same student-teacher (same student duplicates)
    existing_res = await session.execute(
        select(Lesson).where(
            Lesson.student_teacher_id == payload.student_teacher_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    existing = existing_res.scalars().all()
    existing_keys = {(l.scheduled_date, _time_key(l.scheduled_time)) for l in existing}

    # Lessons for OTHER students of the same teacher (time conflicts)
    conflict_res = await session.execute(
        select(Lesson.scheduled_date, Lesson.scheduled_time)
        .join(StudentTeacher, Lesson.student_teacher_id == StudentTeacher.id)
        .where(
            StudentTeacher.teacher_user_id == st.teacher_user_id,
            StudentTeacher.org_id == current_user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
            Lesson.student_teacher_id != payload.student_teacher_id,
        )
    )
    conflict_keys = {(row[0], _time_key(row[1])) for row in conflict_res.all()}

    warnings: list[str] = []
    to_create: list[tuple[date, str]] = []
    for d, t_str in desired:
        t_key = t_str[:5]
        if (d, t_key) in existing_keys:
            warnings.append(f"{d.strftime('%d.%m.%Y')} {t_str} — урок уже существует у этого ученика")
        elif (d, t_key) in conflict_keys:
            warnings.append(f"{d.strftime('%d.%m.%Y')} {t_str} — время занято другим учеником")
        else:
            to_create.append((d, t_str))

    if not to_create:
        raise HTTPException(
            status_code=400,
            detail="all selected slots already have lessons in this month",
        )

    # ── 4. Upsert Subscription ───────────────────────────────────────────────
    # Look for an existing subscription for this student/teacher/month so that
    # repeated calls to the schedule-builder don't create duplicate rows that
    # inflate goal_amount in salary reports.
    existing_sub_res = await session.execute(
        select(Subscription).where(
            Subscription.org_id == current_user.org_id,
            Subscription.student_id == student.id,
            Subscription.teacher_user_id == st.teacher_user_id,
            Subscription.month_year == payload.month_year,
        )
    )
    sub = existing_sub_res.scalars().first()

    if sub is None:
        sub = Subscription(
            org_id=current_user.org_id,
            student_id=student.id,
            teacher_user_id=st.teacher_user_id,
            month_year=payload.month_year,
            lessons_count=len(to_create),
        )
        session.add(sub)
    else:
        # Accumulate count in the single authoritative subscription row.
        sub.lessons_count += len(to_create)

    await session.flush()  # populate sub.id before linking lessons

    # ── 5. Create Lessons ────────────────────────────────────────────────────
    created: list[Lesson] = []
    for lesson_date, t_str in to_create:
        h, m = map(int, t_str.split(":"))
        lesson = Lesson(
            org_id=current_user.org_id,
            student_teacher_id=payload.student_teacher_id,
            subscription_id=sub.id,
            scheduled_date=lesson_date,
            scheduled_time=dt_time(h, m),
        )
        session.add(lesson)
        created.append(lesson)

    await session.commit()
    for l in created:
        await session.refresh(l)

    return LessonBulkOut(
        lessons_created=len(created),
        subscription_id=sub.id,
        lessons=[_to_out(l, student) for l in created],
        warnings=warnings,
    )


@router.patch("/{lesson_id}/status", response_model=LessonOut)
async def update_lesson_status(
    lesson_id: int,
    payload: LessonStatusIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    lesson, st, student = await _get_lesson_with_st(session, lesson_id, current_user)

    if payload.status not in VALID_STATUSES:
        raise HTTPException(status_code=422, detail=f"invalid status: {payload.status}")

    if payload.status == "cancelled":
        if payload.cancelled_by not in VALID_CANCELLED_BY:
            raise HTTPException(status_code=422, detail="cancelled_by must be 'student' or 'teacher'")
        lesson.cancelled_by = payload.cancelled_by
        lesson.makeup_status = "none"
    else:
        lesson.cancelled_by = None
        # When reverting to scheduled (or any non-cancelled status), clear makeup
        # tracking so stale makeup_date/makeup_status don't reappear on the next
        # missed/cancelled cycle.  Also cancel any pending orphan makeup lessons.
        if payload.status == "scheduled":
            lesson.makeup_status = "none"
            lesson.makeup_date = None
            # Hard-delete orphaned makeup lessons so they disappear
            # from the calendar immediately (cancelling leaves them visible).
            await session.execute(
                sa_delete(Lesson).where(
                    Lesson.makeup_for_id == lesson.id,
                    Lesson.status == "scheduled",
                )
            )

    lesson.status = payload.status

    if payload.status == "attended":
        lesson.payment_counted = True

    if payload.notes is not None:
        lesson.notes = payload.notes

    # Если это урок-отработка и он помечен как attended →
    # автоматически закрываем оригинальный урок
    if lesson.lesson_type == "makeup" and payload.status == "attended" and lesson.makeup_for_id:
        original_res = await session.execute(
            select(Lesson).where(Lesson.id == lesson.makeup_for_id)
        )
        original = original_res.scalar_one_or_none()
        if original:
            original.makeup_status = "done"
            original.makeup_date = lesson.scheduled_date
            original.payment_counted = True

    await session.commit()
    await session.refresh(lesson)
    return _to_out(lesson, student)


@router.post("/{lesson_id}/makeup", response_model=LessonOut)
async def schedule_makeup(
    lesson_id: int,
    payload: LessonMakeupIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """
    Создаёт новый урок-отработку на выбранную дату.
    Оригинальный урок → makeup_status = 'scheduled'.
    Когда урок-отработка будет помечен как attended → оригинал → makeup_status = 'done'.
    """
    original, st, student = await _get_lesson_with_st(session, lesson_id, current_user)

    if original.status not in ("missed", "cancelled"):
        raise HTTPException(
            status_code=400,
            detail="makeup only available for missed or cancelled lessons",
        )

    if original.makeup_status in ("scheduled", "done"):
        raise HTTPException(
            status_code=400,
            detail="lesson already has a pending or completed makeup",
        )

    makeup_lesson = Lesson(
        org_id=original.org_id,
        student_teacher_id=original.student_teacher_id,
        subscription_id=None,
        lesson_type="makeup",
        makeup_for_id=original.id,
        scheduled_date=payload.makeup_date,
        scheduled_time=original.scheduled_time,
        status="scheduled",
        payment_counted=False,
    )
    session.add(makeup_lesson)

    original.makeup_status = "scheduled"
    original.makeup_date = payload.makeup_date

    await session.commit()
    await session.refresh(makeup_lesson)
    return _to_out(makeup_lesson, student)


@router.delete("/{lesson_id}", status_code=204)
async def delete_lesson(
    lesson_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Удаляет урок вместе со всеми связанными уроками-отработками.

    Использует LEFT JOIN чтобы корректно обрабатывать «сиротские» уроки,
    у которых student_teacher уже удалён (INNER JOIN в таком случае вернул бы 0 строк → 404).
    """
    result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(
            StudentTeacher,
            StudentTeacher.id == Lesson.student_teacher_id,
            isouter=True,
        )
        .where(Lesson.id == lesson_id, Lesson.org_id == current_user.org_id)
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="lesson not found")

    lesson, st = row

    # Проверка прав только когда student_teacher ещё существует.
    if st is not None and current_user.role == "TEACHER" and st.teacher_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    # Если удаляем оригинальный урок — сначала удаляем его отработки
    await session.execute(
        sa_delete(Lesson).where(Lesson.makeup_for_id == lesson.id)
    )

    # Если удаляем отработку — очищаем поля на оригинале
    if lesson.makeup_for_id is not None:
        original_res = await session.execute(
            select(Lesson).where(Lesson.id == lesson.makeup_for_id)
        )
        original = original_res.scalar_one_or_none()
        if original:
            original.makeup_status = "none"
            original.makeup_date = None

    # Уменьшаем счётчик уроков в подписке чтобы goal_amount оставался точным.
    # Если уроков в подписке больше нет — удаляем саму подписку.
    if lesson.subscription_id is not None:
        sub = await session.get(Subscription, lesson.subscription_id)
        if sub is not None:
            sub.lessons_count = max(0, sub.lessons_count - 1)
            if sub.lessons_count == 0:
                await session.delete(sub)

    await session.delete(lesson)
    await session.commit()
    return Response(status_code=204)


def _to_out(lesson: Lesson, student: Student | None = None) -> LessonOut:
    student_name = None
    if student:
        student_name = f"{student.first_name} {student.last_name}".strip()
    return LessonOut(
        id=lesson.id,
        org_id=lesson.org_id,
        student_teacher_id=lesson.student_teacher_id,
        subscription_id=lesson.subscription_id,
        lesson_type=lesson.lesson_type,
        makeup_for_id=lesson.makeup_for_id,
        scheduled_date=lesson.scheduled_date,
        scheduled_time=lesson.scheduled_time,
        status=lesson.status,
        cancelled_by=lesson.cancelled_by,
        makeup_status=lesson.makeup_status,
        makeup_date=lesson.makeup_date,
        payment_counted=lesson.payment_counted,
        notes=lesson.notes,
        student_name=student_name,
    )


async def _get_lesson_with_st(
    session: AsyncSession, lesson_id: int, user: User
) -> tuple[Lesson, StudentTeacher, Student | None]:
    """Загружает урок + StudentTeacher + Student одним JOIN-запросом."""
    result = await session.execute(
        select(Lesson, StudentTeacher, Student)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(Lesson.id == lesson_id, Lesson.org_id == user.org_id)
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="lesson not found")

    lesson, st, student = row

    if user.role == "TEACHER" and st.teacher_user_id != user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    return lesson, st, student
