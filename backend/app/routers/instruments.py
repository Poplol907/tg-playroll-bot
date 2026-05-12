from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Instrument
from backend.app.schemas.instruments import InstrumentCreateIn, InstrumentOut
from backend.app.services.permissions import require_admin

router = APIRouter(prefix="/instruments", tags=["instruments"])


@router.get("", response_model=list[InstrumentOut])
async def list_instruments(
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    result = await session.execute(
        select(Instrument)
        .where(Instrument.org_id == current_user.org_id, Instrument.is_active == True)
        .order_by(Instrument.name)
    )
    instruments = result.scalars().all()
    return [InstrumentOut(id=i.id, name=i.name, is_active=i.is_active) for i in instruments]


@router.post("", response_model=InstrumentOut)
async def create_instrument(
    payload: InstrumentCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    existing = await session.execute(
        select(Instrument.id).where(
            Instrument.org_id == current_user.org_id,
            Instrument.name == payload.name,
        )
    )
    if existing.first():
        raise HTTPException(status_code=409, detail="instrument already exists")

    instrument = Instrument(org_id=current_user.org_id, name=payload.name)
    session.add(instrument)
    await session.commit()
    await session.refresh(instrument)
    return InstrumentOut(id=instrument.id, name=instrument.name, is_active=instrument.is_active)


@router.delete("/{instrument_id}", status_code=204)
async def deactivate_instrument(
    instrument_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    result = await session.execute(
        select(Instrument).where(
            Instrument.id == instrument_id,
            Instrument.org_id == current_user.org_id,
        )
    )
    instrument = result.scalar_one_or_none()
    if instrument is None:
        raise HTTPException(status_code=404, detail="not found")

    instrument.is_active = False
    await session.commit()
