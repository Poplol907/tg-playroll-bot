"""
JWT-protected admin endpoints for user management within an org.
All endpoints require ADMIN role.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user, hash_password
from backend.app.database import get_session
from backend.app.models import (
    User,
    StudentTeacher,
    Lesson,
    Subscription,
    TeacherRate,
    Report,
    ReportV2,
    DeviceToken,
)

# Role assigned to a soft-disabled account: keeps the row (and all history)
# but drops it out of the teacher list / studio stats (which filter role ==
# "TEACHER") and blocks login (permissions allow only ADMIN/TEACHER).
DISABLED_ROLE = "DISABLED"
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
        .where(
            User.org_id == current_user.org_id,
            User.role != DISABLED_ROLE,
        )
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

    # Logins are global because the login endpoint has no organization selector.
    existing = await session.execute(
        select(User).where(User.login == payload.login)
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="login already exists")

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


# ── Disable user (soft delete — keeps history) ────────────────────────────────

@router.post("/users/{user_id}/disable", status_code=204)
async def disable_org_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Soft-delete: the account is archived (login blocked, hidden from the
    teacher list and studio stats) but every lesson/rate/subscription row is
    preserved for historical reports."""
    _require_admin(current_user)

    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="cannot disable yourself")

    result = await session.execute(
        select(User).where(
            User.id == user_id,
            User.org_id == current_user.org_id,
        )
    )
    u = result.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=404, detail="user not found")

    u.role = DISABLED_ROLE
    u.password_hash = None  # block login
    await session.commit()


# ── Delete user (hard cascade — wipes the teacher and all their data) ─────────

@router.delete("/users/{user_id}", status_code=204)
async def delete_org_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Permanently removes the teacher AND every row that references them
    (lessons, subscriptions, student links, rates, reports, device tokens).
    Mirrors the cascading delete used for students so no orphan FK rows are
    left behind. Use /disable instead to keep the teacher's history."""
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

    # Lessons hang off the teacher's student links — collect those first.
    st_ids = (
        await session.execute(
            select(StudentTeacher.id).where(
                StudentTeacher.teacher_user_id == user_id
            )
        )
    ).scalars().all()

    if st_ids:
        await session.execute(
            sa_delete(Lesson).where(Lesson.student_teacher_id.in_(st_ids))
        )
    await session.execute(
        sa_delete(Subscription).where(Subscription.teacher_user_id == user_id)
    )
    await session.execute(
        sa_delete(StudentTeacher).where(
            StudentTeacher.teacher_user_id == user_id
        )
    )
    # Rates the teacher is the subject of, plus any they authored (created_by
    # is NOT NULL so the row can't simply be detached).
    await session.execute(
        sa_delete(TeacherRate).where(
            (TeacherRate.teacher_user_id == user_id)
            | (TeacherRate.created_by == user_id)
        )
    )
    await session.execute(
        sa_delete(Report).where(Report.teacher_user_id == user_id)
    )
    await session.execute(
        sa_delete(ReportV2).where(ReportV2.teacher_user_id == user_id)
    )
    await session.execute(
        sa_delete(DeviceToken).where(DeviceToken.user_id == user_id)
    )

    await session.delete(u)
    await session.commit()
