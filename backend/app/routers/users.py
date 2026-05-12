from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.user import UserSetLoginIn

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/set-login")
async def user_set_login(
    payload: UserSetLoginIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    exists_q = await session.execute(
        select(User).where(User.login == payload.new_login)
    )
    existing = exists_q.scalar_one_or_none()

    if existing is not None and existing.id != current_user.id:
        raise HTTPException(status_code=409, detail="new login already exists")

    current_user.login = payload.new_login
    await session.commit()

    return {"ok": True, "login": current_user.login, "role": current_user.role}
