from pydantic import BaseModel


class AdminUserOut(BaseModel):
    id: int
    login: str
    role: str
    teacher_name: str | None

class AdminCreateUserIn(BaseModel):
    login: str
    role: str
    teacher_name: str | None = None


class AdminSetRoleIn(BaseModel):
    login: str
    role: str

class AdminSetLoginIn(BaseModel):
    login: str
    new_login: str