"""Makeup lifecycle — links must never orphan or duplicate.

Encodes the correct behaviour; fails against the pre-fix `update_lesson_status`
which only cleaned up makeups on the `→scheduled` transition.
"""
from datetime import date

import pytest
from sqlalchemy import func, select

from backend.app.models import Lesson
from backend.app.services import lessons as svc
from backend.app.services.errors import BusinessRuleViolation


async def _count_makeups(session, original_id):
    return (
        await session.execute(
            select(func.count(Lesson.id)).where(Lesson.makeup_for_id == original_id)
        )
    ).scalar()


async def test_reverting_missed_to_attended_removes_pending_makeup(ctx, mk):
    s = ctx.session
    original = await mk(3, status="missed")
    await svc.schedule_makeup(
        s, ctx.admin, lesson_id=original.id, makeup_date=date(2026, 7, 20)
    )
    assert await _count_makeups(s, original.id) == 1

    # The user "returns" the original and marks it attended (the reported bug).
    await svc.update_lesson_status(
        s, ctx.admin, lesson_id=original.id, status="attended"
    )

    assert await _count_makeups(s, original.id) == 0     # phantom must be gone
    await s.refresh(original)
    assert original.status == "attended"
    assert original.makeup_status == "none"


async def test_reverting_to_attended_removes_even_completed_makeup(ctx, mk):
    s = ctx.session
    original = await mk(3, status="missed")
    res = await svc.schedule_makeup(
        s, ctx.admin, lesson_id=original.id, makeup_date=date(2026, 7, 20)
    )
    # Teacher actually performs the makeup.
    await svc.update_lesson_status(
        s, ctx.admin, lesson_id=res.lesson.id, status="attended"
    )
    await s.refresh(original)
    assert original.makeup_status == "done"

    # Original is then corrected to attended → the makeup is spurious.
    await svc.update_lesson_status(
        s, ctx.admin, lesson_id=original.id, status="attended"
    )
    assert await _count_makeups(s, original.id) == 0
    await s.refresh(original)
    assert original.makeup_status == "none"


async def test_recancelling_does_not_spawn_duplicate_makeup(ctx, mk):
    s = ctx.session
    original = await mk(3, status="missed")
    await svc.schedule_makeup(
        s, ctx.admin, lesson_id=original.id, makeup_date=date(2026, 7, 20)
    )
    # Re-classify as a teacher cancellation — still a needs-makeup state.
    await svc.update_lesson_status(
        s, ctx.admin, lesson_id=original.id, status="cancelled", cancelled_by="teacher"
    )
    await s.refresh(original)
    assert await _count_makeups(s, original.id) == 1        # existing makeup survives
    assert original.makeup_status == "scheduled"            # cache reflects the row

    # A second makeup must be refused (the duplicate-generator bug).
    with pytest.raises(BusinessRuleViolation):
        await svc.schedule_makeup(
            s, ctx.admin, lesson_id=original.id, makeup_date=date(2026, 7, 25)
        )
    assert await _count_makeups(s, original.id) == 1


async def test_attending_makeup_marks_original_done(ctx, mk):
    s = ctx.session
    original = await mk(3, status="missed")
    res = await svc.schedule_makeup(
        s, ctx.admin, lesson_id=original.id, makeup_date=date(2026, 7, 20)
    )
    await svc.update_lesson_status(
        s, ctx.admin, lesson_id=res.lesson.id, status="attended"
    )
    await s.refresh(original)
    assert original.makeup_status == "done"
    assert original.makeup_date == date(2026, 7, 20)
