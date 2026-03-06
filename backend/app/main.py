import os
from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException, APIRouter, Depends, Header
from sqlalchemy.exc import IntegrityError
from sqlalchemy import text, select
from pydantic import BaseModel

from app.database import AsyncSessionLocal
from app.models import User, Report
from app.database import engine, Base
import app.models

load_dotenv()

DEV_MODE = os.getenv("DEV_MODE", "0") == "1"
DEV_KEY = os.getenv("DEV_KEY")

app = FastAPI()

async def require_dev_key(x_dev_key: str | None = Header(default=None)):
    if not DEV_MODE:
        raise HTTPException(status_code=403, detail="dev disabled")
    if DEV_KEY is None:
        raise HTTPException(status_code=403, detail="dev key not set")
    if x_dev_key != DEV_KEY:
        raise HTTPException(status_code=403, detail="invalid dev key")


dev_router = APIRouter(
    prefix="/dev",
    tags=["dev"],
    dependencies=[Depends(require_dev_key)],
)

class CalcTextIn(BaseModel):
    text: str

class CalcLineOut(BaseModel):
    first: str
    last: str
    lessons: int
    price: int
    total: int

class CalcOut(BaseModel):
    count: int
    sum: int
    lines: list[CalcLineOut]

class CalcSavedOut(CalcOut):
    report_id: int

class ReportShortOut(BaseModel):
    report_id: int
    created_at: str
    total_sum: int

class ReportFullOut(BaseModel):
    report_id: int
    created_at: str
    total_sum: int
    raw_text: str

class AdminBindIn(BaseModel):
    login: str
    telegram_user_id: int

class AdminUserOut(BaseModel):
    id: int
    login: str
    role: str
    telegram_user_id: int | None
    teacher_name: str | None


@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/db-ping")
async def db_ping():
    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT 1"))
        return {"db": "ok", "value": result.scalar_one()}

class CreateUserIn(BaseModel):
    login: str
    role: str  # "ADMIN" or "TEACHER"
    teacher_name: str | None = None

@dev_router.post("/create-user")
async def dev_create_user(payload: CreateUserIn):
    async with AsyncSessionLocal() as session:
        q = await session.execute(select(User).where(User.login == payload.login))
        if q.scalar_one_or_none() is not None:
            return {"ok": False, "error": "login exists"}

        u = User(login=payload.login, role=payload.role, teacher_name=payload.teacher_name)
        session.add(u)
        await session.commit()
        return {"ok": True, "id": u.id}


class BindIn(BaseModel):
    login: str
    telegram_user_id: int


@dev_router.post("/bind")
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
            raise HTTPException(status_code=409, detail="telegram_user_id already bound to someone else")

        return {"ok": True}


if DEV_MODE:
    app.include_router(dev_router)

@app.post("/calc/text", response_model=CalcOut)
async def calc_text(payload: CalcTextIn):
    lines_out: list[CalcLineOut] = []
    total_sum = 0

    for idx, raw in enumerate(payload.text.splitlines(), start=1):
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split()
        if len(parts) != 4:
            # пропускаем или можно валить ошибкой
            continue

        first, last, lessons_s, price_s = parts
        try:
            lessons = int(lessons_s)
            price = int(price_s)
        except ValueError:
            continue

        total = lessons * price
        total_sum += total
        lines_out.append(CalcLineOut(first=first, last=last, lessons=lessons, price=price, total=total))

    return CalcOut(count=len(lines_out), sum=total_sum, lines=lines_out)


@app.post("/calc/save-text", response_model=CalcSavedOut)
async def calc_save_text(payload: CalcTextIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(select(User).where(User.telegram_user_id == telegram_user_id))
        user = q.scalar_one_or_none()

        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")
        if user.role != "TEACHER":
            raise HTTPException(status_code=403, detail="only for teachers")

        # считаем (как в calc_text)
        lines_out: list[CalcLineOut] = []
        total_sum = 0

        for raw in payload.text.splitlines():
            raw = raw.strip()
            if not raw:
                continue
            parts = raw.split()
            if len(parts) != 4:
                continue

            first, last, lessons_s, price_s = parts
            try:
                lessons = int(lessons_s)
                price = int(price_s)
            except ValueError:
                continue

            total = lessons * price
            total_sum += total
            lines_out.append(
                CalcLineOut(first=first, last=last, lessons=lessons, price=price, total=total)
            )

        report = Report(
            teacher_user_id=user.id,
            total_sum=total_sum,
            raw_text=payload.text,
        )
        session.add(report)
        await session.commit()
        await session.refresh(report)

        return CalcSavedOut(report_id=report.id, count=len(lines_out), sum=total_sum, lines=lines_out)

@app.get("/reports/last", response_model=ReportShortOut)
async def reports_last(telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        q = await session.execute(select(User).where(User.telegram_user_id == telegram_user_id))
        user = q.scalar_one_or_none()
        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")
        if user.role != "TEACHER":
            raise HTTPException(status_code=403, detail="only for teachers")

        rq = await session.execute(
            select(Report)
            .where(Report.teacher_user_id == user.id)
            .order_by(Report.id.desc())
            .limit(1)
        )
        rep = rq.scalar_one_or_none()
        if rep is None:
            raise HTTPException(status_code=404, detail="no reports yet")

        return ReportShortOut(
            report_id=rep.id,
            created_at=rep.created_at.isoformat(),
            total_sum=rep.total_sum,
        )

@app.get("/reports/{report_id}", response_model=ReportFullOut)
async def report_by_id(report_id: int, telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        # ищем пользователя
        q = await session.execute(select(User).where(User.telegram_user_id == telegram_user_id))
        user = q.scalar_one_or_none()
        if user is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        # ищем отчёт
        rq = await session.execute(select(Report).where(Report.id == report_id))
        rep = rq.scalar_one_or_none()
        if rep is None:
            raise HTTPException(status_code=404, detail="report not found")

        # проверяем доступ
        if user.role != "ADMIN" and rep.teacher_user_id != user.id:
            raise HTTPException(status_code=403, detail="forbidden")

        return ReportFullOut(
            report_id=rep.id,
            created_at=rep.created_at.isoformat(),
            total_sum=rep.total_sum,
            raw_text=rep.raw_text,
        )

@app.post("/admin/bind")
async def admin_bind(payload: AdminBindIn, telegram_user_id: int):
    async with AsyncSessionLocal() as session:

        # проверяем что вызывающий — админ
        q = await session.execute(select(User).where(User.telegram_user_id == telegram_user_id))
        admin = q.scalar_one_or_none()

        if admin is None:
            raise HTTPException(status_code=401, detail="unknown telegram user")

        if admin.role != "ADMIN":
            raise HTTPException(status_code=403, detail="admin only")

        # ищем пользователя по логину
        uq = await session.execute(select(User).where(User.login == payload.login))
        u = uq.scalar_one_or_none()

        if u is None:
            raise HTTPException(status_code=404, detail="user not found")

        # привязываем telegram id
        u.telegram_user_id = payload.telegram_user_id
        await session.commit()

        return {"ok": True, "login": u.login, "telegram_user_id": u.telegram_user_id}

@app.get("/admin/users", response_model=list[AdminUserOut])
async def admin_users(telegram_user_id: int):
    async with AsyncSessionLocal() as session:
        # кто вызывает
        q = await session.execute(select(User).where(User.telegram_user_id == telegram_user_id))
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

