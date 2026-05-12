from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, distinct, delete as sa_delete, update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Lesson, StudentTeacher, Student, Subscription
from backend.app.schemas.reports_v2 import SalaryReportOut, StudioStatsOut, SalaryV2Out
from backend.app.services.salary import calculate_salary
from backend.app.services.rates import build_rate_resolver, build_rate_resolvers_bulk
from backend.app.services.months import parse_month
from backend.app.services.permissions import (
    require_admin,
    require_admin_or_teacher,
    require_teacher_self_or_admin,
)

router = APIRouter(prefix="/reports", tags=["reports"])


async def _load_lessons(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    date_from: date,
    date_to: date,
) -> list[tuple[Lesson, StudentTeacher]]:
    result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_user_id,
            StudentTeacher.org_id == org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    return result.all()


# ─────────────────────────────────────────────────────────────────────────────
#  Новый endpoint для Flutter — /reports/v2/salary
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/v2/salary", response_model=SalaryV2Out)
async def salary_report_v2(
    month_year: str = Query(..., description="YYYY-MM, например 2026-04"),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Зарплата текущего педагога за месяц с геймификацией:
    - goal_amount  = потенциал (все купленные уроки × ставки)
    - earned       = проведённые × ставки (подтверждено)
    - pending      = пропущено учеником × ставки (будет выплачено в конце месяца)
    - debt_lessons = отменено педагогом без отработки
    """
    require_admin_or_teacher(current_user)

    teacher_id = current_user.id
    mr = parse_month(month_year)
    date_from, date_to, date_mid = mr.start, mr.end, mr.midpoint

    teacher = await session.get(User, teacher_id)
    if teacher is None:
        raise HTTPException(status_code=404, detail="teacher not found")

    # ── 0. Карта is_foreign + резолвер ставок (одним запросом каждое) ────
    students_result = await session.execute(
        select(Student.id, Student.is_foreign).where(Student.org_id == current_user.org_id)
    )
    foreign_map: dict[int, bool] = {row[0]: row[1] for row in students_result.all()}

    rate_resolver = await build_rate_resolver(session, current_user.org_id, teacher_id)

    # ── 1. Уроки за месяц ────────────────────────────────────────────────
    # Загружаем все уроки педагога за месяц (regular + makeup)
    rows = await _load_lessons(session, current_user.org_id, teacher_id, date_from, date_to)

    # ── 2. Цель: сумма ставок по РЕАЛЬНЫМ урокам в расписании ────────────
    # Используем фактические уроки, а не aggregated lessons_count подписок —
    # это защищает от устаревших счётчиков и даёт корректное "план = 100%".
    # Урок-отработки (lesson_type='makeup') в цель НЕ входят: они замещают
    # пропущенные уроки из подписки, а не добавляют новые слоты.
    goal_amount = 0
    total_subscribed = 0
    for lesson, st in rows:
        lesson_type = getattr(lesson, "lesson_type", "regular")
        if lesson_type != "regular":
            continue
        rate = rate_resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        goal_amount += rate
        total_subscribed += 1

    # ── 3. Начисления ──────────────────────────────────────────────────
    # Правила:
    #   attended (regular)        → заработано
    #   missed + makeup_done      → заработано (отработка состоялась)
    #   cancelled(teacher) + done → заработано (долг закрыт)
    #   missed + no makeup        → ожидает оплаты в конце месяца (pending)
    #   cancelled(teacher) + none → долг педагога (не оплачивается)
    #   attended (makeup)         → только счётчик, деньги начислены через оригинал

    earned_amount = 0
    pending_amount = 0
    lessons_done = 0
    lessons_missed = 0
    lessons_debt = 0
    lessons_makeup_done = 0

    for lesson, st in rows:
        rate = rate_resolver.resolve(
            lesson.scheduled_date,
            instrument_id=st.instrument_id,
            student_id=st.student_id,
            is_foreign=foreign_map.get(st.student_id, False),
        )
        lesson_type = getattr(lesson, "lesson_type", "regular")

        if lesson.status == "attended":
            if lesson_type == "makeup":
                # Урок-отработка: фиксируем только в счётчике.
                # Деньги начисляются через исходный урок (missed/done или cancelled/done).
                lessons_makeup_done += 1
            else:
                # Обычный проведённый урок.
                lessons_done += 1
                earned_amount += rate

        elif lesson.status == "missed":
            if lesson.makeup_status in ("done", "completed"):
                # Отработка состоялась → урок засчитан как проведённый.
                # makeup-урок уже посчитан выше в lessons_makeup_done.
                earned_amount += rate
            else:
                # Настоящий пропуск — оплачивается в конце месяца.
                lessons_missed += 1
                pending_amount += rate

        elif lesson.status == "cancelled" and lesson.cancelled_by == "teacher":
            if lesson.makeup_status in ("completed", "done"):
                # Долг закрыт отработкой → урок засчитан как проведённый.
                earned_amount += rate
            else:
                # Долг педагога без отработки.
                lessons_debt += 1

    # ── 3. Аванс (1–15) ──────────────────────────────────────────────────
    advance_rows = [(l, st) for l, st in rows if l.scheduled_date <= date_mid]
    advance = await calculate_salary(
        session, current_user.org_id, teacher_id,
        advance_rows, date_from, date_mid, "advance",
        student_foreign_map=foreign_map,
        rate_resolver=rate_resolver,
    )
    advance_amount = advance.total_amount
    total_current = earned_amount + pending_amount
    final_amount = total_current - advance_amount

    return SalaryV2Out(
        month_year=month_year,
        period_start=date_from,
        period_end=date_to,
        goal_amount=goal_amount,
        total_subscribed=total_subscribed,
        earned_amount=earned_amount,
        pending_amount=pending_amount,
        total_current=total_current,
        lessons_done=lessons_done,
        lessons_missed=lessons_missed,
        lessons_debt=lessons_debt,
        lessons_makeup_done=lessons_makeup_done,
        advance_amount=advance_amount,
        final_amount=max(0, final_amount),
        total_amount=total_current,
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Старый endpoint (оставляем для совместимости)
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/salary", response_model=SalaryReportOut)
async def salary_report(
    month: str = Query(..., examples=["2026-04"]),
    teacher_id: int = Query(...),
    report_type: str = Query("final", description="advance или final"),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_teacher_self_or_admin(current_user, teacher_id)

    if report_type not in ("advance", "final"):
        raise HTTPException(status_code=422, detail="report_type must be 'advance' or 'final'")

    mr = parse_month(month)
    date_from, date_to = mr.start, mr.end
    if report_type == "advance":
        date_to = mr.midpoint

    teacher = await session.get(User, teacher_id)
    if teacher is None or teacher.org_id != current_user.org_id:
        raise HTTPException(status_code=404, detail="teacher not found")

    rows = await _load_lessons(session, current_user.org_id, teacher_id, date_from, date_to)
    rate_resolver = await build_rate_resolver(session, current_user.org_id, teacher_id)
    salary = await calculate_salary(
        session, current_user.org_id, teacher_id, rows, date_from, date_to, report_type,
        rate_resolver=rate_resolver,
    )

    return SalaryReportOut(
        teacher_id=teacher_id,
        teacher_name=teacher.teacher_name,
        month=month,
        period_start=date_from,
        period_end=date_to,
        report_type=report_type,
        lessons_done=salary.lessons_done,
        lessons_missed=salary.lessons_missed,
        lessons_debt=salary.lessons_debt,
        lessons_cancelled_makeup=salary.lessons_makeup_done,
        total_amount=salary.total_amount,
    )


@router.get("/studio", response_model=StudioStatsOut)
async def studio_report(
    month: str = Query(..., examples=["2026-04"]),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)

    mr = parse_month(month)
    date_from, date_to = mr.start, mr.end

    teachers_result = await session.execute(
        select(User).where(User.org_id == current_user.org_id, User.role == "TEACHER")
    )
    teachers = teachers_result.scalars().all()

    all_rows_result = await session.execute(
        select(Lesson, StudentTeacher)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.org_id == current_user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    all_rows = all_rows_result.all()

    by_teacher: dict[int, list[tuple[Lesson, StudentTeacher]]] = {}
    for lesson, st in all_rows:
        by_teacher.setdefault(st.teacher_user_id, []).append((lesson, st))

    # Makeup lessons are the same lesson rescheduled — exclude from studio stats
    all_lessons = [lesson for lesson, _ in all_rows if lesson.lesson_type == "regular"]
    total_done = sum(1 for l in all_lessons if l.status == "attended")
    total_missed = sum(1 for l in all_lessons if l.status == "missed")
    total_cancelled = sum(1 for l in all_lessons if l.status == "cancelled")
    total_scheduled = sum(1 for l in all_lessons if l.status == "scheduled")

    active_students_result = await session.execute(
        select(func.count(distinct(StudentTeacher.student_id)))
        .join(Lesson, Lesson.student_teacher_id == StudentTeacher.id)
        .where(
            StudentTeacher.org_id == current_user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    active_students = active_students_result.scalar() or 0
    active_teachers = len([t for t in teachers if t.id in by_teacher])

    # Загружаем ставки сразу для всех педагогов одним запросом → нет N+1
    teacher_ids = [t.id for t in teachers]
    resolvers = await build_rate_resolvers_bulk(session, current_user.org_id, teacher_ids)

    teacher_reports = []
    for teacher in teachers:
        rows = by_teacher.get(teacher.id, [])
        salary = await calculate_salary(
            session, current_user.org_id, teacher.id, rows, date_from, date_to, "final",
            rate_resolver=resolvers.get(teacher.id),
        )
        teacher_reports.append(SalaryReportOut(
            teacher_id=teacher.id,
            teacher_name=teacher.teacher_name,
            month=month,
            period_start=date_from,
            period_end=date_to,
            report_type="final",
            lessons_done=salary.lessons_done,
            lessons_missed=salary.lessons_missed,
            lessons_debt=salary.lessons_debt,
            lessons_cancelled_makeup=salary.lessons_makeup_done,
            total_amount=salary.total_amount,
        ))

    return StudioStatsOut(
        month=month,
        total_lessons_done=total_done,
        total_lessons_missed=total_missed,
        total_lessons_cancelled=total_cancelled,
        total_lessons_scheduled=total_scheduled,
        active_students=active_students,
        active_teachers=active_teachers,
        teachers=teacher_reports,
    )


# ─────────────────────────────────────────────────────────────────────────────
#  Сброс данных месяца (только для отладки / пересчёта)
# ─────────────────────────────────────────────────────────────────────────────

@router.delete("/v2/reset-month", status_code=200)
async def reset_month(
    month_year: str = Query(..., description="YYYY-MM, например 2026-05"),
    session: AsyncSession = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Удаляет все уроки и подписки за указанный месяц для текущего педагога.
    Используется для отладки алгоритма расчёта зарплаты.
    """
    require_admin_or_teacher(current_user)
    teacher_id = current_user.id

    mr = parse_month(month_year)
    date_from, date_to = mr.start, mr.end

    # Удаляем все уроки педагога за месяц. Важно: у lessons есть self-FK
    # makeup_for_id, поэтому сначала чистим/удаляем связанные отработки,
    # иначе PostgreSQL может отказать при удалении оригинального урока.
    lessons_result = await session.execute(
        select(Lesson)
        .join(StudentTeacher, StudentTeacher.id == Lesson.student_teacher_id)
        .where(
            StudentTeacher.teacher_user_id == teacher_id,
            StudentTeacher.org_id == current_user.org_id,
            Lesson.scheduled_date >= date_from,
            Lesson.scheduled_date <= date_to,
        )
    )
    lessons = lessons_result.scalars().all()
    lesson_ids = [lesson.id for lesson in lessons]

    lessons_deleted = len(lesson_ids)
    if lesson_ids:
        # Если в сбрасываемом месяце есть makeup-уроки, их оригиналы могут быть
        # в другом месяце. Возвращаем эти оригиналы в состояние "без отработки".
        original_ids = [
            lesson.makeup_for_id
            for lesson in lessons
            if lesson.makeup_for_id is not None
        ]
        if original_ids:
            await session.execute(
                sa_update(Lesson)
                .where(
                    Lesson.org_id == current_user.org_id,
                    Lesson.id.in_(original_ids),
                )
                .values(makeup_status="none", makeup_date=None)
            )

        # Если сбрасываемый месяц содержит оригинальные уроки, удаляем все их
        # отработки, даже если сами отработки стоят в другом месяце.
        linked_makeups_result = await session.execute(
            select(Lesson.id).where(
                Lesson.org_id == current_user.org_id,
                Lesson.makeup_for_id.in_(lesson_ids),
                Lesson.id.notin_(lesson_ids),
            )
        )
        linked_makeup_ids = list(linked_makeups_result.scalars().all())
        if linked_makeup_ids:
            lessons_deleted += len(linked_makeup_ids)
            await session.execute(
                sa_delete(Lesson).where(Lesson.id.in_(linked_makeup_ids))
            )

        await session.execute(
            sa_delete(Lesson).where(
                Lesson.org_id == current_user.org_id,
                Lesson.id.in_(lesson_ids),
            )
        )

    # Удаляем все подписки педагога за месяц
    subs_result = await session.execute(
        select(Subscription).where(
            Subscription.org_id == current_user.org_id,
            Subscription.teacher_user_id == teacher_id,
            Subscription.month_year == month_year,
        )
    )
    subs = subs_result.scalars().all()
    subs_deleted = len(subs)
    for sub in subs:
        await session.delete(sub)

    await session.commit()

    return {
        "month_year": month_year,
        "lessons_deleted": lessons_deleted,
        "subscriptions_deleted": subs_deleted,
    }
