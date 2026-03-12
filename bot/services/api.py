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