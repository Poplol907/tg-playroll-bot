from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Subscription, StudentTeacher
from backend.app.schemas.subscriptions import (
    SubscriptionCreateIn,
    SubscriptionUpdateIn,
    SubscriptionOut,
)
from backend.app.services.permissions import (
    require_admin_or_teacher,
    require_teacher_self_or_admin,
)

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("", response_model=list[SubscriptionOut])
async def list_subscriptions(
    student_id: int | None = None,
    month: str | None = None,
    teacher_id: int | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    q = select(Subscription).where(Subscription.org_id == current_user.org_id)

    if current_user.role == "TEACHER":
        if teacher_id is not None:
            require_teacher_self_or_admin(current_user, teacher_id)
        q = q.where(Subscription.teacher_user_id == current_user.id)
    elif teacher_id is not None:
        require_teacher_self_or_admin(current_user, teacher_id)
        q = q.where(Subscription.teacher_user_id == teacher_id)

    if student_id is not None:
        q = q.where(Subscription.student_id == student_id)

    if month is not None:
        q = q.where(Subscription.month_year == month)

    result = await session.execute(q.order_by(Subscription.month_year.desc()))
    subs = result.scalars().all()
    return [_to_out(s) for s in subs]


@router.post("", response_model=SubscriptionOut)
async def create_subscription(
    payload: SubscriptionCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    st_result = await session.execute(
        select(StudentTeacher).where(
            StudentTeacher.org_id == current_user.org_id,
            StudentTeacher.student_id == payload.student_id,
            StudentTeacher.teacher_user_id == payload.teacher_user_id,
        )
    )
    if st_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="student_teacher link not found")

    sub = Subscription(
        org_id=current_user.org_id,
        student_id=payload.student_id,
        teacher_user_id=payload.teacher_user_id,
        month_year=payload.month_year,
        lessons_count=payload.lessons_count,
        paid_at=payload.paid_at,
    )
    session.add(sub)
    await session.commit()
    await session.refresh(sub)
    return _to_out(sub)


@router.patch("/{subscription_id}", response_model=SubscriptionOut)
async def update_subscription(
    subscription_id: int,
    payload: SubscriptionUpdateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    result = await session.execute(
        select(Subscription).where(
            Subscription.id == subscription_id,
            Subscription.org_id == current_user.org_id,
        )
    )
    sub = result.scalar_one_or_none()
    if sub is None:
        raise HTTPException(status_code=404, detail="not found")

    if current_user.role == "TEACHER" and sub.teacher_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="forbidden")

    if payload.lessons_count is not None:
        sub.lessons_count = payload.lessons_count
    if payload.paid_at is not None:
        sub.paid_at = payload.paid_at
    if payload.status is not None:
        sub.status = payload.status

    await session.commit()
    await session.refresh(sub)
    return _to_out(sub)


def _to_out(s: Subscription) -> SubscriptionOut:
    return SubscriptionOut(
        id=s.id,
        student_id=s.student_id,
        teacher_user_id=s.teacher_user_id,
        month_year=s.month_year,
        lessons_count=s.lessons_count,
        paid_at=s.paid_at,
        status=s.status,
    )
