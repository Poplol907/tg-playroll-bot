"""Student HTTP routes — thin wrappers over `services.students`.

This module **does not** contain business logic. Its only job is:
  * parse query / body parameters,
  * call the matching service function,
  * map domain objects → response models.

Domain exceptions raised by the service are translated to HTTP responses
by the global handler registered in `app.main`.
"""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import Student, User
from backend.app.schemas.students import (
    StudentCreateIn,
    StudentOut,
    StudentStatusIn,
)
from backend.app.services import students as student_service
from backend.app.services.permissions import require_admin_or_teacher

router = APIRouter(prefix="/students", tags=["students"])


# ─────────────────────────────────────────────────────────────────────────────
#  Serialisation
# ─────────────────────────────────────────────────────────────────────────────


def _to_out(student: Student, student_teacher_id: int | None = None) -> StudentOut:
    data = StudentOut.model_validate(student)
    if student_teacher_id is not None:
        data.student_teacher_id = student_teacher_id
    return data


def _link_to_out(row: student_service.StudentWithLink) -> StudentOut:
    return _to_out(row.student, row.student_teacher_id)


# ─────────────────────────────────────────────────────────────────────────────
#  Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/create", response_model=StudentOut)
async def student_create(
    payload: StudentCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)
    student = await student_service.create_student(
        session,
        current_user,
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone=payload.phone,
        is_foreign=payload.is_foreign,
        teacher_user_id=payload.teacher_user_id,
    )
    return _to_out(student)


@router.get("", response_model=list[StudentOut])
async def students_list(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    rows = await student_service.list_students(session, current_user)
    return [_link_to_out(row) for row in rows]


@router.patch("/{student_id}/status", response_model=StudentOut)
async def update_student_status(
    student_id: int,
    payload: StudentStatusIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)
    student = await student_service.update_student_status(
        session,
        current_user,
        student_id=student_id,
        status=payload.status,
    )
    return _to_out(student)


@router.get("/teacher/{teacher_id}", response_model=list[StudentOut])
async def students_by_teacher(
    teacher_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    rows = await student_service.list_students_by_teacher(
        session, current_user, teacher_id=teacher_id
    )
    return [_link_to_out(row) for row in rows]


@router.delete("/{student_id}", status_code=204)
async def delete_student(
    student_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)
    await student_service.delete_student(
        session, current_user, student_id=student_id
    )
    return Response(status_code=204)
