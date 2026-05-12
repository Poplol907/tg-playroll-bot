from telegram import Update
from telegram.ext import ContextTypes
import httpx

from bot.services.api import (
    calc_save_text,
    get_last_report,
    get_report_by_id,
)
from bot.handlers.students import handle_student_text
from bot.handlers.instruments import handle_instrument_text
from bot.handlers.reports_v2 import handle_reports_admin_text
from bot.services.api import init_password
from bot.ui.keyboards import build_settings_menu


def fmt_sum(n: int) -> str:
    return f"{n:,}".replace(",", ".") + " сум"


async def calc_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)
    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return

    if user.role not in ["TEACHER", "ADMIN"]:
        await update.message.reply_text("Команда /calc доступна только преподавателям и администраторам.")
        return

    context.user_data["awaiting_calc_text"] = True
    await update.message.reply_text(
        "Пришли список ТЕКСТОМ, формат:\n"
        "Имя Фамилия Уроки Цена\n\n"
        "Пример:\n"
        "Ivan Ivanov 5 20\n"
        "Petr Petrov 3 30"
    )

def looks_like_calc_input(text: str) -> bool:
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue

        parts = raw.split()
        if len(parts) != 4:
            continue

        _, _, lessons_s, price_s = parts

        try:
            int(lessons_s)
            int(price_s)
            return True
        except ValueError:
            continue

    return False

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if await handle_student_text(update, context):
        return
    if await handle_instrument_text(update, context):
        return
    if await handle_reports_admin_text(update, context):
        return
    if await _handle_password_text(update, context):
        return

    if not context.user_data.get("awaiting_calc_text"):
        return

    text = update.message.text

    if not looks_like_calc_input(text):
        await update.message.reply_text(
            "Неверный формат отчёта.\n\n"
            "Ожидается текст вида:\n"
            "Имя Фамилия Уроки Цена\n\n"
            "Пример:\n"
            "Ivan Ivanov 5 20\n"
            "Petr Petrov 3 30\n\n"
            "Если передумали, нажмите «Назад»."
        )
        return

    context.user_data["awaiting_calc_text"] = False
    telegram_id = update.effective_user.id

    try:
        data = await calc_save_text(telegram_id, text)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 400:
            await update.message.reply_text(
                "Не удалось распознать ни одной корректной строки отчёта.\n"
                "Проверь формат: Имя Фамилия Уроки Цена"
            )
        elif code == 403:
            await update.message.reply_text("Эта команда доступна только преподавателям и администраторам.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")

        return

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
            f'{row["first"]} {row["last"]}: '
            f'{row["lessons"]} * {row["price"]} = {total_formatted}'
        )

    sum_formatted = fmt_sum(total_sum)

    msg = (
        f"Отчёт #{report_id}\n\n"
        + "Расчёт:\n"
        + "\n".join(out_lines)
        + f"\n\nИтого: {sum_formatted}"
    )

    await update.message.reply_text(msg)


async def _handle_password_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    if not context.user_data.get("awaiting_password_input"):
        return False
    context.user_data["awaiting_password_input"] = False
    parts = update.message.text.strip().split(maxsplit=1)
    if len(parts) != 2:
        await update.message.reply_text(
            "Неверный формат. Нужно: <login> <пароль>",
            reply_markup=build_settings_menu(),
        )
        return True
    login, password = parts
    try:
        await init_password(login, password)
        await update.message.reply_text(
            f"✓ Пароль для «{login}» установлен.\n"
            f"Теперь можно войти в приложение.",
            reply_markup=build_settings_menu(),
        )
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 404:
            await update.message.reply_text(f"Пользователь «{login}» не найден.", reply_markup=build_settings_menu())
        elif code == 409:
            await update.message.reply_text(
                f"У «{login}» уже есть пароль.\nИспользуйте /admin_set_password для смены.",
                reply_markup=build_settings_menu(),
            )
        elif code == 403:
            await update.message.reply_text("Аккаунт не активирован.", reply_markup=build_settings_menu())
        else:
            await update.message.reply_text(f"Ошибка: {code}", reply_markup=build_settings_menu())
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи.", reply_markup=build_settings_menu())
    return True


async def last_report_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id

    try:
        data = await get_last_report(telegram_id)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("Эта команда доступна только преподавателям.")
        elif code == 404:
            await update.message.reply_text("У вас пока нет сохранённых отчётов.")
        else:
            await update.message.reply_text(f"Ошибка сервера: {code}")

        return

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
        data = await get_report_by_id(telegram_id, report_id)

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