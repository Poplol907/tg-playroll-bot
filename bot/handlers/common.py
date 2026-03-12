from telegram import Update
from telegram.ext import ContextTypes

from bot.ui.keyboards import (
    build_admin_menu,
    build_teacher_menu,
    build_root_menu,
)

import httpx
from bot.services.api import user_set_login


def build_help_text(role: str) -> str:
    common = (
        "Доступные команды:\n\n"
        "Общие:\n"
        "/help — показать это меню\n"
        "/whoami — показать ваш аккаунт\n"
        "/myid — показать Telegram ID\n"
        "/set_login <new_login> — изменить ваш логин\n"
    )

    teacher = (
        "\nПреподаватель:\n"
        "/teacher — меню преподавателя\n"
        "/calc — рассчитать и сохранить отчёт\n"
        "/last — показать последний отчёт\n"
        "/report <id> — показать отчёт по номеру\n"
    )

    admin = (
        "\nАдминистрирование:\n"
        "/admin_users — список пользователей\n"
        "/admin_bind <login> <telegram_id> — привязать Telegram ID\n"
        "/admin_create_user <login> <role> [teacher_name] — создать пользователя\n"
        "/admin_set_role <login> <role> — изменить роль пользователя\n"
        "/admin_set_login <old_login> <new_login> — изменить логин пользователя\n"
    )

    pending = (
        "\nВаш аккаунт ещё не активирован.\n"
        "Ожидайте, пока администратор назначит вам роль.\n"
    )

    if role == "ADMIN":
        return common + teacher + admin

    if role == "TEACHER":
        return common + teacher

    return common + pending


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)

    if user is None:
        user = await context.bot_data["create_pending_user"](telegram_id)

        await update.message.reply_text(
            f"Вы зарегистрированы в системе.\n\n"
            f"Логин: {user.login}\n"
            f"Роль: {user.role}\n"
            f"Telegram ID: {telegram_id}\n\n"
            f"Вы можете сразу сменить временный логин командой:\n"
            f"/set_login <новый_логин>\n\n"
            f"После этого ожидайте, пока администратор назначит вам роль.",
            reply_markup=build_root_menu(),
        )
        return

    await update.message.reply_text(
        f"Добро пожаловать, {user.login}. Роль: {user.role}\n\n"
        "Используйте кнопки ниже или команду /help.",
        reply_markup=build_root_menu(),
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text(
            "Вы не зарегистрированы в системе.\nНажмите /start для регистрации."
        )
        return

    await update.message.reply_text(
        build_help_text(user.role),
        reply_markup=build_root_menu(),
    )


async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)

    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return

    await update.message.reply_text(
        f"Логин: {user.login}\n"
        f"Роль: {user.role}\n"
        f"Telegram ID: {telegram_id}",
        reply_markup=build_root_menu(),
    )


async def myid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        f"Твой Telegram ID: {update.effective_user.id}",
        reply_markup=build_root_menu(),
    )

async def set_login_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text(
            "Вы не зарегистрированы в системе.\nНажмите /start"
        )
        return

    if len(context.args) != 1:
        await update.message.reply_text(
            "Использование:\n/set_login <new_login>"
        )
        return

    new_login = context.args[0]

    try:
        data = await user_set_login(update.effective_user.id, new_login)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 409:
            await update.message.reply_text("Этот логин уже занят.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")
        return

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return

    await update.message.reply_text(
        f'Ваш логин обновлён.\n'
        f'Новый логин: {data["login"]}\n'
        f'Роль: {data["role"]}'
    )


async def menu_button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text

    if text in {
        "Помощь",
        "Профиль",
        "Меню админа",
        "Меню преподавателя",
        "Назад",
        "Пользователи",
        "Привязать Telegram",
        "Назначить роль",
        "Изменить логин",
        "Рассчитать отчёт",
        "Последний отчёт",
        "Мои отчёты",
    }:
        context.user_data["awaiting_calc_text"] = False

    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if text == "Мои отчёты":
        await context.bot_data["last_report_cmd"](update, context)
        return

    if text == "Помощь":
        await help_cmd(update, context)
        return

    if text == "Профиль":
        await whoami(update, context)
        return

    if text == "Меню админа":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text(
                "У вас недостаточно прав.",
                reply_markup=build_root_menu(),
            )
            return

        await update.message.reply_text(
            "Меню админа",
            reply_markup=build_admin_menu(),
        )
        return

    if text == "Меню преподавателя":
        await update.message.reply_text(
            "Меню преподавателя",
            reply_markup=build_teacher_menu(),
        )
        return

    if text == "Назад":
        await update.message.reply_text(
            "Главное меню",
            reply_markup=build_root_menu(),
        )
        return

    if text == "Рассчитать отчёт":
        await context.bot_data["calc_cmd"](update, context)
        return

    if text == "Последний отчёт":
        await context.bot_data["last_report_cmd"](update, context)
        return

    if text == "Пользователи":
        await context.bot_data["admin_users_cmd"](update, context)
        return

    if text == "Привязать Telegram":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text(
                "У вас недостаточно прав.",
                reply_markup=build_root_menu(),
            )
            return

        await update.message.reply_text(
            "Использование:\n/admin_bind <login> <telegram_id>",
            reply_markup=build_admin_menu(),
        )
        return

    if text == "Назначить роль":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text(
                "У вас недостаточно прав.",
                reply_markup=build_root_menu(),
            )
            return

        await update.message.reply_text(
            "Использование:\n/admin_set_role <login> <role>",
            reply_markup=build_admin_menu(),
        )
        return

    if text == "Изменить логин":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text(
                "У вас недостаточно прав.",
                reply_markup=build_root_menu(),
            )
            return

        await update.message.reply_text(
            "Для себя: /set_login <new_login>\n"
            "Для другого пользователя: /admin_set_login <old_login> <new_login>",
            reply_markup=build_admin_menu(),
        )
        return