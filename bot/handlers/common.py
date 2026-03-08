from telegram import Update
from telegram.ext import ContextTypes

from bot.ui.keyboards import build_admin_menu, build_teacher_menu


def build_help_text(role: str) -> str:
    common = (
        "Доступные команды:\n\n"
        "Общие:\n"
        "/help — показать это меню\n"
        "/whoami — показать ваш аккаунт\n"
        "/myid — показать Telegram ID\n"
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
    )

    if role == "ADMIN":
        return common + teacher + admin

    if role == "TEACHER":
        return common + teacher

    return common


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text(
            "Вы не зарегистрированы в системе.\n"
            "Попросите админа привязать ваш Telegram ID к аккаунту."
        )
        return

    keyboard = build_admin_menu() if user.role == "ADMIN" else build_teacher_menu()

    await update.message.reply_text(
        f"Добро пожаловать, {user.login}. Роль: {user.role}\n\n"
        "Используйте кнопки ниже или команду /help.",
        reply_markup=keyboard,
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text(
            "Вы не зарегистрированы в системе.\n"
            "Попросите админа привязать ваш Telegram ID к аккаунту."
        )
        return

    keyboard = build_admin_menu() if user.role == "ADMIN" else build_teacher_menu()

    await update.message.reply_text(
        build_help_text(user.role),
        reply_markup=keyboard,
    )


async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)

    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return

    keyboard = build_admin_menu() if user.role == "ADMIN" else build_teacher_menu()

    await update.message.reply_text(
        f"Логин: {user.login}\n"
        f"Роль: {user.role}\n"
        f"Telegram ID: {telegram_id}",
        reply_markup=keyboard,
    )


async def myid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)
    keyboard = None
    if user is not None:
        keyboard = build_admin_menu() if user.role == "ADMIN" else build_teacher_menu()

    await update.message.reply_text(
        f"Твой Telegram ID: {update.effective_user.id}",
        reply_markup=keyboard,
    )


async def menu_button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text

    if text == "Помощь":
        await help_cmd(update, context)
        return

    if text == "Профиль":
        await whoami(update, context)
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
        await update.message.reply_text(
            "Использование:\n/admin_bind <login> <telegram_id>"
        )
        return

    if text == "Меню преподавателя":
        await context.bot_data["teacher_home_cmd"](update, context)
        return