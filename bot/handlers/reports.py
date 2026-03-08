from telegram import Update
from telegram.ext import ContextTypes
import httpx

from bot.services.api import (
    calc_save_text,
    get_last_report,
    get_report_by_id,
)


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


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.user_data.get("awaiting_calc_text"):
        return

    context.user_data["awaiting_calc_text"] = False
    text = update.message.text
    telegram_id = update.effective_user.id

    try:
        data = await calc_save_text(telegram_id, text)

    except httpx.HTTPStatusError as e:
        code = e.response.status_code

        if code == 401:
            await update.message.reply_text("Вы не зарегистрированы в системе.")
        elif code == 403:
            await update.message.reply_text("Эта команда доступна только преподавателям.")
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