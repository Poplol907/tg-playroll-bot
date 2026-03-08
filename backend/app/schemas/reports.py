from pydantic import BaseModel


class CalcTextIn(BaseModel):
    text: str


class CalcLineOut(BaseModel):
    first: str
    last: str
    lessons: int
    price: int
    total: int


class CalcOut(BaseModel):
    count: int
    sum: int
    lines: list[CalcLineOut]


class CalcSavedOut(CalcOut):
    report_id: int


class ReportShortOut(BaseModel):
    report_id: int
    created_at: str
    total_sum: int


class ReportFullOut(BaseModel):
    report_id: int
    created_at: str
    total_sum: int
    raw_text: str