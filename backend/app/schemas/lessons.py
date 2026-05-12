from datetime import date, time

from pydantic import BaseModel


# ─── Bulk creation ────────────────────────────────────────────────────────────

class LessonBulkSlot(BaseModel):
    """One (weekday, time) pair — e.g. {weekday: 4, time: "17:00"} = every Friday at 17:00."""
    weekday: int   # 0 = Mon … 6 = Sun  (Python datetime.weekday() convention)
    time: str      # "HH:MM"


class LessonBulkIn(BaseModel):
    student_teacher_id: int
    month_year: str            # "YYYY-MM"
    slots: list[LessonBulkSlot]


class LessonBulkOut(BaseModel):
    lessons_created: int
    subscription_id: int
    lessons: list["LessonOut"]
    warnings: list[str]        # dates that were skipped (already had a lesson)


# ─── Single creation ──────────────────────────────────────────────────────────

class LessonCreateIn(BaseModel):
    student_teacher_id: int
    subscription_id: int | None = None
    scheduled_date: date
    scheduled_time: time | None = None
    notes: str | None = None


class LessonStatusIn(BaseModel):
    # scheduled / attended / missed / cancelled
    status: str
    # student / teacher — обязательно при status=cancelled
    cancelled_by: str | None = None
    notes: str | None = None


class LessonMakeupIn(BaseModel):
    makeup_date: date


class LessonOut(BaseModel):
    id: int
    org_id: int
    student_teacher_id: int
    subscription_id: int | None
    lesson_type: str = "regular"      # regular / makeup
    makeup_for_id: int | None = None  # id оригинала для makeup-урока
    scheduled_date: date
    scheduled_time: time | None
    status: str
    cancelled_by: str | None
    makeup_status: str
    makeup_date: date | None
    payment_counted: bool
    notes: str | None
    student_name: str | None = None
    instrument_name: str | None = None


# Resolve forward reference in LessonBulkOut → LessonOut
LessonBulkOut.model_rebuild()
