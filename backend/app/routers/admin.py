from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.admin import AdminSetLoginIn
from backend.app.schemas.admin import (
    AdminUserOut,
    AdminCreateUserIn,
    AdminSetRoleIn,
)
from backend.app.services.permissions import require_admin

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/users", response_model=list[AdminUserOut])
async def admin_users(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    uq = await session.execute(
        select(User).where(User.org_id == current_user.org_id).order_by(User.id)
    )
    users = uq.scalars().all()

    return [
        AdminUserOut(
            id=u.id,
            login=u.login,
            role=u.role,
            teacher_name=u.teacher_name,
        )
        for u in users
    ]


@router.post("/create-user")
async def admin_create_user(
    payload: AdminCreateUserIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    uq = await session.execute(
        select(User).where(User.login == payload.login)
    )
    if uq.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="login already exists")

    u = User(
        org_id=current_user.org_id,
        login=payload.login,
        role=payload.role,
        teacher_name=payload.teacher_name,
    )
    session.add(u)
    await session.commit()
    await session.refresh(u)

    return {"ok": True, "id": u.id, "login": u.login, "role": u.role}


@router.post("/set-role")
async def admin_set_role(
    payload: AdminSetRoleIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    uq = await session.execute(
        select(User).where(
            User.login == payload.login,
            User.org_id == current_user.org_id,
        )
    )
    u = uq.scalar_one_or_none()

    if u is None:
        raise HTTPException(status_code=404, detail="user not found")

    u.role = payload.role
    await session.commit()

    return {"ok": True, "login": u.login, "role": u.role}


@router.post("/set-login")
async def admin_set_login(
    payload: AdminSetLoginIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin(current_user)

    uq = await session.execute(
        select(User).where(
            User.login == payload.login,
            User.org_id == current_user.org_id,
        )
    )
    user = uq.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="user not found")

    exists_q = await session.execute(
        select(User).where(User.login == payload.new_login)
    )
    exists = exists_q.scalar_one_or_none()

    if exists is not None and exists.id != user.id:
        raise HTTPException(status_code=409, detail="login already exists")

    user.login = payload.new_login
    await session.commit()

    return {"login": user.login, "role": user.role}
