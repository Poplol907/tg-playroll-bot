import os
from contextlib import asynccontextmanager
from dotenv import load_dotenv

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.app.services.errors import DomainError
from backend.app.routers.users import router as users_router
from backend.app.routers.dev import get_dev_router
from backend.app.routers.admin import router as admin_router
from backend.app.routers.health import router as health_router
from backend.app.routers.students import router as students_router
from backend.app.routers.instruments import router as instruments_router
from backend.app.routers.subscriptions import router as subscriptions_router
from backend.app.routers.lessons import router as lessons_router
from backend.app.routers.auth import router as auth_router
from backend.app.routers.teachers import router as teachers_router
from backend.app.routers.reports_v2 import router as reports_v2_router
from backend.app.routers.rates import router as rates_router
from backend.app.routers.payouts import router as payouts_router
from backend.app.routers.rooms import router as rooms_router
from backend.app.routers.system import router as system_router
from backend.app.routers.org import router as org_router

load_dotenv()

DEV_MODE = os.getenv("DEV_MODE", "0") == "1"
DEV_KEY = os.getenv("DEV_KEY")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Таблицы создаются через migrations/001_full_schema.sql
    # create_all оставлен только для локальной разработки (DEV_MODE)
    if DEV_MODE:
        from backend.app.database import engine, Base
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    lifespan=lifespan,
    title="Kosmo Studio API",
    version="1.0.0",
    docs_url="/docs" if DEV_MODE else None,   # Swagger только в dev
    redoc_url="/redoc" if DEV_MODE else None,
)

# CORS. Нативные мобильные клиенты не отправляют Origin и не подчиняются CORS —
# ограничение origins их не затрагивает. Аутентификация идёт через Bearer-токен
# (заголовок Authorization), а не cookie, поэтому allow_credentials не нужен
# (а сочетание "*" + credentials к тому же небезопасно).
# Прод: список доменов задаётся через ALLOWED_ORIGINS (через запятую).
# По умолчанию пусто = браузерный кросс-оригин доступ запрещён; в DEV — "*".
_allowed_origins = [
    o.strip() for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()
]
if not _allowed_origins and DEV_MODE:
    _allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Domain → HTTP translation ──────────────────────────────────────────────
# Services raise `DomainError` subclasses (NotFound, Forbidden, Conflict, …)
# which are framework-agnostic. This handler is the ONLY place that turns
# them into HTTP responses, keeping services testable without FastAPI.
@app.exception_handler(DomainError)
async def _handle_domain_error(_: Request, exc: DomainError) -> JSONResponse:
    body: dict[str, object] = {"detail": exc.message, "code": exc.code}
    if exc.details is not None:
        body["details"] = exc.details
    return JSONResponse(status_code=exc.status_code, content=body)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(users_router)
app.include_router(students_router)
app.include_router(instruments_router)
app.include_router(subscriptions_router)
app.include_router(lessons_router)
app.include_router(teachers_router)
app.include_router(rates_router)
app.include_router(payouts_router)
app.include_router(rooms_router)
app.include_router(reports_v2_router)
app.include_router(system_router)
app.include_router(org_router)

if DEV_MODE:
    app.include_router(get_dev_router(DEV_MODE, DEV_KEY))
