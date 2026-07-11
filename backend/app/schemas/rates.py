from datetime import date
from pydantic import BaseModel


class RateCreateIn(BaseModel):
    teacher_user_id: int
    instrument_id: int | None = None   # null = для всех инструментов
    is_foreign: bool = False           # True = иностранный тариф
    rate_per_lesson: int
    effective_from: date
    note: str | None = None


class RateOut(BaseModel):
    id: int
    teacher_user_id: int
    instrument_id: int | None
    instrument_name: str | None
    is_foreign: bool
    rate_per_lesson: int
    effective_from: date
    note: str | None


class CurrentRateOut(BaseModel):
    """Актуальная ставка педагога на сегодня — по каждому инструменту."""
    teacher_user_id: int
    teacher_name: str | None
    rates: list[RateOut]
    default_rate: int  # ставка без инструмента (fallback)


class RateConfigIn(BaseModel):
    """Текущая ставка педагога без даты вступления (конфигуратор)."""
    rate_per_lesson: int                        # базовая ставка (обязательна, > 0)
    foreign_rate_per_lesson: int | None = None  # None/0 = иностранного тарифа нет


class CurrentRatesOut(BaseModel):
    rate_per_lesson: int                 # 0, если ставка не задана
    foreign_rate_per_lesson: int | None  # None, если иностранный тариф не задан
