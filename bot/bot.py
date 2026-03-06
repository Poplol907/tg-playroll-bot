import logging
logging.basicConfig(level=logging.INFO)
logging.getLogger("httpx").setLevel(logging.WARNING)  # не логируем каждый запрос

import os
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)
from sqlalchemy import select

# --- make project root importable (so "app.*" resolves to your code, not some random package) ---
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# --- load .env from project root ---
load_dotenv(ROOT / ".env")

from app.database import AsyncSessionLocal  # noqa: E402
from app.models import User  # noqa: E402

TOKEN = os.getenv("BOT_TOKEN")
API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")

async def require_admin(update: Update):
    user = await get_user_by_telegram_id(update.effective_user.id)
    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return None
    if user.role != "ADMIN":
        await update.message.reply_text("У вас нет прав администратора.")
        return None
    return user

async def get_user_by_telegram_id(telegram_id: int):
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.telegram_user_id == telegram_id)
        )
        return result.scalar_one_or_none()

def fmt_sum(n: int) -> str:
    return f"{n:,}".replace(",", ".") + " сум"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await get_user_by_telegram_id(update.effective_user.id)
    if user is None:
        await update.message.reply_text(
            "Вы не зарегистрированы в системе.\n"
            "Попросите админа привязать ваш Telegram ID к аккаунту."
        )
        return

    await update.message.reply_text(
        f"Добро пожаловать, {user.login}. Роль: {user.role}\n\n"
        "Команды:\n"
        "/whoami — показать ваш аккаунт\n"
        "/myid — показать Telegram ID\n"
        "/calc — посчитать список (для преподавателя)"
    )


async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await get_user_by_telegram_id(telegram_id)

    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return

    await update.message.reply_text(
        f"Логин: {user.login}\n"
        f"Роль: {user.role}\n"
        f"Telegram ID: {telegram_id}"
    )


async def myid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(f"Твой Telegram ID: {update.effective_user.id}")


async def calc_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await get_user_by_telegram_id(update.effective_user.id)
    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return

    if user.role != "TEACHER":
        await update.message.reply_text("Команда /calc доступна только преподавателям.")
        return

    context.user_data["awaiting_calc_text"] = True
    await update.message.reply_text(
        "Пришли список ТЕКСТОМ, формат:\n"
        "Имя Фамилия Уроки Цена\n\n"
        "Пример:\n"
        "Ivan Ivanov 5 20\n"
        "Petr Petrov 3 30"
    )


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.user_data.get("awaiting_calc_text"):
        return

    context.user_data["awaiting_calc_text"] = False
    text = update.message.text

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            telegram_id = update.effective_user.id
            r = await client.post(
                f"{API_URL}/calc/save-text",
                params={"telegram_user_id": telegram_id},
                json={"text": text},
            )
            r.raise_for_status()
            data = r.json()

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером расчёта. Попробуйте позже.")
        return
    report_id = data.get("report_id")
    lines = data.get("lines", [])
    total_sum = data.get("sum", 0)

    if not lines:
        await update.message.reply_text(
            "Не получилось распарсить ни одной строки.\n"
            "Проверь формат: Имя Фамилия Уроки Цена"
        )
        return

    out_lines = []
    for row in lines:
        total_formatted = fmt_sum(row["total"])
        out_lines.append(
            f'{row["first"]} {row["last"]} = {total_formatted}'
        )

    sum_formatted = fmt_sum(total_sum)

    msg = (
            f"Отчёт #{report_id}\n\n"
            + "Расчёт:\n"
            + "\n".join(out_lines)
            + f"\n\nИтого: {sum_formatted}"
    )

    await update.message.reply_text(msg)

async def last(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.get(
                f"{API_URL}/reports/last",
                params={"telegram_user_id": telegram_id},
            )
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPError:
        await update.message.reply_text("Не смог получить последний отчёт.")
        return

    total = fmt_sum(data["total_sum"])
    await update.message.reply_text(
        f'Последний отчёт #{data["report_id"]}\n'
        f'Сумма: {total}\n'
        f'Дата: {data["created_at"]}'
    )


async def report_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.args:
        await update.message.reply_text("Использование: /report <id>")
        return

    try:
        report_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("ID должен быть числом.")
        return

    telegram_id = update.effective_user.id

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.get(
                f"{API_URL}/reports/{report_id}",
                params={"telegram_user_id": telegram_id},
            )
            r.raise_for_status()
            data = r.json()

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 404:
            await update.message.reply_text("Такого отчёта не существует.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав доступа к этому отчёту.")
        elif code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")

        return

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return

    total = fmt_sum(data["total_sum"])

    msg = (
        f'Отчёт #{data["report_id"]}\n'
        f'Дата: {data["created_at"]}\n'
        f'Сумма: {total}\n\n'
        f'Исходный текст:\n{data["raw_text"]}'
    )

    await update.message.reply_text(msg)

async def admin_bind_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update)
    if admin is None:
        return

    if len(context.args) != 2:
        await update.message.reply_text("Использование: /admin_bind <login> <telegram_id>")
        return

    login = context.args[0]
    try:
        target_tid = int(context.args[1])
    except ValueError:
        await update.message.reply_text("telegram_id должен быть числом.")
        return

    telegram_id = update.effective_user.id

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.post(
                f"{API_URL}/admin/bind",
                params={"telegram_user_id": telegram_id},
                json={"login": login, "telegram_user_id": target_tid},
            )
            r.raise_for_status()
            data = r.json()

    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 404:
            await update.message.reply_text("Пользователь с таким логином не найден.")
        elif code == 409:
            await update.message.reply_text("Этот Telegram ID уже привязан к другому аккаунту.")
        elif code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав администратора.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")
        return

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return

    await update.message.reply_text(
        f'Готово. {data["login"]} привязан к Telegram ID {data["telegram_user_id"]}.'
    )

async def admin_users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update)
    if admin is None:
        return

    telegram_id = update.effective_user.id

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.get(
                f"{API_URL}/admin/users",
                params={"telegram_user_id": telegram_id},
            )
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPError:
        await update.message.reply_text("Не смог получить список пользователей.")
        return

    if not data:
        await update.message.reply_text("Пользователей нет.")
        return

    lines = []
    for u in data:
        tid = u.get("telegram_user_id")
        tid_s = str(tid) if tid is not None else "—"
        tname = u.get("teacher_name")
        tname = "" if (tname is None or tname == "null") else tname
        lines.append(f'{u["id"]}. {u["login"]} ({u["role"]}) {tname} | tg: {tid_s}')

    msg = "Пользователи:\n" + "\n".join(lines)
    if len(msg) > 3500:
        msg = msg[:3500] + "\n... (обрезано)"
    await update.message.reply_text(msg)


def main():
    if not TOKEN or ":" not in TOKEN:
        raise RuntimeError("BOT_TOKEN не найден или выглядит неправильно. Проверь .env в корне проекта.")

    app = ApplicationBuilder().token(TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("whoami", whoami))
    app.add_handler(CommandHandler("myid", myid))
    app.add_handler(CommandHandler("calc", calc_cmd))
    app.add_handler(CommandHandler("last", last))
    app.add_handler(CommandHandler("report", report_cmd))
    app.add_handler(CommandHandler("admin_bind", admin_bind_cmd))
    app.add_handler(CommandHandler("admin_users", admin_users_cmd))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    app.run_polling()


if __name__ == "__main__":
    main()