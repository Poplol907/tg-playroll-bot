from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Lesson, StudentTeacher
from backend.app.schemas.teachers import TeacherOut, TeacherScheduleDay
from backend.app.services.months import parse_month
from backend.app.services.permissions import require_teacher_self_or_admin

router = APIRouter(prefix="/teachers", tags=["teachers"])


@router.get("", response_model=list[TeacherOut])
async def list_teachers(
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    result = await session.execute(
        select(User)
        .where(User.org_id == current_user.org_id, User.role == "TEACHER")
        .order_by(User.teacher_name)
    )
    teachers = result.scalars().all()
    return [TeacherOut(id=t.id, login=t.login, teacher_name=t.teacher_name) for t in teachers]


@router.get("/{teacher_id}/schedule", response_model=list[TeacherScheduleDay])
async def teacher_schedule(
    teacher_id: int,
    month: str,  # '2026-04'
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_teacher_self_or_admin(current_user, teacher_id)

    mr = parse_month(month)

    result = await session.execute(
        select(Lesson)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_id,
            StudentTeacher.org_id == current_user.org_id,
            Lesson.scheduled_date >= mr.start,
            Lesson.scheduled_date <= mr.end,
        )
        .order_by(Lesson.scheduled_date, Lesson.scheduled_time)
    )
    lessons = result.scalars().all()

    # группируем по дню
    days: dict[date, list[str]] = {}
    for lesson in lessons:
        d = lesson.scheduled_date
        if d not in days:
            days[d] = []
        days[d].append(lesson.status)

    return [
        TeacherScheduleDay(
            date=str(d),
            lessons_count=len(statuses),
            statuses=statuses,
        )
        for d, statuses in sorted(days.items())
    ]
