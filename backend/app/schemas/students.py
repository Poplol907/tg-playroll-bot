from datetime import datetime
from pydantic import BaseModel


class StudentCreateIn(BaseModel):
    first_name: str
    last_name: str
    phone: str | None = None
    is_foreign: bool = False
    # Only respected when submitted by ADMIN; TEACHER always creates for themselves
    teacher_user_id: int | None = None


class StudentStatusIn(BaseModel):
    status: str  # "active" | "inactive"


class StudentOut(BaseModel):
    id: int
    org_id: int
    first_name: str
    last_name: str
    phone: str | None
    status: str
    note: str | None = None
    is_foreign: bool = False
    created_at: datetime
    # Present when the listing is for a specific teacher (TEACHER role or filtered)
    student_teacher_id: int | None = None

    class Config:
        from_attributes = True