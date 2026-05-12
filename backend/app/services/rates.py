"""Сервис получения ставки педагога.

Приоритет (от точного к общему):
  1. teacher + student_id + effective_from <= lesson_date  → персональная ставка ученика
  2. teacher + is_foreign=True + effective_from <= lesson_date  → иностранный тариф
  3. teacher + instrument + effective_from <= lesson_date  → ставка по инструменту
  4. teacher + instrument IS NULL + effective_from <= lesson_date  → базовая ставка
  5. Fallback: DEFAULT_RATE (если ставки не настроены)
"""
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import TeacherRate

DEFAULT_RATE = 20_000  # сум — используется только если ставки не заданы


async def get_rate(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    lesson_date: date,
    instrument_id: int | None = None,
    student_id: int | None = None,
    is_foreign: bool = False,
) -> int:
    """Возвращает ставку за один урок в сумах."""

    base_where = [
        TeacherRate.org_id == org_id,
        TeacherRate.teacher_user_id == teacher_user_id,
        TeacherRate.effective_from <= lesson_date,
    ]

    # 1. Персональная ставка для конкретного ученика
    if student_id is not None:
        result = await session.execute(
            select(TeacherRate.rate_per_lesson)
            .where(*base_where, TeacherRate.student_id == student_id)
            .order_by(TeacherRate.effective_from.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row is not None:
            return row

    # 2. Иностранный тариф (если ученик помечен is_foreign)
    if is_foreign:
        result = await session.execute(
            select(TeacherRate.rate_per_lesson)
            .where(
                *base_where,
                TeacherRate.student_id.is_(None),
                TeacherRate.is_foreign.is_(True),
            )
            .order_by(TeacherRate.effective_from.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row is not None:
            return row

    # 3. Ставка по инструменту
    if instrument_id is not None:
        result = await session.execute(
            select(TeacherRate.rate_per_lesson)
            .where(
                *base_where,
                TeacherRate.student_id.is_(None),
                TeacherRate.is_foreign.is_(False),
                TeacherRate.instrument_id == instrument_id,
            )
            .order_by(TeacherRate.effective_from.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row is not None:
            return row

    # 4. Базовая ставка (без инструмента, без ученика, не иностранная)
    result = await session.execute(
        select(TeacherRate.rate_per_lesson)
        .where(
            *base_where,
            TeacherRate.student_id.is_(None),
            TeacherRate.is_foreign.is_(False),
            TeacherRate.instrument_id.is_(None),
        )
        .order_by(TeacherRate.effective_from.desc())
        .limit(1)
    )
    row = result.scalar_one_or_none()
    if row is not None:
        return row

    return DEFAULT_RATE


async def get_rates_for_teacher(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
) -> list[TeacherRate]:
    """Вся история ставок педагога."""
    result = await session.execute(
        select(TeacherRate)
        .where(
            TeacherRate.org_id == org_id,
            TeacherRate.teacher_user_id == teacher_user_id,
        )
        .order_by(TeacherRate.effective_from.desc())
    )
    return result.scalars().all()


# ─────────────────────────────────────────────────────────────────────────────
#  RateResolver — пакетная загрузка ставок одним запросом для отчётов.
#
#  Зачем: в отчётах зарплаты вызов `get_rate()` для каждого урока делает 1–4
#  отдельных SQL-запроса. На 30 уроках это 120 запросов. RateResolver
#  загружает ВСЕ ставки педагога(ов) одним запросом и резолвит их в памяти —
#  это сокращает число запросов в ~30 раз с ровно той же логикой приоритетов.
# ─────────────────────────────────────────────────────────────────────────────


class RateResolver:
    """Резолвер ставок с предзагрузкой. Логика приоритетов идентична get_rate()."""

    def __init__(self, rates: list[TeacherRate]):
        # Раскладываем на 4 списка по типам, отсортировано по дате убывания —
        # первый матч с effective_from <= lesson_date и есть ответ.
        self._personal: dict[int, list[TeacherRate]] = {}     # student_id -> rates
        self._foreign: list[TeacherRate] = []                 # is_foreign=True, student_id NULL
        self._by_instrument: dict[int, list[TeacherRate]] = {}  # instrument_id -> rates
        self._base: list[TeacherRate] = []                    # student NULL, instrument NULL, foreign=False

        # Гарантируем сортировку по effective_from DESC (как в SQL ORDER BY)
        rates_sorted = sorted(rates, key=lambda r: r.effective_from, reverse=True)

        for r in rates_sorted:
            if r.student_id is not None:
                self._personal.setdefault(r.student_id, []).append(r)
            elif r.is_foreign:
                self._foreign.append(r)
            elif r.instrument_id is not None:
                self._by_instrument.setdefault(r.instrument_id, []).append(r)
            else:
                self._base.append(r)

    @staticmethod
    def _first_active(rates: list[TeacherRate], on_date: date) -> TeacherRate | None:
        """Первая ставка с effective_from <= on_date (список уже отсортирован DESC)."""
        for r in rates:
            if r.effective_from <= on_date:
                return r
        return None

    def resolve(
        self,
        lesson_date: date,
        instrument_id: int | None = None,
        student_id: int | None = None,
        is_foreign: bool = False,
    ) -> int:
        """Возвращает ставку. Логика идентична get_rate()."""
        # 1. Персональная ставка ученика
        if student_id is not None and student_id in self._personal:
            r = self._first_active(self._personal[student_id], lesson_date)
            if r is not None:
                return r.rate_per_lesson

        # 2. Иностранный тариф
        if is_foreign:
            r = self._first_active(self._foreign, lesson_date)
            if r is not None:
                return r.rate_per_lesson

        # 3. Ставка по инструменту
        if instrument_id is not None and instrument_id in self._by_instrument:
            r = self._first_active(self._by_instrument[instrument_id], lesson_date)
            if r is not None:
                return r.rate_per_lesson

        # 4. Базовая ставка
        r = self._first_active(self._base, lesson_date)
        if r is not None:
            return r.rate_per_lesson

        return DEFAULT_RATE


async def build_rate_resolver(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
) -> RateResolver:
    """Загружает все ставки педагога одним запросом и возвращает резолвер."""
    rates = await get_rates_for_teacher(session, org_id, teacher_user_id)
    return RateResolver(rates)


async def build_rate_resolvers_bulk(
    session: AsyncSession,
    org_id: int,
    teacher_user_ids: list[int],
) -> dict[int, RateResolver]:
    """Загружает ставки сразу для нескольких педагогов одним запросом.
    Используется в studio_report для избежания N+1 по педагогам."""
    if not teacher_user_ids:
        return {}
    result = await session.execute(
        select(TeacherRate).where(
            TeacherRate.org_id == org_id,
            TeacherRate.teacher_user_id.in_(teacher_user_ids),
        )
    )
    rates = result.scalars().all()
    grouped: dict[int, list[TeacherRate]] = {tid: [] for tid in teacher_user_ids}
    for r in rates:
        grouped.setdefault(r.teacher_user_id, []).append(r)
    return {tid: RateResolver(rs) for tid, rs in grouped.items()}
