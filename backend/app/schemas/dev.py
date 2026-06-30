from pydantic import BaseModel


class CreateUserIn(BaseModel):
    login: str
    role: str
    teacher_name: str | None = None
