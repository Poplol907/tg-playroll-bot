"""Truth-table tests for the single-source-of-truth payroll classifier.

These encode the studio owner's domain rules directly. They must pass for
every payroll consumer (salary_v2, calculate_salary, studio_stats) because
all of them route through `classify()`.
"""
from backend.app.services.payroll import classify

RATE = 100_000


def v(status, lesson_type="regular", cancelled_by=None, makeup_status="none", rate=RATE):
    return classify(
        status=status,
        lesson_type=lesson_type,
        cancelled_by=cancelled_by,
        makeup_status=makeup_status,
        rate=rate,
    )


def test_attended_regular_is_paid_now_and_counted():
    r = v("attended")
    assert r.category == "done"
    assert r.amount == RATE
    assert r.paid_now and not r.paid_deferred
    assert r.counted and r.goal


def test_attended_makeup_counts_but_pays_zero():
    r = v("attended", lesson_type="makeup")
    assert r.category == "makeup_done"
    assert r.amount == 0
    assert not r.paid_now and not r.paid_deferred
    assert r.counted        # a makeup replaces a miss → it IS the taught lesson
    assert not r.goal       # but it must not inflate the goal


def test_unattended_makeup_is_ignored():
    r = v("scheduled", lesson_type="makeup")
    assert r.category == "ignored"
    assert r.amount == 0 and not r.counted and not r.goal


def test_missed_without_makeup_is_deferred_pay_not_counted():
    r = v("missed")
    assert r.category == "missed"
    assert r.amount == RATE
    assert not r.paid_now and r.paid_deferred
    assert not r.counted     # a no-show is not a taught lesson
    assert r.goal


def test_missed_with_completed_makeup_is_paid_now():
    r = v("missed", makeup_status="done")
    assert r.category == "missed"
    assert r.amount == RATE
    assert r.paid_now and not r.paid_deferred
    assert not r.counted


def test_teacher_cancel_without_makeup_is_unpaid_debt():
    r = v("cancelled", cancelled_by="teacher")
    assert r.category == "debt"
    assert r.amount == 0
    assert not r.paid_now and not r.paid_deferred
    assert not r.counted and r.goal


def test_teacher_cancel_with_completed_makeup_is_paid():
    r = v("cancelled", cancelled_by="teacher", makeup_status="done")
    assert r.category == "debt"
    assert r.amount == RATE
    assert r.paid_now


def test_student_cancel_is_paid_like_a_miss():
    # THE core regression: student-fault cancels MUST be paid (salary_v2 dropped them).
    r = v("cancelled", cancelled_by="student")
    assert r.category == "missed"
    assert r.amount == RATE
    assert r.paid_deferred and not r.paid_now
    assert not r.counted


def test_student_cancel_with_completed_makeup_is_paid_now():
    r = v("cancelled", cancelled_by="student", makeup_status="done")
    assert r.amount == RATE and r.paid_now


def test_cancel_unknown_fault_is_not_paid():
    r = v("cancelled", cancelled_by=None)
    assert r.category == "debt" and r.amount == 0 and not r.paid_now


def test_scheduled_regular_contributes_only_to_goal():
    r = v("scheduled")
    assert r.category == "scheduled"
    assert r.amount == 0 and not r.paid_now and not r.paid_deferred
    assert not r.counted and r.goal


def test_completed_is_accepted_as_done_alias():
    # Legacy data may carry makeup_status="completed"; treat it as "done".
    assert v("missed", makeup_status="completed").paid_now
