"""Student management service.

All business logic for students lives here:

* listing with role-based filters (admin sees the org, teacher sees their own),
* creation with duplicate detection + teacher assignment,
* status transitions (active / inactive),
* deletion with cascading cleanup of lessons, subscriptions, and teacher links.

Functions raise `services.errors.DomainError` subclasses on failure —
NEVER `HTTPException`. The router translates them at the boundary.

Each public function takes an `AsyncSession` and a `User` (the actor) plus
the request data, and returns domain objects (SQLAlchemy models or simple
dataclasses), not HTTP response models.
"""

from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import delete as sa_delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.models import Lesson, Student, StudentTeacher, Subscription, User
from backend.app.services.errors import (
    Conflict,
    Forbidden,
    NotFound,
    ValidationError,
)

# ─────────────────────────────────────────────────────────────────────────────
#  Constants (domain vocabulary)
# ─────────────────────────────────────────────────────────────────────────────

VALID_STATUSES = {"active", "inactive"}


# ─────────────────────────────────────────────────────────────────────────────
#  Result objects
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class StudentWithLink:
    """Student plus the `student_teacher_id` of the link it was reached through.

    The link id is present only when the listing is scoped to a specific
    teacher (TEACHER role, or the admin `/teacher/{id}` filter); for the
    org-wide admin listing it stays `None`.
    """

    student: Student
    student_teacher_id: int | None = None


# ─────────────────────────────────────────────────────────────────────────────
#  Internal helpers (kept private to the service)
# ─────────────────────────────────────────────────────────────────────────────


async def _load_student(
    session: AsyncSession, student_id: int, org_id: int
) -> Student:
    result = await session.execute(
        select(Student).where(
            Student.id == student_id,
            Student.org_id == org_id,
        )
    )
    student = result.scalar_one_or_none()
    if student is None:
        raise NotFound("student not found")
    return student


async def _student_link_ids(session: AsyncSession, student_id: int) -> list[int]:
    """All StudentTeacher link ids for a student (used for cascade delete)."""
    result = await session.execute(
        select(StudentTeacher.id).where(StudentTeacher.student_id == student_id)
    )
    return [row[0] for row in result.all()]


async def _teacher_owns_student(
    session: AsyncSession, teacher_user_id: int, student_id: int
) -> bool:
    result = await session.execute(
        select(StudentTeacher.id).where(
            StudentTeacher.student_id == student_id,
            StudentTeacher.teacher_user_id == teacher_user_id,
        )
    )
    return result.first() is not None


async def _list_for_teacher(
    session: AsyncSession, org_id: int, teacher_user_id: int
) -> list[StudentWithLink]:
    """Students linked to one teacher, each carrying its link id."""
    result = await session.execute(
        select(Student, StudentTeacher.id.label("st_id"))
        .join(StudentTeacher, StudentTeacher.student_id == Student.id)
        .where(
            StudentTeacher.teacher_user_id == teacher_user_id,
            StudentTeacher.org_id == org_id,
        )
        .order_by(Student.last_name, Student.first_name)
    )
    return [
        StudentWithLink(student=student, student_teacher_id=st_id)
        for student, st_id in result.all()
    ]


# ─────────────────────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────────────────────


async def create_student(
    session: AsyncSession,
    user: User,
    *,
    first_name: str,
    last_name: str,
    phone: str | None,
    is_foreign: bool,
    teacher_user_id: int | None,
) -> Student:
    """Create a student and (optionally) link it to a teacher.

    A TEACHER always creates for themselves; an ADMIN may pass an explicit
    `teacher_user_id` (verified to be a TEACHER in the same org) or none.
    """
    existing = await session.execute(
        select(Student.id).where(
            Student.org_id == user.org_id,
            Student.first_name == first_name,
            Student.last_name == last_name,
        )
    )
    if existing.first():
        raise Conflict("Ученик с таким именем уже существует")

    if user.role == "TEACHER":
        assign_teacher_id: int | None = user.id
    else:  # ADMIN
        assign_teacher_id = teacher_user_id

    if assign_teacher_id is not None and user.role == "ADMIN":
        teacher_check = await session.execute(
            select(User).where(
                User.id == assign_teacher_id,
                User.org_id == user.org_id,
                User.role == "TEACHER",
            )
        )
        if teacher_check.scalar_one_or_none() is None:
            raise NotFound("teacher not found")

    student = Student(
        org_id=user.org_id,
        first_name=first_name,
        last_name=last_name,
        phone=phone,
        is_foreign=is_foreign,
        status="active",
    )
    session.add(student)
    await session.flush()

    if assign_teacher_id is not None:
        session.add(
            StudentTeacher(
                org_id=user.org_id,
                student_id=student.id,
                teacher_user_id=assign_teacher_id,
                is_primary=True,
                status="active",
            )
        )

    await session.commit()
    await session.refresh(student)
    return student


async def list_students(
    session: AsyncSession, user: User
) -> list[StudentWithLink]:
    """ADMIN sees every student in the org; TEACHER sees only their own."""
    if user.role == "ADMIN":
        result = await session.execute(
            select(Student)
            .where(Student.org_id == user.org_id)
            .order_by(Student.last_name, Student.first_name)
        )
        return [StudentWithLink(student=s) for s in result.scalars().all()]

    if user.role == "TEACHER":
        return await _list_for_teacher(session, user.org_id, user.id)

    raise Forbidden("forbidden")


async def list_students_by_teacher(
    session: AsyncSession, user: User, *, teacher_id: int
) -> list[StudentWithLink]:
    """Admin-only: students of an arbitrary teacher, with link ids."""
    if user.role != "ADMIN":
        raise Forbidden("admin only")
    return await _list_for_teacher(session, user.org_id, teacher_id)


async def update_student_status(
    session: AsyncSession, user: User, *, student_id: int, status: str
) -> Student:
    if status not in VALID_STATUSES:
        raise ValidationError(
            "invalid status",
            details={"allowed": sorted(VALID_STATUSES)},
        )
    student = await _load_student(session, student_id, user.org_id)
    student.status = status
    await session.commit()
    await session.refresh(student)
    return student


async def delete_student(
    session: AsyncSession, user: User, *, student_id: int
) -> None:
    """Delete a student and every row that references them.

    Cascades lessons → subscriptions → teacher links → student. A TEACHER
    may only delete a student they are linked to.
    """
    student = await _load_student(session, student_id, user.org_id)

    if user.role == "TEACHER" and not await _teacher_owns_student(
        session, user.id, student_id
    ):
        raise Forbidden("forbidden")

    st_ids = await _student_link_ids(session, student_id)
    if st_ids:
        await session.execute(
            sa_delete(Lesson).where(Lesson.student_teacher_id.in_(st_ids))
        )
    await session.execute(
        sa_delete(Subscription).where(Subscription.student_id == student_id)
    )
    await session.execute(
        sa_delete(StudentTeacher).where(StudentTeacher.student_id == student_id)
    )
    await session.delete(student)
    await session.commit()
