from datetime import date, datetime, time, timezone

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    Date,
    Time,
    Text,
    ForeignKey,
    Boolean,
    UniqueConstraint,
    func,
)

from sqlalchemy.orm import Mapped, mapped_column

from backend.app.database import Base


class Org(Base):
    __tablename__ = "orgs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    slug: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=func.now(),
    )


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("org_id", "login", name="uq_users_org_login"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("orgs.id"),
        nullable=False,
    )

    login: Mapped[str] = mapped_column(String(64), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False)  # ADMIN / TEACHER / PENDING
    telegram_user_id: Mapped[int | None] = mapped_column(Integer, unique=True, nullable=True)
    teacher_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(256), nullable=True)


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    teacher_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    total_sum: Mapped[int] = mapped_column(Integer, nullable=False)

    raw_text: Mapped[str] = mapped_column(Text, nullable=False)



class Student(Base):
    __tablename__ = "students"

    __table_args__ = (
        UniqueConstraint(
            "org_id",
            "first_name",
            "last_name",
            "phone",
            name="uq_student_identity",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)

    org_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("orgs.id"),
        nullable=False,
        index=True,
    )

    first_name: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    last_name: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)

    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="ACTIVE",
    )

    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Признак иностранного ученика (уроки ведутся на английском, тариф выше)
    is_foreign: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=func.now(),
    )


class StudentTeacher(Base):
    __tablename__ = "student_teachers"

    __table_args__ = (
        UniqueConstraint(
            "org_id",
            "student_id",
            "teacher_user_id",
            name="uq_student_teacher",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)

    org_id: Mapped[int] = mapped_column(
        ForeignKey("orgs.id"),
        nullable=False,
        index=True,
    )

    student_id: Mapped[int] = mapped_column(
        ForeignKey("students.id"),
        nullable=False,
        index=True,
    )

    teacher_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    instrument_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("instruments.id"),
        nullable=True,
        index=True,
    )

    is_primary: Mapped[bool] = mapped_column(Boolean, default=True)

    status: Mapped[str] = mapped_column(String(16), nullable=False, default="ACTIVE")

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )

class Instrument(Base):
    __tablename__ = "instruments"
    __table_args__ = (
        UniqueConstraint("org_id", "name", name="uq_instruments_org_name"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("orgs.id"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(String(64), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        server_default=func.now(),
    )


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orgs.id"), nullable=False, index=True
    )
    student_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("students.id"), nullable=False, index=True
    )
    teacher_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )

    # '2026-04'
    month_year: Mapped[str] = mapped_column(String(7), nullable=False, index=True)

    lessons_count: Mapped[int] = mapped_column(Integer, nullable=False)

    paid_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    # active / frozen / cancelled
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="active")

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orgs.id"), nullable=False, index=True
    )
    student_teacher_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("student_teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subscription_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("subscriptions.id"), nullable=True, index=True
    )

    # regular / makeup
    lesson_type: Mapped[str] = mapped_column(
        String(16), nullable=False, default="regular", server_default="regular"
    )
    # для makeup-урока: id оригинального урока, который он отрабатывает
    makeup_for_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("lessons.id"), nullable=True, index=True
    )

    scheduled_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    scheduled_time: Mapped[time | None] = mapped_column(Time, nullable=True)

    # scheduled / attended / missed / cancelled
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="scheduled", index=True
    )

    # student / teacher (null если не отменён)
    cancelled_by: Mapped[str | None] = mapped_column(String(16), nullable=True)

    # none / scheduled / done / burned / transferred
    makeup_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="none"
    )
    makeup_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    payment_counted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now(), onupdate=func.now()
    )


class ReportV2(Base):
    __tablename__ = "reports_v2"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orgs.id"), nullable=False, index=True
    )
    teacher_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )

    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)

    # advance / final
    report_type: Mapped[str] = mapped_column(String(16), nullable=False)

    lessons_done: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    lessons_missed: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    lessons_debt: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    advance_amount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    final_amount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_amount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    generated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class TeacherRate(Base):
    """Ставка педагога за урок.

    Приоритет поиска ставки (от частного к общему):
      1. teacher + instrument + effective_from <= today  (самая точная)
      2. teacher + instrument IS NULL + effective_from <= today  (для всех инструментов)
    Берётся запись с максимальным effective_from <= дата урока.

    Это даёт админу полную гибкость:
      - разные ставки по инструментам
      - изменение ставки с нужной даты без потери истории
    """

    __tablename__ = "teacher_rates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orgs.id"), nullable=False, index=True
    )
    teacher_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )
    # null = ставка для всех инструментов этого педагога
    instrument_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("instruments.id"), nullable=True, index=True
    )
    # null = ставка для всех учеников; задан = персональная ставка для конкретного ученика
    student_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("students.id"), nullable=True, index=True
    )
    # True = ставка для иностранных учеников (is_foreign=True на студенте)
    is_foreign: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    rate_per_lesson: Mapped[int] = mapped_column(Integer, nullable=False)

    # с какой даты действует ставка
    effective_from: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    note: Mapped[str | None] = mapped_column(String(256), nullable=True)

    created_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class DeviceToken(Base):
    """FCM/APNs токены для push-уведомлений."""

    __tablename__ = "device_tokens"

    __table_args__ = (
        UniqueConstraint("user_id", "token", name="uq_device_token"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False)

    # ios / android
    platform: Mapped[str] = mapped_column(String(16), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now(), onupdate=func.now()
    )