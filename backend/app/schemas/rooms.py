from datetime import date, time

from pydantic import BaseModel, field_serializer


class RoomOut(BaseModel):
    id: int
    name: str
    sort_order: int
    is_active: bool


class RoomCreateIn(BaseModel):
    name: str


class RoomUpdateIn(BaseModel):
    name: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class RoomBlockOut(BaseModel):
    id: int
    room_id: int
    teacher_user_id: int
    weekday: int | None
    specific_date: date | None
    start_time: time
    end_time: time
    note: str | None

    @field_serializer("start_time", "end_time")
    def _format_time(self, value: time) -> str:
        return value.strftime("%H:%M")


class RoomBlockCreateIn(BaseModel):
    room_id: int
    teacher_user_id: int
    start_time: time
    end_time: time
    weekday: int | None = None
    specific_date: date | None = None
    note: str | None = None


class ResolvedBlockOut(BaseModel):
    id: int
    room_id: int
    room_name: str
    teacher_user_id: int
    teacher_name: str | None
    start_time: time
    end_time: time
    note: str | None
    is_recurring: bool
    specific_date: date | None
    weekday: int | None

    @field_serializer("start_time", "end_time")
    def _format_time(self, value: time) -> str:
        return value.strftime("%H:%M")


class CancelIn(BaseModel):
    date: date
