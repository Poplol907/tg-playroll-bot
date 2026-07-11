from datetime import date

from pydantic import BaseModel


class PayoutCreateIn(BaseModel):
    teacher_user_id: int
    month_year: str       # 'YYYY-MM'
    amount: int
    paid_at: date
    note: str | None = None


class PayoutUpdateIn(BaseModel):
    """Частичное редактирование выплаты — переданы только меняемые поля."""
    amount: int | None = None
    paid_at: date | None = None
    note: str | None = None


class PayoutOut(BaseModel):
    id: int
    teacher_user_id: int
    month_year: str
    amount: int
    paid_at: date
    note: str | None
