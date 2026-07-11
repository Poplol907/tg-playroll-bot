"""End-to-end payroll: every report routes through one classifier, so the
teacher's screen, the admin studio view, and the legacy report must agree.
"""
from datetime import date

from backend.app.models import Lesson, TeacherRate
from backend.app.services import reports as rs

RATE = 100_000


async def _rate(ctx, amount=RATE, eff=date(2026, 7, 1), **kw):
    ctx.session.add(TeacherRate(
        org_id=ctx.org.id,
        teacher_user_id=ctx.teacher.id,
        rate_per_lesson=amount,
        effective_from=eff,
        created_by=ctx.admin.id,
        **kw,
    ))
    await ctx.session.commit()


async def _lesson(ctx, day, *, status="attended", cancelled_by=None,
                  lesson_type="regular", makeup_for_id=None, makeup_status="none"):
    lesson = Lesson(
        org_id=ctx.org.id,
        student_teacher_id=ctx.st.id,
        scheduled_date=date(2026, 7, day),
        status=status,
        cancelled_by=cancelled_by,
        lesson_type=lesson_type,
        makeup_for_id=makeup_for_id,
        makeup_status=makeup_status,
    )
    ctx.session.add(lesson)
    await ctx.session.commit()
    await ctx.session.refresh(lesson)
    return lesson


async def test_salary_v2_pays_student_cancellation(ctx):
    await _rate(ctx)
    await _lesson(ctx, 3, status="attended")
    await _lesson(ctx, 10, status="cancelled", cancelled_by="student")
    r = await rs.salary_v2(ctx.session, ctx.teacher, month_year="2026-07", teacher_id=None)
    assert r.total_amount == 2 * RATE                       # both are paid
    assert r.total_amount == r.advance_amount + r.final_amount
    assert r.lessons_done == 1
    assert r.lessons_missed == 1


async def test_teacher_cancel_without_makeup_is_not_paid(ctx):
    await _rate(ctx)
    await _lesson(ctx, 3, status="attended")
    await _lesson(ctx, 12, status="cancelled", cancelled_by="teacher")
    r = await rs.salary_v2(ctx.session, ctx.teacher, month_year="2026-07", teacher_id=None)
    assert r.total_amount == RATE                           # only the attended
    assert r.lessons_debt == 1


async def test_admin_studio_and_teacher_totals_match(ctx):
    await _rate(ctx)
    await _lesson(ctx, 3, status="attended")
    await _lesson(ctx, 10, status="cancelled", cancelled_by="student")
    await _lesson(ctx, 12, status="cancelled", cancelled_by="teacher")
    teacher_view = await rs.salary_v2(
        ctx.session, ctx.teacher, month_year="2026-07", teacher_id=None
    )
    studio = await rs.studio_stats(ctx.session, ctx.admin, month="2026-07")
    ts = next(t for t in studio.teacher_salaries if t.teacher.id == ctx.teacher.id)
    assert ts.salary.total_amount == teacher_view.total_amount


async def test_foreign_tariff_applied_in_studio_view(ctx):
    await _rate(ctx, 100_000)
    await _rate(ctx, 150_000, is_foreign=True)
    ctx.student.is_foreign = True
    await ctx.session.commit()
    await _lesson(ctx, 3, status="attended")
    studio = await rs.studio_stats(ctx.session, ctx.admin, month="2026-07")
    ts = next(t for t in studio.teacher_salaries if t.teacher.id == ctx.teacher.id)
    assert ts.salary.total_amount == 150_000               # foreign tariff, not base


async def test_makeup_pair_is_paid_once(ctx):
    await _rate(ctx)
    original = await _lesson(ctx, 3, status="missed", makeup_status="done")
    await _lesson(ctx, 20, status="attended", lesson_type="makeup",
                  makeup_for_id=original.id)
    r = await rs.salary_v2(ctx.session, ctx.teacher, month_year="2026-07", teacher_id=None)
    assert r.total_amount == RATE                           # single payment via original
    assert r.lessons_makeup_done == 1


async def test_rate_set_midmonth_still_pays_earlier_lessons(ctx):
    # The reported "extra 20k": rate first set on the 8th, lesson on the 3rd.
    await _rate(ctx, 100_000, eff=date(2026, 7, 8))
    await _lesson(ctx, 3, status="attended")
    await _lesson(ctx, 10, status="attended")
    r = await rs.salary_v2(ctx.session, ctx.teacher, month_year="2026-07", teacher_id=None)
    assert r.total_amount == 2 * 100_000                    # no 20 000 leak
