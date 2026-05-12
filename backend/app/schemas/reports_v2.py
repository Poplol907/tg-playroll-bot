from datetime import date
from pydantic import BaseModel


class SalaryV2Out(BaseModel):
    """Ответ для Flutter-приложения: /reports/v2/salary"""
    month_year: str
    period_start: date
    period_end: date

    # ── Цель (все купленные уроки × ставки) ─────────────────────────────
    goal_amount: int          # максимальный потенциал месяца
    total_subscribed: int     # куплено уроков всего

    # ── Актуальные деньги ────────────────────────────────────────────────
    earned_amount: int        # проведённые уроки × ставки (подтверждено)
    pending_amount: int       # пропуски по вине ученика × ставки (в конце месяца)
    total_current: int        # earned + pending (показывается большим числом)

    # ── Счётчики уроков ──────────────────────────────────────────────────
    lessons_done: int         # проведено
    lessons_missed: int       # пропущено учеником (оплачивается)
    lessons_debt: int         # отменено педагогом без отработки (долг)
    lessons_makeup_done: int  # отработанные долги педагога

    # ── Разбивка выплат ──────────────────────────────────────────────────
    advance_amount: int       # аванс (1–15)
    final_amount: int         # доплата (16–конец)
    total_amount: int         # earned + pending (итого к выплате)


class SalaryReportOut(BaseModel):
    teacher_id: int
    teacher_name: str | None
    month: str
    period_start: date
    period_end: date
    report_type: str

    lessons_done: int
    lessons_missed: int
    lessons_debt: int
    lessons_cancelled_makeup: int
    total_amount: int


class StudioStatsOut(BaseModel):
    month: str
    total_lessons_done: int
    total_lessons_missed: int
    total_lessons_cancelled: int
    total_lessons_scheduled: int
    active_students: int
    active_teachers: int
    teachers: list[SalaryReportOut]
