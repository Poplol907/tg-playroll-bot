import os
import httpx

API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")


async def get_admin_users(telegram_user_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/admin/users",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def admin_bind_user(admin_telegram_user_id: int, login: str, target_tid: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/admin/bind",
            params={"telegram_user_id": admin_telegram_user_id},
            json={"login": login, "telegram_user_id": target_tid},
        )
        r.raise_for_status()
        return r.json()


async def calc_save_text(telegram_user_id: int, text: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/calc/save-text",
            params={"telegram_user_id": telegram_user_id},
            json={"text": text},
        )
        r.raise_for_status()
        return r.json()


async def get_last_report(telegram_user_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/reports/last",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def get_report_by_id(telegram_user_id: int, report_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/reports/{report_id}",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def admin_create_user(admin_telegram_user_id: int, login: str, role: str, teacher_name: str | None = None):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/admin/create-user",
            params={"telegram_user_id": admin_telegram_user_id},
            json={
                "login": login,
                "role": role,
                "teacher_name": teacher_name,
            },
        )
        r.raise_for_status()
        return r.json()


async def admin_set_role(admin_telegram_user_id: int, login: str, role: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/admin/set-role",
            params={"telegram_user_id": admin_telegram_user_id},
            json={
                "login": login,
                "role": role,
            },
        )
        r.raise_for_status()
        return r.json()


async def user_set_login(telegram_user_id: int, new_login: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/users/set-login",
            params={"telegram_user_id": telegram_user_id},
            json={"new_login": new_login},
        )
        r.raise_for_status()
        return r.json()



async def admin_set_login(telegram_user_id: int, login: str, new_login: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/admin/set-login",
            params={"telegram_user_id": telegram_user_id},
            json={
                "login": login,
                "new_login": new_login,
            },
        )
        r.raise_for_status()
        return r.json()

async def create_student(
    telegram_user_id: int,
    first_name: str,
    last_name: str,
    phone: str | None = None,
):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/students/create",
            params={"telegram_user_id": telegram_user_id},
            json={
                "first_name": first_name,
                "last_name": last_name,
                "phone": phone,
            },
        )
        r.raise_for_status()
        return r.json()


async def get_students(telegram_user_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/students",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


# ── Инструменты ────────────────────────────────────────────────────────────

async def get_instruments(telegram_user_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/instruments",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def create_instrument(telegram_user_id: int, name: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/instruments",
            params={"telegram_user_id": telegram_user_id},
            json={"name": name},
        )
        r.raise_for_status()
        return r.json()


async def delete_instrument(telegram_user_id: int, instrument_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.delete(
            f"{API_URL}/instruments/{instrument_id}",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
# ── Отчёты v2 ──────────────────────────────────────────────────────────────

async def get_salary_report(telegram_user_id: int, teacher_id: int, month: str, report_type: str = "final"):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/reports/salary",
            params={
                "telegram_user_id": telegram_user_id,
                "teacher_id": teacher_id,
                "month": month,
                "report_type": report_type,
            },
        )
        r.raise_for_status()
        return r.json()


async def get_studio_report(telegram_user_id: int, month: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/reports/studio",
            params={"telegram_user_id": telegram_user_id, "month": month},
        )
        r.raise_for_status()
        return r.json()


async def get_teachers(telegram_user_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/teachers",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def get_teacher_rates(telegram_user_id: int, teacher_id: int):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.get(
            f"{API_URL}/rates/teacher/{teacher_id}",
            params={"telegram_user_id": telegram_user_id},
        )
        r.raise_for_status()
        return r.json()


async def set_teacher_rate(
    telegram_user_id: int,
    teacher_id: int,
    rate: int,
    effective_from: str,  # 'YYYY-MM-DD'
    instrument_id: int | None = None,
    note: str | None = None,
):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/rates/teacher/{teacher_id}",
            params={"telegram_user_id": telegram_user_id},
            json={
                "teacher_user_id": teacher_id,
                "rate_per_lesson": rate,
                "effective_from": effective_from,
                "instrument_id": instrument_id,
                "note": note,
            },
        )
        r.raise_for_status()
        return r.json()


# ── Пароль (для Flutter) ───────────────────────────────────────────────────

async def init_password(login: str, password: str):
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(
            f"{API_URL}/auth/init-password",
            json={"login": login, "password": password},
        )
        r.raise_for_status()
