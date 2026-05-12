from pydantic import BaseModel


class LoginIn(BaseModel):
    login: str
    password: str


class SetPasswordIn(BaseModel):
    login: str
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: str
    teacher_name: str | None
