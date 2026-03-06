from fastapi import APIRouter
from sqlalchemy import text

from backend.app.database import engine

router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/db-ping")
async def db_ping():
    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT 1"))
        return {"db": "ok", "value": result.scalar_one()}
