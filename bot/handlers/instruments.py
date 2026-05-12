import httpx
from telegram import Update
from telegram.ext import ContextTypes

from bot.handlers.admin import require_admin
from bot.services.api import get_instruments, create_instrument
from bot.ui.keyboards import build_instruments_menu


async def instruments_list_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return

    try:
        data = await get_instruments(update.effective_user.id)
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.", reply_markup=build_instruments_menu())
        return

    if not data:
        await update.message.reply_text("Список инструментов пуст.", reply_markup=build_instruments_menu())
        return

    lines = [f'{i["id"]}. {i["name"]}' for i in data]
    await update.message.reply_text(
        "Инструменты:\n" + "\n".join(lines),
        reply_markup=build_instruments_menu(),
    )


async def handle_instrument_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    if not context.user_data.get("awaiting_instrument_name"):
        return False

    context.user_data["awaiting_instrument_name"] = False
    name = update.message.text.strip()

    if not name:
        await update.message.reply_text("Название не может быть пустым.", reply_markup=build_instruments_menu())
        return True

    try:
        data = await create_instrument(update.effective_user.id, name)
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 409:
            await update.message.reply_text(f'Инструмент «{name}» уже существует.', reply_markup=build_instruments_menu())
        elif code == 403:
            await update.message.reply_text("У вас нет прав.", reply_markup=build_instruments_menu())
        else:
            await update.message.reply_text(f"Ошибка: {code}", reply_markup=build_instruments_menu())
        return True
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.", reply_markup=build_instruments_menu())
        return True

    await update.message.reply_text(
        f'✓ Инструмент добавлен: {data["name"]}',
        reply_markup=build_instruments_menu(),
    )
    return True
