from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Report
from backend.app.schemas.reports import (
    CalcLineOut,
    CalcOut,
    CalcSavedOut,
    CalcTextIn,
    ReportFullOut,
    ReportShortOut,
)
from backend.app.services.permissions import require_admin_or_teacher

router = APIRouter(tags=["reports"])


def _parse_calc_lines(text: str) -> tuple[list[CalcLineOut], int]:
    """Парсит текст вида 'Имя Фамилия уроки цена' → (lines, total_sum)."""
    lines_out: list[CalcLineOut] = []
    total_sum = 0

    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split()
        if len(parts) != 4:
            continue
        first, last, lessons_s, price_s = parts
        try:
            lessons = int(lessons_s)
            price = int(price_s)
        except ValueError:
            continue
        total = lessons * price
        total_sum += total
        lines_out.append(CalcLineOut(first=first, last=last, lessons=lessons, price=price, total=total))

    return lines_out, total_sum


@router.post("/calc/text", response_model=CalcOut)
async def calc_text(payload: CalcTextIn):
    lines_out, total_sum = _parse_calc_lines(payload.text)
    return CalcOut(count=len(lines_out), sum=total_sum, lines=lines_out)


@router.post("/calc/save-text", response_model=CalcSavedOut)
async def calc_save_text(
    payload: CalcTextIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    lines_out, total_sum = _parse_calc_lines(payload.text)

    if not lines_out:
        raise HTTPException(status_code=400, detail="no valid lines")

    report = Report(
        teacher_user_id=current_user.id,
        total_sum=total_sum,
        raw_text=payload.text,
    )
    session.add(report)
    await session.commit()
    await session.refresh(report)

    return CalcSavedOut(report_id=report.id, count=len(lines_out), sum=total_sum, lines=lines_out)


@router.get("/reports/last", response_model=ReportShortOut)
async def reports_last(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    rq = await session.execute(
        select(Report)
        .where(Report.teacher_user_id == current_user.id)
        .order_by(Report.id.desc())
        .limit(1)
    )
    rep = rq.scalar_one_or_none()

    if rep is None:
        raise HTTPException(status_code=404, detail="no reports yet")

    return ReportShortOut(
        report_id=rep.id,
        created_at=rep.created_at.isoformat(),
        total_sum=rep.total_sum,
    )


@router.get("/reports/{report_id}", response_model=ReportFullOut)
async def report_by_id(
    report_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    rq = await session.execute(select(Report).where(Report.id == report_id))
    rep = rq.scalar_one_or_none()

    if rep is None:
        raise HTTPException(status_code=404, detail="report not found")

    if current_user.role != "ADMIN" and rep.teacher_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    return ReportFullOut(
        report_id=rep.id,
        created_at=rep.created_at.isoformat(),
        total_sum=rep.total_sum,
        raw_text=rep.raw_text,
    )
