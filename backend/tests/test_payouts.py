"""Выплаты: create / list / update (PATCH) / delete.

Роутер-функции — обычные async-функции; вызываем их напрямую, передавая
session и current_user вместо Depends.
"""
from datetime import date

from backend.app.routers import payouts as pr
from backend.app.schemas.payouts import PayoutCreateIn, PayoutUpdateIn


async def _create(ctx, amount=500_000, paid_at=date(2026, 7, 20)):
    return await pr.create_payout(
        PayoutCreateIn(
            teacher_user_id=ctx.teacher.id,
            month_year="2026-07",
            amount=amount,
            paid_at=paid_at,
        ),
        session=ctx.session,
        current_user=ctx.admin,
    )


async def test_update_payout_amount_only(ctx):
    created = await _create(ctx)
    updated = await pr.update_payout(
        created.id,
        PayoutUpdateIn(amount=600_000),
        session=ctx.session,
        current_user=ctx.admin,
    )
    assert updated.amount == 600_000
    assert updated.paid_at == date(2026, 7, 20)   # дата не тронута


async def test_update_payout_date_only(ctx):
    created = await _create(ctx)
    updated = await pr.update_payout(
        created.id,
        PayoutUpdateIn(paid_at=date(2026, 7, 25)),
        session=ctx.session,
        current_user=ctx.admin,
    )
    assert updated.paid_at == date(2026, 7, 25)
    assert updated.amount == 500_000              # сумма не тронута


async def test_delete_payout_removes_it(ctx):
    created = await _create(ctx)
    await pr.delete_payout(created.id, session=ctx.session, current_user=ctx.admin)
    remaining = await pr.list_payouts(
        month_year="2026-07",
        teacher_id=ctx.teacher.id,
        session=ctx.session,
        current_user=ctx.admin,
    )
    assert remaining == []
