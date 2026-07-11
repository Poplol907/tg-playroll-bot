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

# Ставки не заданы ВОВСЕ → 0, а не выдуманная сумма (иначе 20 000 молча
# «протекали» в зарплату). Урок раньше всей истории ставок берёт самую раннюю
# ставку (см. RateResolver.resolve, фаза 2); до 0 доходит только при полном
# отсутствии ставок у педагога — это подсвечивается как unrated_lessons.
DEFAULT_RATE = 0


async def get_rate(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    lesson_date: date,
    instrument_id: int | None = None,
    student_id: int | None = None,
    is_foreign: bool = False,
) -> int:
    """Ставка за один урок. Делегирует в RateResolver, чтобы приоритеты и
    backward-extension жили ровно в одном месте — одиночный лукап и пакетный
    резолвер больше не могут разойтись."""
    rates = await get_rates_for_teacher(session, org_id, teacher_user_id)
    return RateResolver(rates).resolve(
        lesson_date,
        instrument_id=instrument_id,
        student_id=student_id,
        is_foreign=is_foreign,
    )


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
        """Ставка за урок с приоритетами (персон. > иностр. > инструмент > база).

        Фаза 1 — обычный date-valid поиск (effective_from <= дата урока).
        Фаза 2 — если урок раньше ВСЕЙ истории ставок (ни одна не подошла ни в
        одном тире), берём самую раннюю ставку по тем же приоритетам. Фаза 2
        включается только когда фаза 1 не нашла НИЧЕГО, поэтому не может перебить
        валидную историческую ставку. Иначе — DEFAULT_RATE (0)."""
        hit = self._resolve_active(lesson_date, instrument_id, student_id, is_foreign)
        if hit is not None:
            return hit
        hit = self._resolve_earliest(instrument_id, student_id, is_foreign)
        if hit is not None:
            return hit
        return DEFAULT_RATE

    def _resolve_active(
        self,
        lesson_date: date,
        instrument_id: int | None,
        student_id: int | None,
        is_foreign: bool,
    ) -> int | None:
        """Фаза 1: старший по приоритету тир со ставкой effective_from <= дата."""
        if student_id is not None and student_id in self._personal:
            r = self._first_active(self._personal[student_id], lesson_date)
            if r is not None:
                return r.rate_per_lesson
        if is_foreign:
            r = self._first_active(self._foreign, lesson_date)
            if r is not None:
                return r.rate_per_lesson
        if instrument_id is not None and instrument_id in self._by_instrument:
            r = self._first_active(self._by_instrument[instrument_id], lesson_date)
            if r is not None:
                return r.rate_per_lesson
        r = self._first_active(self._base, lesson_date)
        if r is not None:
            return r.rate_per_lesson
        return None

    def _resolve_earliest(
        self,
        instrument_id: int | None,
        student_id: int | None,
        is_foreign: bool,
    ) -> int | None:
        """Фаза 2: самая ранняя ставка в старшем непустом тире. Списки
        отсортированы по дате убыванию → earliest = последний элемент."""
        if student_id is not None and self._personal.get(student_id):
            return self._personal[student_id][-1].rate_per_lesson
        if is_foreign and self._foreign:
            return self._foreign[-1].rate_per_lesson
        if instrument_id is not None and self._by_instrument.get(instrument_id):
            return self._by_instrument[instrument_id][-1].rate_per_lesson
        if self._base:
            return self._base[-1].rate_per_lesson
        return None


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


# ─────────────────────────────────────────────────────────────────────────────
#  Текущая ставка (без даты вступления): ровно одна запись на тариф
# ─────────────────────────────────────────────────────────────────────────────


async def _upsert_current_tier(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    created_by: int,
    *,
    is_foreign: bool,
    rate: int | None,
) -> None:
    """Схлопывает базовый/иностранный тариф педагога в одну запись.

    Все прочие записи этого тира (student_id и instrument_id = NULL) удаляются;
    при rate > 0 создаётся ровно одна. effective_from неважен — одна запись плюс
    backward-extension в resolve() покрывает уроки любой даты.
    """
    existing = (
        await session.execute(
            select(TeacherRate).where(
                TeacherRate.org_id == org_id,
                TeacherRate.teacher_user_id == teacher_user_id,
                TeacherRate.student_id.is_(None),
                TeacherRate.instrument_id.is_(None),
                TeacherRate.is_foreign.is_(is_foreign),
            )
        )
    ).scalars().all()
    for r in existing:
        await session.delete(r)

    if rate and rate > 0:
        session.add(TeacherRate(
            org_id=org_id,
            teacher_user_id=teacher_user_id,
            instrument_id=None,
            student_id=None,
            is_foreign=is_foreign,
            rate_per_lesson=rate,
            effective_from=date.today(),
            created_by=created_by,
        ))


async def set_current_rates(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
    created_by: int,
    *,
    base_rate: int,
    foreign_rate: int | None = None,
) -> None:
    """Задаёт текущую ставку педагога (обычную + иностранную) без истории дат.

    foreign_rate None/0 → иностранный тариф удаляется (иностранцы падают на базу).
    """
    await _upsert_current_tier(
        session, org_id, teacher_user_id, created_by,
        is_foreign=False, rate=base_rate,
    )
    await _upsert_current_tier(
        session, org_id, teacher_user_id, created_by,
        is_foreign=True, rate=foreign_rate,
    )
    await session.commit()


async def get_current_rates(
    session: AsyncSession,
    org_id: int,
    teacher_user_id: int,
) -> tuple[int, int | None]:
    """Текущая (base, foreign) ставка педагога. base=0 / foreign=None, если не задано."""
    rates = await get_rates_for_teacher(session, org_id, teacher_user_id)
    base = next(
        (r.rate_per_lesson for r in rates
         if r.student_id is None and r.instrument_id is None and not r.is_foreign),
        0,
    )
    foreign = next(
        (r.rate_per_lesson for r in rates
         if r.student_id is None and r.instrument_id is None and r.is_foreign),
        None,
    )
    return base, foreign
