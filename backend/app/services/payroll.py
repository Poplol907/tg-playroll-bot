"""Single source of truth for teacher payroll.

Every payroll consumer — `reports.salary_v2`, `salary.calculate_salary`,
`reports.studio_stats` — routes through `classify()` + `aggregate()`. There must
be no second implementation of these rules anywhere; divergence between two
copies is exactly what silently underpaid teachers before.

Domain rules (studio owner, authoritative):
  PAID:   attended regular; student no-show ("missed"); student-fault cancel;
          teacher-fault cancel ONLY IF a makeup was completed.
  UNPAID: teacher-fault cancel without a completed makeup.
  A makeup lesson REPLACES the missed/cancelled original — money flows through
  the original; the makeup itself is a counter only (never separately paid).
  The user-facing lesson COUNT = taught lessons only: attended regular +
  completed makeups. Misses and cancellations are never counted.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Iterable

# makeup_status values meaning "the makeup happened". "completed" is a legacy
# alias for "done" tolerated on read; writers only ever produce "done".
_MAKEUP_DONE = {"done", "completed"}


@dataclass(frozen=True)
class Verdict:
    category: str        # done | missed | debt | makeup_done | scheduled | ignored
    amount: int          # money this lesson contributes (0 if unpaid)
    paid_now: bool       # realized this period → earned (advance-eligible if <= midpoint)
    paid_deferred: bool  # owed, but only at month end → pending / final
    counted: bool        # counts as a taught lesson for the user-facing count
    goal: bool           # contributes rate to goal_amount (gross scheduled value)


def classify(
    *,
    status: str,
    lesson_type: str,
    cancelled_by: str | None,
    makeup_status: str,
    rate: int,
) -> Verdict:
    """Classify one lesson into a payroll verdict. Pure — no I/O."""
    makeup_done = makeup_status in _MAKEUP_DONE

    # A makeup lesson is a counter only; money always flows through its original.
    if lesson_type == "makeup":
        if status == "attended":
            return Verdict("makeup_done", 0, False, False, True, False)
        return Verdict("ignored", 0, False, False, False, False)

    if status == "attended":
        return Verdict("done", rate, True, False, True, True)

    if status == "missed":
        # Student no-show is always paid: now if a makeup closed it, else deferred.
        return Verdict("missed", rate, makeup_done, not makeup_done, False, True)

    if status == "cancelled":
        if cancelled_by == "student":
            # Student-fault cancel is paid exactly like a no-show.
            return Verdict("missed", rate, makeup_done, not makeup_done, False, True)
        if cancelled_by == "teacher":
            # Teacher debt: paid only once a makeup is completed.
            if makeup_done:
                return Verdict("debt", rate, True, False, False, True)
            return Verdict("debt", 0, False, False, False, True)
        # Unknown fault — don't pay; still part of the scheduled goal.
        return Verdict("debt", 0, False, False, False, True)

    # scheduled / any other unresolved state — contributes only to the goal.
    return Verdict("scheduled", 0, False, False, False, True)


@dataclass(frozen=True)
class PayrollTotals:
    earned: int
    pending: int
    total: int
    advance: int
    final: int
    goal_amount: int
    debt_amount: int
    unrated_lessons: int
    lessons_done: int
    lessons_missed: int
    lessons_debt: int
    lessons_makeup_done: int
    counted_total: int


def aggregate(items: Iterable[tuple[object, int]], *, midpoint: date) -> PayrollTotals:
    """Accrue a teacher's period from (lesson, rate) pairs.

    `lesson` need only expose: status, lesson_type, cancelled_by, makeup_status,
    scheduled_date. `rate` is the ALREADY foreign-aware per-lesson rate — callers
    must resolve `is_foreign` before calling so the foreign tariff can't be
    silently dropped (it was, in two of three entry points).
    """
    earned = pending = advance = goal = debt = unrated = 0
    done = missed = debt_n = makeup_done_n = counted = 0

    for lesson, rate in items:
        vd = classify(
            status=lesson.status,
            lesson_type=getattr(lesson, "lesson_type", "regular"),
            cancelled_by=lesson.cancelled_by,
            makeup_status=lesson.makeup_status,
            rate=rate,
        )

        if vd.goal:
            goal += rate
            if rate == 0:
                unrated += 1
        if vd.paid_now:
            earned += vd.amount
            if lesson.scheduled_date <= midpoint:
                advance += vd.amount
        elif vd.paid_deferred:
            pending += vd.amount
        if vd.counted:
            counted += 1

        if vd.category == "done":
            done += 1
        elif vd.category == "makeup_done":
            makeup_done_n += 1
        elif vd.category == "missed" and vd.paid_deferred:
            missed += 1                 # OPEN miss only; closed ones are paid_now
        elif vd.category == "debt" and vd.amount == 0:
            debt_n += 1
            debt += rate

    total = earned + pending
    return PayrollTotals(
        earned=earned,
        pending=pending,
        total=total,
        advance=advance,
        final=total - advance,          # invariant: total == advance + final
        goal_amount=goal,
        debt_amount=debt,
        unrated_lessons=unrated,
        lessons_done=done,
        lessons_missed=missed,
        lessons_debt=debt_n,
        lessons_makeup_done=makeup_done_n,
        counted_total=counted,
    )
