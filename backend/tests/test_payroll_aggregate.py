"""Aggregation tests — the single accrual loop every report routes through.

Lessons are lightweight stand-ins (only the attributes the aggregator reads),
so these stay DB-free and fast.
"""
from datetime import date
from types import SimpleNamespace

from backend.app.services.payroll import aggregate

RATE = 100_000
MID = date(2026, 7, 15)


def L(status, day, lesson_type="regular", cancelled_by=None, makeup_status="none"):
    return SimpleNamespace(
        status=status,
        lesson_type=lesson_type,
        cancelled_by=cancelled_by,
        makeup_status=makeup_status,
        scheduled_date=date(2026, 7, day),
    )


def test_student_cancel_is_paid_and_split_correctly():
    items = [
        (L("attended", 3), RATE),
        (L("cancelled", 10, cancelled_by="student"), RATE),
    ]
    t = aggregate(items, midpoint=MID)
    assert t.earned == RATE          # the attended lesson
    assert t.pending == RATE         # student-fault cancel, owed at month end
    assert t.total == 2 * RATE
    assert t.advance == RATE         # only the paid-now item before the 15th
    assert t.final == RATE
    assert t.lessons_done == 1
    assert t.lessons_missed == 1
    assert t.counted_total == 1


def test_makeup_pair_pays_once_and_counts_once():
    items = [
        (L("missed", 3, makeup_status="done"), RATE),
        (L("attended", 20, lesson_type="makeup"), RATE),
    ]
    t = aggregate(items, midpoint=MID)
    assert t.total == RATE           # single payment, via the original
    assert t.lessons_makeup_done == 1
    assert t.counted_total == 1      # the makeup is the one taught lesson
    assert t.lessons_missed == 0     # a closed miss is not an open miss


def test_teacher_debt_is_unpaid_but_still_in_goal():
    items = [(L("cancelled", 5, cancelled_by="teacher"), RATE)]
    t = aggregate(items, midpoint=MID)
    assert t.total == 0
    assert t.goal_amount == RATE
    assert t.debt_amount == RATE
    assert t.lessons_debt == 1
    assert t.counted_total == 0


def test_attended_after_midpoint_is_not_in_advance():
    t = aggregate([(L("attended", 20), RATE)], midpoint=MID)
    assert t.earned == RATE and t.advance == 0 and t.final == RATE


def test_total_always_equals_advance_plus_final():
    items = [
        (L("attended", 3), RATE),
        (L("attended", 20), RATE),
        (L("missed", 8), RATE),
        (L("cancelled", 9, cancelled_by="student"), RATE),
    ]
    t = aggregate(items, midpoint=MID)
    assert t.total == t.advance + t.final


def test_zero_rate_lesson_is_flagged_unrated():
    t = aggregate([(L("attended", 3), 0)], midpoint=MID)
    assert t.unrated_lessons == 1
    assert t.total == 0
