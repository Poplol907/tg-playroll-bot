"""Общие проверки прав доступа.

Централизованное место для проверок роли/принадлежности к организации.
Снижает дублирование в роутерах.
"""
from fastapi import HTTPException

from backend.app.models import User


def require_admin(user: User) -> None:
    """Только админ. Иначе 403."""
    if user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="admin only")


def require_admin_or_teacher(user: User) -> None:
    """Админ или педагог. PENDING/иные роли — 403."""
    if user.role not in ("ADMIN", "TEACHER"):
        raise HTTPException(status_code=403, detail="forbidden")


def require_teacher_self_or_admin(user: User, target_teacher_id: int) -> None:
    """Педагог может только себя; админ — кого угодно."""
    if user.role == "ADMIN":
        return
    if user.role == "TEACHER" and user.id == target_teacher_id:
        return
    raise HTTPException(status_code=403, detail="forbidden")
