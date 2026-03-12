
import os
from dotenv import load_dotenv

from contextlib import asynccontextmanager

from fastapi import FastAPI
from backend.app.routers.reports import router as reports_router
from backend.app.routers.users import router as users_router
from backend.app.routers.dev import get_dev_router
from backend.app.routers.admin import router as admin_router
from backend.app.routers.health import router as health_router
from backend.app.database import engine, Base


load_dotenv()

DEV_MODE = os.getenv("DEV_MODE", "0") == "1"
DEV_KEY = os.getenv("DEV_KEY")

@asynccontextmanager
async def lifespan(_: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield
app = FastAPI(lifespan=lifespan)


app.include_router(health_router)
app.include_router(admin_router)
app.include_router(reports_router)

app.include_router(users_router)


if DEV_MODE:
    app.include_router(get_dev_router(DEV_MODE, DEV_KEY))

