from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import (
    create_access_token,
    hash_password,
    verify_password,
    get_current_user,
)
from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.auth import LoginIn, SetPasswordIn, TokenOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenOut)
async def login(payload: LoginIn, session: AsyncSession = Depends(get_session)):
    result = await session.execute(select(User).where(User.login == payload.login))
    user = result.scalar_one_or_none()

    if user is None or user.password_hash is None:
        raise HTTPException(status_code=401, detail="invalid credentials")

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="invalid credentials")

    if user.role == "PENDING":
        raise HTTPException(status_code=403, detail="account not activated")

    token = create_access_token(user.id)
    return TokenOut(
        access_token=token,
        user_id=user.id,
        role=user.role,
        teacher_name=user.teacher_name,
    )


@router.post("/set-password", status_code=204)
async def set_password(
    payload: SetPasswordIn,
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Только ADMIN может устанавливать пароль любому пользователю.
    Или пользователь может сменить пароль себе."""
    result = await session.execute(select(User).where(User.login == payload.login))
    target = result.scalar_one_or_none()

    if target is None:
        raise HTTPException(status_code=404, detail="user not found")

    if current_user.role != "ADMIN" and current_user.id != target.id:
        raise HTTPException(status_code=403, detail="forbidden")

    target.password_hash = hash_password(payload.password)
    await session.commit()


@router.post("/init-password", status_code=204)
async def init_password(
    payload: SetPasswordIn,
    session: AsyncSession = Depends(get_session),
):
    """Установить пароль впервые — только если он ещё не задан.
    Используется при первом входе пользователя в приложение."""
    result = await session.execute(select(User).where(User.login == payload.login))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="user not found")

    if user.password_hash is not None:
        raise HTTPException(status_code=409, detail="password already set, use /auth/set-password")

    if user.role == "PENDING":
        raise HTTPException(status_code=403, detail="account not activated")

    user.password_hash = hash_password(payload.password)
    await session.commit()


@router.get("/me")
async def me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "login": current_user.login,
        "role": current_user.role,
        "teacher_name": current_user.teacher_name,
        "org_id": current_user.org_id,
    }
