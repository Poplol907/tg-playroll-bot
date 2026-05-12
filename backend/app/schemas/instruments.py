from pydantic import BaseModel


class InstrumentCreateIn(BaseModel):
    name: str


class InstrumentOut(BaseModel):
    id: int
    name: str
    is_active: bool
