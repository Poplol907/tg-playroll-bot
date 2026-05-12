"""
JWT-protected admin endpoints for user management within an org.
All endpoints require ADMIN role.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user, hash_password
from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.org import (
    OrgUserOut,
    OrgUserCreateIn,
    OrgUserUpdateIn,
    OrgSetPasswordIn,
)
from backend.app.services.permissions import require_admin as _require_admin

router = APIRouter(prefix="/org", tags=["org"])


def _to_out(u: User) -> OrgUserOut:
    return OrgUserOut(
        id=u.id,
        login=u.login,
        role=u.role,
        teacher_name=u.teacher_name,
        has_password=u.password_hash is not None,
    )


# ── List all users in org ─────────────────────────────────────────────────────

@router.get("/users", response_model=list[OrgUserOut])
async def list_org_users(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    _require_admin(current_user)
    result = await session.execute(
        select(User)
        .where(User.org_id == current_user.org_id)
        .order_by(User.role, User.login)
    )
    return [_to_out(u) for u in result.scalars().all()]


# ── Create a user ─────────────────────────────────────────────────────────────

@router.post("/users", response_model=OrgUserOut, status_code=201)
async def create_org_user(
    payload: OrgUserCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    _require_admin(current_user)

    if payload.role not in ("ADMIN", "TEACHER"):
        raise HTTPException(status_code=422, detail="role must be ADMIN or TEACHER")

    # Check for duplicate login in this org
    existing = await session.execute(
        select(User).where(
            User.org_id == current_user.org_id,
            User.login == payload.login,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="login already exists in this org")

    u = User(
        org_id=current_user.org_id,
        login=payload.login,
        role=payload.role,
        teacher_name=payload.teacher_name,
        password_hash=hash_password(payload.password) if payload.password else None,
    )
    session.add(u)
    await session.commit()
    await session.refresh(u)
    return _to_out(u)


# ── Update user (name / role) ─────────────────────────────────────────────────

@router.patch("/users/{user_id}", response_model=OrgUserOut)
async def update_org_user(
    user_id: int,
    payload: OrgUserUpdateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    _require_admin(current_user)

    result = await session.execute(
        select(User).where(
            User.id == user_id,
            User.org_id == current_user.org_id,
        )
    )
    u = result.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=404, detail="user not found")

    if payload.teacher_name is not None:
        u.teacher_name = payload.teacher_name
    if payload.role is not None:
        if payload.role not in ("ADMIN", "TEACHER"):
            raise HTTPException(status_code=422, detail="invalid role")
        u.role = payload.role

    await session.commit()
    await session.refresh(u)
    return _to_out(u)


# ── Set password for any user in org ─────────────────────────────────────────

@router.post("/users/{user_id}/password", status_code=204)
async def set_org_user_password(
    user_id: int,
    payload: OrgSetPasswordIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    _require_admin(current_user)

    result = await session.execute(
        select(User).where(
            User.id == user_id,
            User.org_id == current_user.org_id,
        )
    )
    u = result.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=404, detail="user not found")

    u.password_hash = hash_password(payload.password)
    await session.commit()


# ── Delete user ───────────────────────────────────────────────────────────────

@router.delete("/users/{user_id}", status_code=204)
async def delete_org_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    _require_admin(current_user)

    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="cannot delete yourself")

    result = await session.execute(
        select(User).where(
            User.id == user_id,
            User.org_id == current_user.org_id,
        )
    )
    u = result.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=404, detail="user not found")

    await session.delete(u)
    await session.commit()
