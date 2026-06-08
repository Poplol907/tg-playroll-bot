"""Lesson HTTP routes — thin wrappers over `services.lessons`.

This module **does not** contain business logic. Its only job is:
  * parse query / body parameters,
  * call the matching service function,
  * map domain objects → response models.

Domain exceptions raised by the service are translated to HTTP responses
by the global handler registered in `app.main`.
"""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import Lesson, Student, User
from backend.app.schemas.lessons import (
    LessonBulkIn,
    LessonBulkOut,
    LessonCreateIn,
    LessonMakeupIn,
    LessonOut,
    LessonStatusIn,
)
from backend.app.services import lessons as lesson_service
from backend.app.services.months import parse_month
from backend.app.services.permissions import require_admin_or_teacher

router = APIRouter(prefix="/lessons", tags=["lessons"])


# ─────────────────────────────────────────────────────────────────────────────
#  Serialisation
# ─────────────────────────────────────────────────────────────────────────────


def _to_out(lesson: Lesson, student: Student | None) -> LessonOut:
    student_name = None
    if student is not None:
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


# ─────────────────────────────────────────────────────────────────────────────
#  Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("", response_model=list[LessonOut])
async def list_lessons(
    teacher_id: int | None = None,
    month: str | None = None,
    student_id: int | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    month_range = None
    if month is not None:
        mr = parse_month(month)
        month_range = (mr.start, mr.end)

    rows = await lesson_service.list_lessons(
        session,
        current_user,
        teacher_id=teacher_id,
        student_id=student_id,
        month_range=month_range,
    )
    return [_to_out(row.lesson, row.student) for row in rows]


@router.post("", response_model=LessonOut)
async def create_lesson(
    payload: LessonCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)
    result = await lesson_service.create_lesson(
        session,
        current_user,
        student_teacher_id=payload.student_teacher_id,
        subscription_id=payload.subscription_id,
        scheduled_date=payload.scheduled_date,
        scheduled_time=payload.scheduled_time,
        notes=payload.notes,
    )
    return _to_out(result.lesson, result.student)


@router.post("/bulk", response_model=LessonBulkOut)
async def create_bulk_lessons(
    payload: LessonBulkIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)
    bulk = await lesson_service.bulk_create_lessons(
        session,
        current_user,
        student_teacher_id=payload.student_teacher_id,
        month_year=payload.month_year,
        slots=[
            lesson_service.BulkSlot(weekday=s.weekday, time=s.time)
            for s in payload.slots
        ],
    )
    return LessonBulkOut(
        lessons_created=len(bulk.lessons),
        subscription_id=bulk.subscription_id,
        lessons=[_to_out(l, bulk.student) for l in bulk.lessons],
        warnings=bulk.warnings,
    )


@router.patch("/{lesson_id}/status", response_model=LessonOut)
async def update_lesson_status(
    lesson_id: int,
    payload: LessonStatusIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    result = await lesson_service.update_lesson_status(
        session,
        current_user,
        lesson_id=lesson_id,
        status=payload.status,
        cancelled_by=payload.cancelled_by,
        notes=payload.notes,
    )
    return _to_out(result.lesson, result.student)


@router.post("/{lesson_id}/makeup", response_model=LessonOut)
async def schedule_makeup(
    lesson_id: int,
    payload: LessonMakeupIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Create a makeup lesson linked to a missed/cancelled original.

    When the makeup is later marked as attended, the original lesson is
    closed automatically (see `update_lesson_status`).
    """
    result = await lesson_service.schedule_makeup(
        session,
        current_user,
        lesson_id=lesson_id,
        makeup_date=payload.makeup_date,
    )
    return _to_out(result.lesson, result.student)


@router.delete("/{lesson_id}", status_code=204)
async def delete_lesson(
    lesson_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    await lesson_service.delete_lesson(
        session, current_user, lesson_id=lesson_id
    )
    return Response(status_code=204)
