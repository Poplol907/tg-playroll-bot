from datetime import date
import httpx
from telegram import Update
from telegram.ext import ContextTypes

from bot.handlers.admin import require_admin
from bot.services.api import set_teacher_rate
from bot.ui.keyboards import build_teachers_menu


async def set_rate_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда: /set_rate <teacher_id> <rate> [YYYY-MM-DD]
    Пример:   /set_rate 3 25000
              /set_rate 3 25000 2026-05-01
    """
    admin = await require_admin(update, context)
    if admin is None:
        return

    if len(context.args) < 2:
        await update.message.reply_text(
            "Использование:\n/set_rate <id_педагога> <ставка> [ГГГГ-ММ-ДД]\n\n"
            "Пример:\n/set_rate 3 25000\n/set_rate 3 25000 2026-05-01"
        )
        return

    try:
        teacher_id = int(context.args[0])
        rate = int(context.args[1])
    except ValueError:
        await update.message.reply_text("ID педагога и ставка должны быть числами.")
        return

    if rate <= 0:
        await update.message.reply_text("Ставка должна быть больше нуля.")
        return

    effective_from = date.today().isoformat()
    if len(context.args) >= 3:
        try:
            date.fromisoformat(context.args[2])
            effective_from = context.args[2]
        except ValueError:
            await update.message.reply_text("Неверный формат даты. Используйте ГГГГ-ММ-ДД.")
            return

    try:
        data = await set_teacher_rate(
            update.effective_user.id,
            teacher_id,
            rate,
            effective_from,
        )
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 404:
            await update.message.reply_text("Педагог не найден.")
        elif code == 403:
            await update.message.reply_text("Только для администратора.")
        else:
            await update.message.reply_text(f"Ошибка: {code}")
        return
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи.")
        return

    fmt_rate = f"{data['rate_per_lesson']:,}".replace(",", " ")
    await update.message.reply_text(
        f"✓ Ставка установлена\n"
        f"Педагог ID: {teacher_id}\n"
        f"Ставка: {fmt_rate} сум/урок\n"
        f"С: {data['effective_from']}",
        reply_markup=build_teachers_menu(),
    )
