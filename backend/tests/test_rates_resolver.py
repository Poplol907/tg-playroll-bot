"""Rate resolution — no silent 20 000, and lessons before the first rate step
back-extend to the earliest configured rate instead of leaking the default.
"""
from datetime import date

from backend.app.models import TeacherRate
from backend.app.services.rates import DEFAULT_RATE, RateResolver, get_rate


def R(rate, eff, *, student_id=None, instrument_id=None, is_foreign=False):
    return TeacherRate(
        rate_per_lesson=rate,
        effective_from=eff,
        student_id=student_id,
        instrument_id=instrument_id,
        is_foreign=is_foreign,
    )


# ── Pure RateResolver ────────────────────────────────────────────────────────

def test_default_rate_is_zero_not_a_made_up_number():
    assert DEFAULT_RATE == 0


def test_no_rates_returns_zero():
    assert RateResolver([]).resolve(date(2026, 7, 10)) == 0


def test_basic_base_rate():
    assert RateResolver([R(100_000, date(2026, 7, 1))]).resolve(date(2026, 7, 10)) == 100_000


def test_lesson_before_earliest_step_uses_earliest_rate():
    # Rate first set on the 8th; a lesson on the 3rd must NOT fall to the default.
    r = RateResolver([R(100_000, date(2026, 7, 8))])
    assert r.resolve(date(2026, 7, 3)) == 100_000


def test_backward_extension_never_overrides_a_valid_historical_rate():
    # base 50k from January, a new personal 200k from Jul-08; lesson on Jul-03.
    r = RateResolver([
        R(50_000, date(2026, 1, 1)),
        R(200_000, date(2026, 7, 8), student_id=7),
    ])
    # base 50k is date-valid on Jul-03 → 50k wins; the future personal rate must not.
    assert r.resolve(date(2026, 7, 3), student_id=7) == 50_000


def test_backward_extension_keeps_tier_priority():
    # only a personal rate exists (future); a lesson before it back-extends to it.
    r = RateResolver([R(200_000, date(2026, 7, 8), student_id=7)])
    assert r.resolve(date(2026, 7, 3), student_id=7) == 200_000


def test_priority_personal_over_base():
    r = RateResolver([
        R(100_000, date(2026, 1, 1)),
        R(150_000, date(2026, 1, 1), student_id=7),
    ])
    assert r.resolve(date(2026, 7, 3), student_id=7) == 150_000
    assert r.resolve(date(2026, 7, 3)) == 100_000


def test_latest_effective_within_tier_wins():
    r = RateResolver([
        R(100_000, date(2026, 1, 1)),
        R(120_000, date(2026, 6, 1)),
    ])
    assert r.resolve(date(2026, 7, 3)) == 120_000
    assert r.resolve(date(2026, 5, 1)) == 100_000


# ── get_rate (DB path shares the same logic) ─────────────────────────────────

async def test_get_rate_with_no_rates_is_zero(ctx):
    v = await get_rate(ctx.session, ctx.org.id, ctx.teacher.id, date(2026, 7, 10))
    assert v == 0


async def test_get_rate_backfills_lessons_before_first_step(ctx):
    ctx.session.add(TeacherRate(
        org_id=ctx.org.id,
        teacher_user_id=ctx.teacher.id,
        rate_per_lesson=100_000,
        effective_from=date(2026, 7, 8),
        created_by=ctx.admin.id,
    ))
    await ctx.session.commit()
    early = await get_rate(ctx.session, ctx.org.id, ctx.teacher.id, date(2026, 7, 3))
    assert early == 100_000
