from pydantic import BaseModel


class UserSetLoginIn(BaseModel):
    new_login: str