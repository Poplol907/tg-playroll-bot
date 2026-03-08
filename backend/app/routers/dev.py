from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select

from backend.app.database import AsyncSessionLocal
from backend.app.models import User
from backend.app.schemas.dev import CreateUserIn, BindIn


def get_dev_router(dev_mode: bool, dev_key: str | None) -> APIRouter:
    async def require_dev_key(x_dev_key: str | None = Header(default=None)):
        if not dev_mode:
            raise HTTPException(status_code=403, detail="dev disabled")
        if dev_key is None:
            raise HTTPException(status_code=403, detail="dev key not set")
        if x_dev_key != dev_key:
            raise HTTPException(status_code=403, detail="invalid dev key")

    router = APIRouter(
        prefix="/dev",
        tags=["dev"],
        dependencies=[Depends(require_dev_key)],
    )

    @router.post("/create-user")
    async def dev_create_user(payload: CreateUserIn):
        async with AsyncSessionLocal() as session:
            q = await session.execute(select(User).where(User.login == payload.login))
            if q.scalar_one_or_none() is not None:
                return {"ok": False, "error": "login exists"}

            u = User(
                login=payload.login,
                role=payload.role,
                teacher_name=payload.teacher_name,
            )
            session.add(u)
            await session.commit()
            return {"ok": True, "id": u.id}

    @router.post("/bind")
    async def dev_bind(payload: BindIn):
        async with AsyncSessionLocal() as session:
            q = await session.execute(select(User).where(User.login == payload.login))
            u = q.scalar_one_or_none()

            if u is None:
                raise HTTPException(status_code=404, detail="user not found")

            u.telegram_user_id = payload.telegram_user_id
            try:
                await session.commit()
            except IntegrityError:
                await session.rollback()
                raise HTTPException(
                    status_code=409,
                    detail="telegram_user_id already bound to someone else",
                )

            return {"ok": True}

    return router
