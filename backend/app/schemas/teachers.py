from pydantic import BaseModel


class TeacherOut(BaseModel):
    id: int
    login: str
    teacher_name: str | None


class TeacherScheduleDay(BaseModel):
    date: str          # '2026-04-15'
    lessons_count: int
    statuses: list[str]  # ['attended', 'scheduled', 'missed']
