from pydantic import BaseModel, Field


class LoginIn(BaseModel):
    login: str
    password: str


class SetPasswordIn(BaseModel):
    login: str
    password: str = Field(min_length=8, max_length=128)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: str
    teacher_name: str | None
