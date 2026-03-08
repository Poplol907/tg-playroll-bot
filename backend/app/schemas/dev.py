from pydantic import BaseModel


class CreateUserIn(BaseModel):
    login: str
    role: str
    teacher_name: str | None = None


class BindIn(BaseModel):
    login: str
    telegram_user_id: int
