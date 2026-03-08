from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from backend.app.database import AsyncSessionLocal
from backend.app.models import User, Report
from backend.app.schemas.reports import (
    CalcLineOut,
    CalcOut,
    CalcSavedOut,
    CalcTextIn,
    ReportFullOut,
    ReportShortOut,
)

router = APIRouter(tags=["reports"])


@router.post("/calc/text", response_model=CalcOut)
async def calc_text(payload: CalcTextIn):
    lines_out: list[CalcLineOut] = []
    total_sum = 0

    for raw in payload.text.splitlines():
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

        lines_out.append(
            CalcLineOut(
                first=first,
                last=last,
                lessons=lessons,
                price=price,
                total=total,
            )
        )

    return CalcOut(count=len(lines_out), sum=total_sum, lines=lines_out)


@router.post("/calc/save-text", response_model=CalcSavedOut)
async def calc_save_text(payload: CalcTextIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        user = q.scalar_one_or_none()

        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")
        if user.role not in ["TEACHER", "ADMIN"]:
            raise HTTPException(status_code=403, detail="only for teachers and admins")

        lines_out: list[CalcLineOut] = []
        total_sum = 0

        for raw in payload.text.splitlines():
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

            lines_out.append(
                CalcLineOut(
                    first=first,
                    last=last,
                    lessons=lessons,
                    price=price,
                    total=total,
                )
            )

        report = Report(
            teacher_user_id=user.id,
            total_sum=total_sum,
            raw_text=payload.text,
        )
        session.add(report)
        await session.commit()
        await session.refresh(report)

        return CalcSavedOut(
            report_id=report.id,
            count=len(lines_out),
            sum=total_sum,
            lines=lines_out,
        )


@router.get("/reports/last", response_model=ReportShortOut)
async def reports_last(telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        user = q.scalar_one_or_none()

        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")
        if user.role not in ["TEACHER", "ADMIN"]:
            raise HTTPException(status_code=403, detail="only for teachers and admins")

        rq = await session.execute(
            select(Report)
            .where(Report.teacher_user_id == user.id)
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
async def report_by_id(report_id: int, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        user = q.scalar_one_or_none()

        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        rq = await session.execute(select(Report).where(Report.id == report_id))
        rep = rq.scalar_one_or_none()

        if rep is None:
            raise HTTPException(status_code=404, detail="report not found")

        if user.role != "ADMIN" and rep.teacher_user_id != user.id:
            raise HTTPException(status_code=403, detail="forbidden")

        return ReportFullOut(
            report_id=rep.id,
            created_at=rep.created_at.isoformat(),
            total_sum=rep.total_sum,
            raw_text=rep.raw_text,
        )