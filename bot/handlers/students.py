import httpx
from telegram import Update
from telegram.ext import ContextTypes

from bot.handlers.admin import require_admin
from bot.services.api import create_student, get_students
from bot.ui.keyboards import build_students_menu


async def student_create_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return

    if len(context.args) < 2:
        await update.message.reply_text(
            "Использование:\n/student_create <Имя> <Фамилия> [телефон]"
        )
        return

    first_name = context.args[0]
    last_name = context.args[1]
    phone = context.args[2] if len(context.args) > 2 else None

    try:
        data = await create_student(
            update.effective_user.id,
            first_name,
            last_name,
            phone,
        )

    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав для этого действия.")
        elif code == 409:
            await update.message.reply_text("Ученик с таким именем уже существует.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")
        return

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return

    await update.message.reply_text(
        f"Ученик создан.\n"
        f"ID: {data['id']}\n"
        f"Имя: {data['first_name']} {data['last_name']}\n"
        f"Статус: {data['status']}"
    )


async def students_list_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return

    try:
        data = await get_students(update.effective_user.id)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав для этого действия.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")
        return

    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return

    if not data:
        await update.message.reply_text("Список учеников пуст.")
        return

    lines = []
    for s in data:
        phone = s["phone"] if s["phone"] else "—"
        lines.append(
            f'{s["id"]}. {s["first_name"]} {s["last_name"]} | {s["status"]} | тел: {phone}'
        )

    msg = "Ученики:\n" + "\n".join(lines)
    if len(msg) > 3500:
        msg = msg[:3500] + "\n... (обрезано)"

    await update.message.reply_text(msg, reply_markup=build_students_menu())


async def handle_student_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """Обрабатывает ввод данных ученика после нажатия 'Добавить ученика'.
    Возвращает True если состояние было активно и обработано."""
    if not context.user_data.get("awaiting_student_input"):
        return False

    context.user_data["awaiting_student_input"] = False
    parts = update.message.text.strip().split()

    if len(parts) < 2:
        await update.message.reply_text(
            "Неверный формат. Нужно минимум имя и фамилия.\n"
            "Пример: Иван Иванов +998901234567\n\n"
            "Попробуйте снова — нажмите «Добавить ученика».",
            reply_markup=build_students_menu(),
        )
        return True

    first_name = parts[0]
    last_name = parts[1]
    phone = parts[2] if len(parts) > 2 else None

    try:
        data = await create_student(
            update.effective_user.id,
            first_name,
            last_name,
            phone,
        )
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("У вас нет прав для этого действия.")
        elif code == 409:
            await update.message.reply_text(
                "Ученик с таким именем уже существует.",
                reply_markup=build_students_menu(),
            )
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")
        return True
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи с сервером.")
        return True

    await update.message.reply_text(
        f"Ученик добавлен.\n"
        f"ID: {data['id']}\n"
        f"Имя: {data['first_name']} {data['last_name']}\n"
        f"Телефон: {data.get('phone') or '—'}\n"
        f"Статус: {data['status']}",
        reply_markup=build_students_menu(),
    )
    return True
