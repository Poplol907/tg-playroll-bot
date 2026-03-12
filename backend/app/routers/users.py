from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from backend.app.database import AsyncSessionLocal
from backend.app.models import User
from backend.app.schemas.user import UserSetLoginIn

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/set-login")
async def user_set_login(payload: UserSetLoginIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(
            select(User).where(User.telegram_user_id == telegram_user_id)
        )
        user = q.scalar_one_or_none()

        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        exists_q = await session.execute(
            select(User).where(User.login == payload.new_login)
        )
        existing = exists_q.scalar_one_or_none()

        if existing is not None and existing.id != user.id:
            raise HTTPException(status_code=409, detail="new login already exists")

        user.login = payload.new_login
        await session.commit()

        return {
            "ok": True,
            "login": user.login,
            "role": user.role,
        }