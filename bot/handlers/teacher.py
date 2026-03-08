from telegram import Update
from telegram.ext import ContextTypes


async def require_teacher(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return None

    if user.role != "TEACHER" and user.role != "ADMIN":
        await update.message.reply_text("Эта команда доступна только преподавателям.")
        return None

    return user


async def teacher_home_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    teacher = await require_teacher(update, context)
    if teacher is None:
        return

    await update.message.reply_text(
        f"Меню преподавателя\n\n"
        f"Пользователь: {teacher.login}\n"
        f"Роль: {teacher.role}\n\n"
        "Скоро здесь появятся:\n"
        "• расписание\n"
        "• мои ученики\n"
        "• мои группы"
    )