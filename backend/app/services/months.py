"""Парсинг месяца и связанные утилиты.

Формат: 'YYYY-MM' (например '2026-04').
"""
import calendar
from dataclasses import dataclass
from datetime import date

from fastapi import HTTPException


@dataclass(frozen=True)
class MonthRange:
    year: int
    month: int
    start: date
    end: date         # последний день месяца включительно
    midpoint: date    # 15-е число (граница аванс/финал)

    @property
    def month_year(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"


def parse_month(month_str: str) -> MonthRange:
    """Парсит 'YYYY-MM'. Бросает 422 при невалидном формате."""
    try:
        year, mon = map(int, month_str.split("-"))
        if not (1 <= mon <= 12) or year < 2000 or year > 2100:
            raise ValueError
        last_day = calendar.monthrange(year, mon)[1]
        return MonthRange(
            year=year,
            month=mon,
            start=date(year, mon, 1),
            end=date(year, mon, last_day),
            midpoint=date(year, mon, 15),
        )
    except (ValueError, AttributeError):
        raise HTTPException(status_code=422, detail="month must be 'YYYY-MM'")
