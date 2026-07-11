from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, TeacherRate, Instrument, Student
from backend.app.schemas.rates import (
    RateCreateIn,
    RateOut,
    CurrentRateOut,
    RateConfigIn,
    CurrentRatesOut,
)
from backend.app.services.rates import (
    get_rates_for_teacher,
    get_rate,
    set_current_rates,
    get_current_rates,
    DEFAULT_RATE,
)
from backend.app.services.permissions import require_admin, require_teacher_self_or_admin

router = APIRouter(prefix="/rates", tags=["rates"])


class RateSimpleOut(BaseModel):
    id: int
    rate_per_lesson: int
    is_foreign: bool = False
    instrument_name: Optional[str] = None
    note: Optional[str] = None
    effective_from: date


@router.get("/v2/my", response_model=list[RateSimpleOut])
async def my_rates(
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Ставки текущего педагога — для отображения в мобильном приложении."""
    rates = await get_rates_for_teacher(session, current_user.org_id, current_user.id)

    # Загружаем имена студентов и инструментов
    student_ids = {r.student_id for r in rates if r.student_id is not None}
    instrument_ids = {r.instrument_id for r in rates if r.instrument_id is not None}

    students: dict[int, str] = {}
    if student_ids:
        result = await session.execute(
            select(Student).where(Student.id.in_(student_ids))
        )
        students = {s.id: f'{s.first_name} {s.last_name}' for s in result.scalars().all()}

    instruments: dict[int, str] = {}
    if instrument_ids:
        result = await session.execute(
            select(Instrument).where(Instrument.id.in_(instrument_ids))
        )
        instruments = {i.id: i.name for i in result.scalars().all()}

    return [
        RateSimpleOut(
            id=r.id,
            rate_per_lesson=r.rate_per_lesson,
            is_foreign=r.is_foreign,
            instrument_name=instruments.get(r.instrument_id) if r.instrument_id else None,
            note=r.note,
            effective_from=r.effective_from,
        )
        for r in rates
    ]


@router.get("/teacher/{teacher_id}", response_model=CurrentRateOut)
async def get_teacher_rates(
    teacher_id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Все ставки педагога — история и актуальные."""
    require_teacher_self_or_admin(current_user, teacher_id)

    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")

    history = await get_rates_for_teacher(session, current_user.org_id, teacher_id)

    # загружаем инструменты для имён
    instruments: dict[int, str] = {}
    inst_ids = {r.instrument_id for r in history if r.instrument_id is not None}
    if inst_ids:
        result = await session.execute(
            select(Instrument).where(Instrument.id.in_(inst_ids))
        )
        instruments = {i.id: i.name for i in result.scalars().all()}

    today = date.today()
    default_rate = await get_rate(session, current_user.org_id, teacher_id, today)

    return CurrentRateOut(
        teacher_user_id=teacher_id,
        teacher_name=teacher.teacher_name,
        default_rate=default_rate,
        rates=[
            RateOut(
                id=r.id,
                teacher_user_id=r.teacher_user_id,
                instrument_id=r.instrument_id,
                instrument_name=instruments.get(r.instrument_id) if r.instrument_id else None,
                is_foreign=r.is_foreign,
                rate_per_lesson=r.rate_per_lesson,
                effective_from=r.effective_from,
                note=r.note,
            )
            for r in history
        ],
    )


@router.post("/teacher/{teacher_id}", response_model=RateOut)
async def set_rate(
    teacher_id: int,
    payload: RateCreateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Установить или изменить ставку. Старые записи не удаляются — история сохраняется."""
    require_admin(current_user)

    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")

    if payload.instrument_id is not None:
        instrument = await session.get(Instrument, payload.instrument_id)
        if instrument is None or instrument.org_id != current_user.org_id:
            raise HTTPException(status_code=404, detail="instrument not found")
    else:
        instrument = None

    rate = TeacherRate(
        org_id=current_user.org_id,
        teacher_user_id=teacher_id,
        instrument_id=payload.instrument_id,
        is_foreign=payload.is_foreign,
        rate_per_lesson=payload.rate_per_lesson,
        effective_from=payload.effective_from,
        note=payload.note,
        created_by=current_user.id,
    )
    session.add(rate)
    await session.commit()
    await session.refresh(rate)

    return RateOut(
        id=rate.id,
        teacher_user_id=rate.teacher_user_id,
        instrument_id=rate.instrument_id,
        instrument_name=instrument.name if instrument else None,
        is_foreign=rate.is_foreign,
        rate_per_lesson=rate.rate_per_lesson,
        effective_from=rate.effective_from,
        note=rate.note,
    )


@router.get("/teacher/{teacher_id}/current", response_model=CurrentRatesOut)
async def get_current_rate(
    teacher_id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Текущая ставка педагога (обычная + иностранная) для конфигуратора."""
    require_teacher_self_or_admin(current_user, teacher_id)
    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")
    base, foreign = await get_current_rates(session, current_user.org_id, teacher_id)
    return CurrentRatesOut(rate_per_lesson=base, foreign_rate_per_lesson=foreign)


@router.put("/teacher/{teacher_id}/current", response_model=CurrentRatesOut)
async def set_current_rate(
    teacher_id: int,
    payload: RateConfigIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Задаёт текущую ставку без даты вступления — схлопывает историю тарифа."""
    require_admin(current_user)
    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")
    if payload.rate_per_lesson <= 0:
        raise HTTPException(status_code=400, detail="rate_per_lesson must be > 0")
    await set_current_rates(
        session,
        current_user.org_id,
        teacher_id,
        current_user.id,
        base_rate=payload.rate_per_lesson,
        foreign_rate=payload.foreign_rate_per_lesson,
    )
    base, foreign = await get_current_rates(session, current_user.org_id, teacher_id)
    return CurrentRatesOut(rate_per_lesson=base, foreign_rate_per_lesson=foreign)


@router.delete("/{rate_id}", status_code=204)
async def delete_rate(
    rate_id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Удалить конкретную запись ставки."""
    require_admin(current_user)

    rate = await session.get(TeacherRate, rate_id)
    if rate is None or rate.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="not found")

    await session.delete(rate)
    await session.commit()
