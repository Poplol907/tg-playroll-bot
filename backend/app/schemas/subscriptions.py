from datetime import date

from pydantic import BaseModel


class SubscriptionCreateIn(BaseModel):
    student_id: int
    teacher_user_id: int
    month_year: str        # '2026-04'
    lessons_count: int
    paid_at: date | None = None


class SubscriptionUpdateIn(BaseModel):
    lessons_count: int | None = None
    paid_at: date | None = None
    status: str | None = None  # active / frozen / cancelled


class SubscriptionOut(BaseModel):
    id: int
    student_id: int
    teacher_user_id: int
    month_year: str
    lessons_count: int
    paid_at: date | None
    status: str
