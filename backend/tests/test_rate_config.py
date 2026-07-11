"""Конфигуратор ставки без даты: одна текущая ставка на тариф (base/foreign),
изменение схлопывает историю и применяется ко всем месяцам.
"""
from datetime import date

from sqlalchemy import select

from backend.app.models import TeacherRate
from backend.app.services.rates import (
    get_current_rates,
    get_rate,
    set_current_rates,
)


async def _base_rows(ctx):
    return (
        await ctx.session.execute(
            select(TeacherRate).where(
                TeacherRate.teacher_user_id == ctx.teacher.id,
                TeacherRate.student_id.is_(None),
                TeacherRate.instrument_id.is_(None),
                TeacherRate.is_foreign.is_(False),
            )
        )
    ).scalars().all()


async def _set(ctx, *, base, foreign=None):
    await set_current_rates(
        ctx.session,
        ctx.org.id,
        ctx.teacher.id,
        ctx.admin.id,
        base_rate=base,
        foreign_rate=foreign,
    )


async def test_setting_base_keeps_exactly_one_row(ctx):
    await _set(ctx, base=100_000)
    rows = await _base_rows(ctx)
    assert len(rows) == 1
    assert rows[0].rate_per_lesson == 100_000


async def test_changing_base_collapses_history_to_one(ctx):
    # две «исторические» base-записи с разными датами
    ctx.session.add_all([
        TeacherRate(org_id=ctx.org.id, teacher_user_id=ctx.teacher.id,
                    rate_per_lesson=50_000, effective_from=date(2026, 1, 1),
                    created_by=ctx.admin.id),
        TeacherRate(org_id=ctx.org.id, teacher_user_id=ctx.teacher.id,
                    rate_per_lesson=80_000, effective_from=date(2026, 6, 1),
                    created_by=ctx.admin.id),
    ])
    await ctx.session.commit()

    await _set(ctx, base=120_000)
    rows = await _base_rows(ctx)
    assert len(rows) == 1                      # схлопнулось в одну
    assert rows[0].rate_per_lesson == 120_000


async def test_base_applies_to_all_dates(ctx):
    await _set(ctx, base=100_000)
    # урок задолго до сегодняшней даты всё равно берёт текущую ставку
    early = await get_rate(ctx.session, ctx.org.id, ctx.teacher.id, date(2020, 1, 1))
    assert early == 100_000


async def test_foreign_rate_set_then_cleared(ctx):
    await _set(ctx, base=100_000, foreign=150_000)
    base, foreign = await get_current_rates(ctx.session, ctx.org.id, ctx.teacher.id)
    assert (base, foreign) == (100_000, 150_000)
    # иностранный ученик тарифицируется по 150k
    fr = await get_rate(ctx.session, ctx.org.id, ctx.teacher.id,
                        date(2026, 7, 10), is_foreign=True)
    assert fr == 150_000

    # очистка иностранного тарифа → иностранцы падают на базовую
    await _set(ctx, base=100_000, foreign=None)
    base, foreign = await get_current_rates(ctx.session, ctx.org.id, ctx.teacher.id)
    assert (base, foreign) == (100_000, None)
    fr2 = await get_rate(ctx.session, ctx.org.id, ctx.teacher.id,
                         date(2026, 7, 10), is_foreign=True)
    assert fr2 == 100_000


async def test_get_current_rates_defaults_to_zero_none(ctx):
    base, foreign = await get_current_rates(ctx.session, ctx.org.id, ctx.teacher.id)
    assert base == 0
    assert foreign is None
