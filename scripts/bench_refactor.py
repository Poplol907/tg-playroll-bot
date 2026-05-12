"""Бенчмарк: считаем SQL-запросы и время до/после рефакторинга.

ДО симулируем оригинальной реализацией get_rate() в цикле.
ПОСЛЕ — текущим кодом с RateResolver.
"""
import asyncio
import time
from datetime import date

from sqlalchemy import event, select
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.database import AsyncSessionLocal, engine
from backend.app.models import Lesson, StudentTeacher, Student, User, Subscription
from backend.app.services.rates import get_rate, build_rate_resolver, build_rate_resolvers_bulk


# ── SQL-счётчик через SQLAlchemy event ────────────────────────────────────────
_query_count = 0

def _count_query(conn, cursor, statement, parameters, context, executemany):
    global _query_count
    # Считаем только реальные SELECT/INSERT/UPDATE — не системные
    s = statement.strip().upper()
    if s.startswith(("SELECT", "INSERT", "UPDATE", "DELETE")) and "PG_CATALOG" not in s and "INFORMATION_SCHEMA" not in s:
        _query_count += 1


def reset_counter():
    global _query_count
    _query_count = 0


def get_count() -> int:
    return _query_count


# Подключаем счётчик к sync engine который под асинхронным
event.listen(engine.sync_engine, "before_cursor_execute", _count_query)


# ── Benchmark: BEFORE (старый код-паттерн) ────────────────────────────────────

async def salary_v2_before(session: AsyncSession, org_id: int, teacher_id: int, month_year: str):
    """Симуляция старой реализации salary_report_v2: get_rate в цикле."""
    year, mon = map(int, month_year.split("-"))
    date_from = date(year, mon, 1)
    date_to = date(year, mon, 30)

    # Карта is_foreign
    students_result = await session.execute(
        select(Student.id, Student.is_foreign).where(Student.org_id == org_id)
    )
    foreign_map = {row[0]: row[1] for row in students_result.all()}

    # Подписки
    subs_result = await session.execute(
        select(Subscription).where(
            Subscription.org_id == org_id,
            Subscription.teacher_user_id == teacher_id,
            Subscription.month_year == month_year,
        )
    )
    subs = subs_result.scalars().all()

    goal = 0
    for sub in subs:
        rate = await get_rate(
            session, org_id, teacher_id, date_from,
            student_id=sub.student_id,
            is_foreign=foreign_map.get(sub.student_id, False),
        )
        goal += sub.lessons_count * rate

    # Уроки
    lessons_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_id,
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    rows = lessons_result.all()

    earned = 0
    for lesson, st in rows:
        rate = await get_rate(
            session, org_id, teacher_id, lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        if lesson.status == "attended":
            earned += rate

    return goal, earned


# ── Benchmark: AFTER (новый код с RateResolver) ───────────────────────────────

async def salary_v2_after(session: AsyncSession, org_id: int, teacher_id: int, month_year: str):
    year, mon = map(int, month_year.split("-"))
    date_from = date(year, mon, 1)
    date_to = date(year, mon, 30)

    students_result = await session.execute(
        select(Student.id, Student.is_foreign).where(Student.org_id == org_id)
    )
    foreign_map = {row[0]: row[1] for row in students_result.all()}

    rate_resolver = await build_rate_resolver(session, org_id, teacher_id)

    subs_result = await session.execute(
        select(Subscription).where(
            Subscription.org_id == org_id,
            Subscription.teacher_user_id == teacher_id,
            Subscription.month_year == month_year,
        )
    )
    subs = subs_result.scalars().all()

    goal = 0
    for sub in subs:
        rate = rate_resolver.resolve(date_from, student_id=sub.student_id,
                                     is_foreign=foreign_map.get(sub.student_id, False))
        goal += sub.lessons_count * rate

    lessons_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_id,
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    rows = lessons_result.all()

    earned = 0
    for lesson, st in rows:
        rate = rate_resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        if lesson.status == "attended":
            earned += rate

    return goal, earned


# ── Benchmark: studio_report для всех педагогов (BEFORE: get_rate per lesson) ─

async def studio_before(session: AsyncSession, org_id: int, month_year: str):
    year, mon = map(int, month_year.split("-"))
    date_from = date(year, mon, 1)
    date_to = date(year, mon, 30)

    teachers_result = await session.execute(
        select(User).where(User.org_id == org_id, User.role == "TEACHER")
    )
    teachers = teachers_result.scalars().all()

    rows_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    all_rows = rows_result.all()
    by_teacher = {}
    for l, st in all_rows:
        by_teacher.setdefault(st.teacher_user_id, []).append((l, st))

    totals = {}
    for teacher in teachers:
        rows = by_teacher.get(teacher.id, [])
        total = 0
        for lesson, st in rows:
            rate = await get_rate(
                session, org_id, teacher.id, lesson.scheduled_date,
                instrument_id=st.instrument_id,
                student_id=st.student_id,
            )
            if lesson.status == "attended":
                total += rate
        totals[teacher.id] = total
    return totals


async def studio_after(session: AsyncSession, org_id: int, month_year: str):
    year, mon = map(int, month_year.split("-"))
    date_from = date(year, mon, 1)
    date_to = date(year, mon, 30)

    teachers_result = await session.execute(
        select(User).where(User.org_id == org_id, User.role == "TEACHER")
    )
    teachers = teachers_result.scalars().all()

    rows_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    all_rows = rows_result.all()
    by_teacher = {}
    for l, st in all_rows:
        by_teacher.setdefault(st.teacher_user_id, []).append((l, st))

    teacher_ids = [t.id for t in teachers]
    resolvers = await build_rate_resolvers_bulk(session, org_id, teacher_ids)

    totals = {}
    for teacher in teachers:
        rows = by_teacher.get(teacher.id, [])
        resolver = resolvers.get(teacher.id)
        total = 0
        for lesson, st in rows:
            rate = resolver.resolve(
                lesson.scheduled_date,
                instrument_id=st.instrument_id,
                student_id=st.student_id,
            )
            if lesson.status == "attended":
                total += rate
        totals[teacher.id] = total
    return totals


# ── Benchmark: create_lesson (BEFORE: 3 selects, AFTER: 1 join) ───────────────

async def create_lesson_lookup_before(session: AsyncSession, lesson_st_id: int, org_id: int):
    """Симулирует прежнюю последовательность: select StudentTeacher → select Student."""
    st_res = await session.execute(
        select(StudentTeacher).where(
            StudentTeacher.id == lesson_st_id,
            StudentTeacher.org_id == org_id,
        )
    )
    st = st_res.scalar_one_or_none()
    if st is None:
        return None
    s_res = await session.execute(select(Student).where(Student.id == st.student_id))
    return st, s_res.scalar_one_or_none()


async def create_lesson_lookup_after(session: AsyncSession, lesson_st_id: int, org_id: int):
    """Новая реализация: один JOIN."""
    res = await session.execute(
        select(StudentTeacher, Student)
        .join(Student, Student.id == StudentTeacher.student_id)
        .where(
            StudentTeacher.id == lesson_st_id,
            StudentTeacher.org_id == org_id,
        )
    )
    return res.first()


# ── Runner ────────────────────────────────────────────────────────────────────

def fmt_box(title: str, before_ms: float, before_q: int, after_ms: float, after_q: int):
    speedup = before_ms / after_ms if after_ms > 0 else 0
    width = 53
    print("┌" + "─" * width + "┐")
    print(f"│ {title:<{width-1}}│")
    print(f"│ До:    {before_ms:>5.1f}ms | {before_q:>3} SQL запросов{' ' * (width - 36)}│")
    print(f"│ После: {after_ms:>5.1f}ms | {after_q:>3} SQL запросов{' ' * (width - 36)}│")
    print(f"│ Прирост: {speedup:>4.1f}x быстрее ✅{' ' * (width - 27)}│")
    print("└" + "─" * width + "┘")
    print()


async def bench():
    org_id = 1
    teacher_id = 3        # Али Расулов
    month_year = "2026-04"

    async with AsyncSessionLocal() as s:
        # ── Salary V2 ──
        reset_counter()
        t = time.perf_counter()
        await salary_v2_before(s, org_id, teacher_id, month_year)
        before_ms = (time.perf_counter() - t) * 1000
        before_q = get_count()

    async with AsyncSessionLocal() as s:
        reset_counter()
        t = time.perf_counter()
        await salary_v2_after(s, org_id, teacher_id, month_year)
        after_ms = (time.perf_counter() - t) * 1000
        after_q = get_count()

    fmt_box("GET /reports/v2/salary (1 педагог)", before_ms, before_q, after_ms, after_q)

    # ── Studio (все педагоги) ──
    async with AsyncSessionLocal() as s:
        reset_counter()
        t = time.perf_counter()
        await studio_before(s, org_id, month_year)
        before_ms = (time.perf_counter() - t) * 1000
        before_q = get_count()

    async with AsyncSessionLocal() as s:
        reset_counter()
        t = time.perf_counter()
        await studio_after(s, org_id, month_year)
        after_ms = (time.perf_counter() - t) * 1000
        after_q = get_count()

    fmt_box("GET /reports/studio (все педагоги)", before_ms, before_q, after_ms, after_q)

    # ── create_lesson lookup ──
    # Возьмём существующий st_id=7 (Максим Школьный)
    async with AsyncSessionLocal() as s:
        reset_counter()
        t = time.perf_counter()
        await create_lesson_lookup_before(s, 7, org_id)
        before_ms = (time.perf_counter() - t) * 1000
        before_q = get_count()

    async with AsyncSessionLocal() as s:
        reset_counter()
        t = time.perf_counter()
        await create_lesson_lookup_after(s, 7, org_id)
        after_ms = (time.perf_counter() - t) * 1000
        after_q = get_count()

    fmt_box("POST /lessons (lookup студента)", before_ms, before_q, after_ms, after_q)


if __name__ == "__main__":
    asyncio.run(bench())
