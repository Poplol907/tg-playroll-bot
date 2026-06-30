from pydantic import BaseModel, Field


class OrgUserOut(BaseModel):
    id: int
    login: str
    role: str
    teacher_name: str | None = None
    has_password: bool

    class Config:
        from_attributes = True


class OrgUserCreateIn(BaseModel):
    login: str
    role: str = "TEACHER"          # TEACHER | ADMIN
    teacher_name: str | None = None
    password: str | None = Field(default=None, min_length=8, max_length=128)  # optional — can be set later


class OrgUserUpdateIn(BaseModel):
    teacher_name: str | None = None
    role: str | None = None


class OrgSetPasswordIn(BaseModel):
    password: str = Field(min_length=8, max_length=128)
