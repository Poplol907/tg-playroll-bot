from pydantic import BaseModel


class AdminBindIn(BaseModel):
    login: str
    telegram_user_id: int


class AdminUserOut(BaseModel):
    id: int
    login: str
    role: str
    telegram_user_id: int | None
    teacher_name: str | None