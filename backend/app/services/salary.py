"""Расчёт зарплаты педагога — тонкий адаптер над payroll.aggregate.

Все правила начисления живут в services/payroll.py (единый источник истины).
Здесь только: резолв foreign-aware ставок по каждому уроку и упаковка результата
в SalaryResult — форму, которую ждут studio_stats и легаси-отчёт.
"""
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import Lesson, StudentTeacher
from backend.app.services.payroll import aggregate
from backend.app.services.rates import RateResolver, build_rate_resolver


@dataclass
class LessonStat:
    lesson_id: int
    lesson_date: date
    status: str
    instrument_id: int | None
    rate: int
    counted: bool  # входит ли в зарплату


@dataclass
class SalaryResult:
    teacher_user_id: int
    org_id: int
    period_start: date
    period_end: date
    report_type: str  # advance / final

    lessons_done: int = 0
    lessons_missed: int = 0        # пропуски ученика (оплачиваются)
    lessons_debt: int = 0          # долги педагога (не оплачиваются)
    lessons_makeup_done: int = 0   # закрытые долги педагога (оплачиваются)

    total_amount: int = 0
    breakdown: list[LessonStat] = field(default_factory=list)


async def calculate_salary(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    lessons: list[tuple[Lesson, StudentTeacher]],
    period_start: date,
    period_end: date,
    report_type: str,  # advance / final
    student_foreign_map: dict[int, bool] | None = None,
    rate_resolver: RateResolver | None = None,
) -> SalaryResult:
    """Зарплата педагога за период. Делегирует правила в payroll.aggregate.

    `student_foreign_map` НУЖЕН для корректного иностранного тарифа — без него
    foreign-ученики тарифицируются по базе (эта потеря и была багом в studio/
    легаси-отчётах). `rate_resolver` снимает N+1, если передан.
    """
    resolver = rate_resolver or await build_rate_resolver(
        session, org_id, teacher_user_id
    )
    fmap = student_foreign_map or {}
    midpoint = period_start.replace(day=15)

    items = [
        (
            lesson,
            resolver.resolve(
                lesson.scheduled_date,
                instrument_id=st.instrument_id,
                student_id=st.student_id,
                is_foreign=fmap.get(st.student_id, False),
            ),
        )
        for lesson, st in lessons
        if period_start <= lesson.scheduled_date <= period_end
    ]

    t = aggregate(items, midpoint=midpoint)
    total = t.advance if report_type == "advance" else t.total

    return SalaryResult(
        teacher_user_id=teacher_user_id,
        org_id=org_id,
        period_start=period_start,
        period_end=period_end,
        report_type=report_type,
        lessons_done=t.lessons_done,
        lessons_missed=t.lessons_missed,
        lessons_debt=t.lessons_debt,
        lessons_makeup_done=t.lessons_makeup_done,
        total_amount=total,
    )
