from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.database import get_session
from backend.app.models import User
from backend.app.schemas.dev import CreateUserIn


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

    DEFAULT_ORG_ID = 1

    @router.post("/create-user")
    async def dev_create_user(
        payload: CreateUserIn,
        session: AsyncSession = Depends(get_session),
    ):
        q = await session.execute(
            select(User).where(
                User.org_id == DEFAULT_ORG_ID,
                User.login == payload.login,
            )
        )
        if q.scalar_one_or_none() is not None:
            return {"ok": False, "error": "login exists"}

        u = User(
            org_id=DEFAULT_ORG_ID,
            login=payload.login,
            role=payload.role,
            teacher_name=payload.teacher_name,
        )
        session.add(u)
        await session.commit()
        return {"ok": True, "id": u.id}

    return router
