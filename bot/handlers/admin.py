from bot.services.api import get_admin_users, admin_bind_user
from telegram import Update
from telegram.ext import ContextTypes
import httpx


async def require_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return None

    if user.role != "ADMIN":
        await update.message.reply_text("У вас нет прав администратора.")
        return None

    return user


async def admin_users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return

    telegram_id = update.effective_user.id

    try:
        data = await get_admin_users(telegram_id)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав администратора.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")

        return

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


async def admin_bind_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
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
        data = await admin_bind_user(telegram_id, login, target_tid)

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