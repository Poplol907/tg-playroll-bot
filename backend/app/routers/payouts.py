from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import Payout, User
from backend.app.schemas.payouts import PayoutCreateIn, PayoutOut, PayoutUpdateIn
from backend.app.services.permissions import require_admin

router = APIRouter(prefix="/payouts", tags=["payouts"])


def _to_out(p: Payout) -> PayoutOut:
    return PayoutOut(
        id=p.id,
        teacher_user_id=p.teacher_user_id,
        month_year=p.month_year,
        amount=p.amount,
        paid_at=p.paid_at,
        note=p.note,
    )


@router.get("", response_model=list[PayoutOut])
async def list_payouts(
    month_year: str = Query(..., description="YYYY-MM"),
    teacher_id: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    q = select(Payout).where(
        Payout.org_id == current_user.org_id,
        Payout.month_year == month_year,
    )
    if teacher_id is not None:
        q = q.where(Payout.teacher_user_id == teacher_id)
    q = q.order_by(Payout.paid_at.desc(), Payout.id.desc())
    rows = (await session.execute(q)).scalars().all()
    return [_to_out(p) for p in rows]


@router.post("", response_model=PayoutOut, status_code=201)
async def create_payout(
    payload: PayoutCreateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    teacher = await session.get(User, payload.teacher_user_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")
    payout = Payout(
        org_id=current_user.org_id,
        teacher_user_id=payload.teacher_user_id,
        month_year=payload.month_year,
        amount=payload.amount,
        paid_at=payload.paid_at,
        note=payload.note,
        created_by=current_user.id,
    )
    session.add(payout)
    await session.commit()
    await session.refresh(payout)
    return _to_out(payout)


@router.patch("/{payout_id}", response_model=PayoutOut)
async def update_payout(
    payout_id: int,
    payload: PayoutUpdateIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    payout = await session.get(Payout, payout_id)
    if payout is None or payout.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="payout not found")
    if payload.amount is not None:
        if payload.amount <= 0:
            raise HTTPException(status_code=400, detail="amount must be > 0")
        payout.amount = payload.amount
    if payload.paid_at is not None:
        payout.paid_at = payload.paid_at
    if payload.note is not None:
        payout.note = payload.note
    await session.commit()
    await session.refresh(payout)
    return _to_out(payout)


@router.delete("/{payout_id}", status_code=204)
async def delete_payout(
    payout_id: int,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    payout = await session.get(Payout, payout_id)
    if payout is None or payout.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="payout not found")
    await session.delete(payout)
    await session.commit()
