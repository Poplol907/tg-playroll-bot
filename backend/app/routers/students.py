from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.auth import get_current_user
from backend.app.database import get_session
from backend.app.models import User, Student, StudentTeacher, Lesson, Subscription
from backend.app.schemas.students import StudentCreateIn, StudentOut, StudentStatusIn
from backend.app.services.permissions import require_admin_or_teacher

router = APIRouter(prefix="/students", tags=["students"])


@router.post("/create", response_model=StudentOut)
async def student_create(
    payload: StudentCreateIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    existing = await session.execute(
        select(Student.id).where(
            Student.org_id == current_user.org_id,
            Student.first_name == payload.first_name,
            Student.last_name == payload.last_name,
        )
    )
    if existing.first():
        raise HTTPException(status_code=409, detail="Ученик с таким именем уже существует")

    # Determine which teacher this student belongs to
    if current_user.role == "TEACHER":
        assign_teacher_id = current_user.id
    else:
        # ADMIN: use provided teacher_user_id if given, otherwise no link
        assign_teacher_id = payload.teacher_user_id

    # If admin specified a teacher, verify that teacher belongs to same org
    if assign_teacher_id and current_user.role == "ADMIN":
        teacher_check = await session.execute(
            select(User).where(
                User.id == assign_teacher_id,
                User.org_id == current_user.org_id,
                User.role == "TEACHER",
            )
        )
        if teacher_check.scalar_one_or_none() is None:
            raise HTTPException(status_code=404, detail="teacher not found")

    student = Student(
        org_id=current_user.org_id,
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone=payload.phone,
        is_foreign=payload.is_foreign,
        status="active",
    )
    session.add(student)
    await session.flush()

    if assign_teacher_id:
        rel = StudentTeacher(
            org_id=current_user.org_id,
            student_id=student.id,
            teacher_user_id=assign_teacher_id,
            is_primary=True,
            status="active",
        )
        session.add(rel)

    await session.commit()
    await session.refresh(student)
    return StudentOut.model_validate(student)


@router.get("", response_model=list[StudentOut])
async def students_list(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.role == "ADMIN":
        result = await session.execute(
            select(Student)
            .where(Student.org_id == current_user.org_id)
            .order_by(Student.last_name, Student.first_name)
        )
        students = result.scalars().all()
        return [StudentOut.model_validate(s) for s in students]

    elif current_user.role == "TEACHER":
        # Join StudentTeacher so we can include student_teacher_id in response
        result = await session.execute(
            select(Student, StudentTeacher.id.label("st_id"))
            .join(StudentTeacher, StudentTeacher.student_id == Student.id)
            .where(
                StudentTeacher.teacher_user_id == current_user.id,
                StudentTeacher.org_id == current_user.org_id,
            )
            .order_by(Student.last_name, Student.first_name)
        )
        rows = result.all()
        out = []
        for student, st_id in rows:
            data = StudentOut.model_validate(student)
            data.student_teacher_id = st_id
            out.append(data)
        return out

    else:
        raise HTTPException(status_code=403, detail="forbidden")


@router.patch("/{student_id}/status", response_model=StudentOut)
async def update_student_status(
    student_id: int,
    payload: StudentStatusIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    require_admin_or_teacher(current_user)

    if payload.status not in ("active", "inactive"):
        raise HTTPException(status_code=422, detail="invalid status")

    result = await session.execute(
        select(Student).where(
            Student.id == student_id,
            Student.org_id == current_user.org_id,
        )
    )
    student = result.scalar_one_or_none()
    if student is None:
        raise HTTPException(status_code=404, detail="student not found")

    student.status = payload.status
    await session.commit()
    await session.refresh(student)
    return StudentOut.model_validate(student)


@router.get("/teacher/{teacher_id}", response_model=list[StudentOut])
async def students_by_teacher(
    teacher_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="admin only")

    result = await session.execute(
        select(Student, StudentTeacher.id.label("st_id"))
        .join(StudentTeacher, StudentTeacher.student_id == Student.id)
        .where(
            StudentTeacher.teacher_user_id == teacher_id,
            StudentTeacher.org_id == current_user.org_id,
        )
        .order_by(Student.last_name, Student.first_name)
    )
    rows = result.all()
    out = []
    for student, st_id in rows:
        data = StudentOut.model_validate(student)
        data.student_teacher_id = st_id
        out.append(data)
    return out


@router.delete("/{student_id}", status_code=204)
async def delete_student(
    student_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Удаляет ученика и все связанные записи (уроки, подписки, связи с педагогами)."""
    require_admin_or_teacher(current_user)

    student_res = await session.execute(
        select(Student).where(
            Student.id == student_id,
            Student.org_id == current_user.org_id,
        )
    )
    student = student_res.scalar_one_or_none()
    if student is None:
        raise HTTPException(status_code=404, detail="student not found")

    # Педагог может удалить только своего ученика
    if current_user.role == "TEACHER":
        link_res = await session.execute(
            select(StudentTeacher.id).where(
                StudentTeacher.student_id == student_id,
                StudentTeacher.teacher_user_id == current_user.id,
            )
        )
        if link_res.first() is None:
            raise HTTPException(status_code=403, detail="forbidden")

    # Собираем id всех StudentTeacher-связей ученика
    st_res = await session.execute(
        select(StudentTeacher.id).where(StudentTeacher.student_id == student_id)
    )
    st_ids = [row[0] for row in st_res.all()]

    # Каскадно удаляем: уроки → подписки → связи → ученик
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
    return Response(status_code=204)
