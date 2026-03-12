from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from backend.app.database import AsyncSessionLocal
from backend.app.models import User
from backend.app.schemas.admin import AdminSetLoginIn
from backend.app.schemas.admin import (
    AdminBindIn,
    AdminUserOut,
    AdminCreateUserIn,
    AdminSetRoleIn,
)

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/bind")
async def admin_bind(payload: AdminBindIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        uq = await session.execute(select(User).where(User.login == payload.login))
        u = uq.scalar_one_or_none()

        if u is None:
            raise HTTPException(status_code=404, detail="user not found")

        u.telegram_user_id = payload.telegram_user_id
        await session.commit()

        return {"ok": True, "login": u.login, "telegram_user_id": u.telegram_user_id}


@router.get("/users", response_model=list[AdminUserOut])
async def admin_users(telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        uq = await session.execute(select(User).order_by(User.id))
        users = uq.scalars().all()

        return [
            AdminUserOut(
                id=u.id,
                login=u.login,
                role=u.role,
                telegram_user_id=u.telegram_user_id,
                teacher_name=u.teacher_name,
            )
            for u in users
        ]

@router.post("/create-user")
async def admin_create_user(payload: AdminCreateUserIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        uq = await session.execute(select(User).where(User.login == payload.login))
        existing = uq.scalar_one_or_none()

        if existing is not None:
            raise HTTPException(status_code=409, detail="login already exists")

        u = User(
            login=payload.login,
            role=payload.role,
            teacher_name=payload.teacher_name,
        )
        session.add(u)
        await session.commit()
        await session.refresh(u)

        return {
            "ok": True,
            "id": u.id,
            "login": u.login,
            "role": u.role,
        }


@router.post("/set-role")
async def admin_set_role(payload: AdminSetRoleIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        uq = await session.execute(select(User).where(User.login == payload.login))
        u = uq.scalar_one_or_none()

        if u is None:
            raise HTTPException(status_code=404, detail="user not found")

        u.role = payload.role
        await session.commit()

        return {
            "ok": True,
            "login": u.login,
            "role": u.role,
        }


@router.post("/set-login")
async def admin_set_login(payload: AdminSetLoginIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:

        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        uq = await session.execute(
            select(User).where(User.login == payload.login)
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

        return {
            "login": user.login,
            "role": user.role
        }