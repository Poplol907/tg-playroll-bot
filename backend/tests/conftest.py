"""Shared test fixtures.

Service functions take an AsyncSession, so we run them against an in-memory
SQLite database (the models use portable column types). No Postgres needed.
"""
import os

# Importing backend.app.database builds an engine from DATABASE_URL at import
# time with Postgres pool args, so the URL must be Postgres-shaped even though
# this module engine is never connected in tests (each test uses its own
# in-memory SQLite engine below).
os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test"
)

from datetime import date, time
from types import SimpleNamespace

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from backend.app.database import Base
from backend.app import models  # noqa: F401 — registers all tables on Base.metadata
from backend.app.models import Lesson, Org, Student, StudentTeacher, User


@pytest_asyncio.fixture
async def session():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    async with maker() as s:
        yield s
    await engine.dispose()


@pytest_asyncio.fixture
async def ctx(session):
    """Seed a minimal org: one admin, one teacher, one student linked to them."""
    org = Org(name="Studio", slug="studio")
    session.add(org)
    await session.flush()

    admin = User(org_id=org.id, login="admin", role="ADMIN", teacher_name="Admin")
    teacher = User(org_id=org.id, login="teach", role="TEACHER", teacher_name="Teacher")
    session.add_all([admin, teacher])
    await session.flush()

    student = Student(org_id=org.id, first_name="Ann", last_name="Lee")
    session.add(student)
    await session.flush()

    st = StudentTeacher(
        org_id=org.id, student_id=student.id, teacher_user_id=teacher.id
    )
    session.add(st)
    await session.commit()

    return SimpleNamespace(
        session=session, org=org, admin=admin, teacher=teacher, student=student, st=st
    )


@pytest.fixture
def mk(ctx):
    """Factory: create a lesson for the seeded student in July 2026."""
    async def _mk(
        day,
        *,
        status="scheduled",
        cancelled_by=None,
        lesson_type="regular",
        makeup_for_id=None,
        makeup_status="none",
    ):
        lesson = Lesson(
            org_id=ctx.org.id,
            student_teacher_id=ctx.st.id,
            scheduled_date=date(2026, 7, day),
            scheduled_time=time(10, 0),
            status=status,
            cancelled_by=cancelled_by,
            lesson_type=lesson_type,
            makeup_for_id=makeup_for_id,
            makeup_status=makeup_status,
        )
        ctx.session.add(lesson)
        await ctx.session.commit()
        await ctx.session.refresh(lesson)
        return lesson

    return _mk
