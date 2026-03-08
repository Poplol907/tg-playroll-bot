from telegram import Update
from telegram.ext import ContextTypes


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

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
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)

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
