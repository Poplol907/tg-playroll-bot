"""Reporting HTTP routes — thin wrappers over `services.reports`.

This module **does not** contain business logic. Its only job is:
  * parse query parameters,
  * call the matching service function,
  * map domain dataclasses → response models.

Domain exceptions raised by the service are translated to HTTP responses
by the global handler registered in `app.main`.
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.reports_v2 import (
    SalaryReportOut,
    SalaryV2Out,
    StudioStatsOut,
)
from backend.app.services import reports as report_service
from backend.app.services.permissions import (
    require_admin,
    require_admin_or_teacher,
)

router = APIRouter(prefix="/reports", tags=["reports"])


# ─────────────────────────────────────────────────────────────────────────────
#  Serialisation
# ─────────────────────────────────────────────────────────────────────────────


def _salary_to_out(
    ts: report_service.TeacherSalary, month: str
) -> SalaryReportOut:
    return SalaryReportOut(
        teacher_id=ts.teacher.id,
        teacher_name=ts.teacher.teacher_name,
        month=month,
        period_start=ts.period_start,
        period_end=ts.period_end,
        report_type=ts.report_type,
        lessons_done=ts.salary.lessons_done,
        lessons_missed=ts.salary.lessons_missed,
        lessons_debt=ts.salary.lessons_debt,
        lessons_cancelled_makeup=ts.salary.lessons_makeup_done,
        total_amount=ts.salary.total_amount,
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/v2/salary", response_model=SalaryV2Out)
async def salary_report_v2(
    month_year: str = Query(..., description="YYYY-MM, например 2026-04"),
    teacher_id: int | None = Query(
        None,
        description="Опционально: смотреть зарплату конкретного педагога (только админ)",
    ),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Зарплата педагога за месяц с геймификацией.

    По умолчанию — зарплата текущего пользователя. Админ может передать
    `?teacher_id=X` и увидеть зарплату того педагога (view-as).
    """
    require_admin_or_teacher(current_user)
    r = await report_service.salary_v2(
        session, current_user, month_year=month_year, teacher_id=teacher_id
    )
    return SalaryV2Out(
        month_year=month_year,
        period_start=r.period_start,
        period_end=r.period_end,
        goal_amount=r.goal_amount,
        total_subscribed=r.total_subscribed,
        earned_amount=r.earned_amount,
        pending_amount=r.pending_amount,
        total_current=r.total_current,
        lessons_done=r.lessons_done,
        lessons_missed=r.lessons_missed,
        lessons_debt=r.lessons_debt,
        lessons_makeup_done=r.lessons_makeup_done,
        advance_amount=r.advance_amount,
        final_amount=r.final_amount,
        total_amount=r.total_amount,
    )


@router.get("/salary", response_model=SalaryReportOut)
async def salary_report(
    month: str = Query(..., examples=["2026-04"]),
    teacher_id: int = Query(...),
    report_type: str = Query("final", description="advance или final"),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    ts = await report_service.salary_report(
        session,
        current_user,
        month=month,
        teacher_id=teacher_id,
        report_type=report_type,
    )
    return _salary_to_out(ts, month)


@router.get("/studio", response_model=StudioStatsOut)
async def studio_report(
    month: str = Query(..., examples=["2026-04"]),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    r = await report_service.studio_stats(session, current_user, month=month)
    return StudioStatsOut(
        month=r.month,
        total_lessons_done=r.total_done,
        total_lessons_missed=r.total_missed,
        total_lessons_cancelled=r.total_cancelled,
        total_lessons_scheduled=r.total_scheduled,
        active_students=r.active_students,
        active_teachers=r.active_teachers,
        teachers=[_salary_to_out(ts, month) for ts in r.teacher_salaries],
    )


@router.delete("/v2/reset-month", status_code=200)
async def reset_month(
    month_year: str = Query(..., description="YYYY-MM, например 2026-05"),
    teacher_id: int | None = Query(
        None,
        description="Опционально: сбросить месяц конкретного педагога (только админ)",
    ),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Удаляет все уроки и подписки за месяц для педагога (инструмент пересчёта)."""
    require_admin_or_teacher(current_user)
    r = await report_service.reset_month(
        session, current_user, month_year=month_year, teacher_id=teacher_id
    )
    return {
        "month_year": month_year,
        "teacher_id": r.teacher_id,
        "lessons_deleted": r.lessons_deleted,
        "subscriptions_deleted": r.subscriptions_deleted,
    }
