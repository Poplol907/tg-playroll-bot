"""Сервис расчёта зарплаты педагога.

Правила (из мастер-документа):
  АВАНС (1–15):
    + attended уроки за 1–15
    — missed и cancelled НЕ включаются

  ФИНАЛ (1–конец месяца):
    + все attended
    + missed (пропуски ученика — оплачиваются педагогу)
    + cancelled + makeup_status='done' (отработанные долги)
    — cancelled без отработки НЕ оплачиваются

Ставка берётся из БД через services/rates.py для каждого урока отдельно
(у педагога может быть разная ставка для разных инструментов).
"""
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import Lesson, StudentTeacher
from backend.app.services.rates import RateResolver, build_rate_resolver, get_rate


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
    """Считает зарплату педагога.

    Опциональный `rate_resolver` устраняет N+1 — если он передан, ставки
    резолвятся в памяти. Если не передан — загружается одним запросом.
    """
    result = SalaryResult(
        teacher_user_id=teacher_user_id,
        org_id=org_id,
        period_start=period_start,
        period_end=period_end,
        report_type=report_type,
    )

    # Готовим резолвер ставок один раз — снимает N+1 в цикле
    resolver = rate_resolver or await build_rate_resolver(session, org_id, teacher_user_id)

    for lesson, st in lessons:
        if not (period_start <= lesson.scheduled_date <= period_end):
            continue

        is_foreign = (student_foreign_map or {}).get(st.student_id, False)
        rate = resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=is_foreign,
        )

        counted = False
        lesson_type = getattr(lesson, "lesson_type", "regular")

        if lesson.status == "attended":
            if lesson_type == "makeup":
                # Урок-отработка: только счётчик. Деньги — через исходный урок.
                result.lessons_makeup_done += 1
                counted = False
            else:
                result.lessons_done += 1
                counted = True

        elif lesson.status == "missed":
            if lesson.makeup_status in ("done", "completed"):
                # Отработка состоялась → начисляем как проведённый.
                # В аванс включаем только если оригинал был в 1–15.
                counted = True
            elif report_type == "final":
                # Настоящий пропуск — в аванс не идёт, только в финал.
                result.lessons_missed += 1
                counted = True
            else:
                counted = False

        elif lesson.status == "cancelled" and lesson.cancelled_by == "teacher":
            if lesson.makeup_status in ("done", "completed"):
                # Долг закрыт → начисляем как проведённый.
                counted = True
            else:
                result.lessons_debt += 1
                counted = False

        elif lesson.status == "cancelled" and lesson.cancelled_by == "student":
            # Отмена по вине ученика: в финал оплачивается как missed
            if report_type == "final":
                result.lessons_missed += 1
                counted = True
            else:
                counted = False

        if counted:
            result.total_amount += rate

        result.breakdown.append(LessonStat(
            lesson_id=lesson.id,
            lesson_date=lesson.scheduled_date,
            status=lesson.status,
            instrument_id=st.instrument_id,
            rate=rate,
            counted=counted,
        ))

    return result
