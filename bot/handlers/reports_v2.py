from datetime import date
import httpx
from telegram import Update
from telegram.ext import ContextTypes

from bot.handlers.admin import require_admin
from bot.services.api import get_salary_report, get_studio_report, get_teachers
from bot.ui.keyboards import build_reports_admin_menu, build_admin_menu


def fmt_sum(n: int) -> str:
    return f"{n:,}".replace(",", " ") + " сум"


async def handle_reports_admin_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """Обрабатывает ввод месяца для отчётов. Возвращает True если состояние активно."""

    if context.user_data.get("awaiting_studio_month"):
        context.user_data["awaiting_studio_month"] = False
        month = update.message.text.strip()
        await _send_studio_report(update, context, month)
        return True

    if context.user_data.get("awaiting_salary_month"):
        context.user_data["awaiting_salary_month"] = False
        month = update.message.text.strip()
        teacher_id = context.user_data.pop("salary_teacher_id", None)
        report_type = context.user_data.pop("salary_report_type", "final")
        if teacher_id is None:
            await update.message.reply_text("Ошибка: педагог не выбран.")
            return True
        await _send_salary_report(update, context, teacher_id, month, report_type)
        return True

    if context.user_data.get("awaiting_salary_teacher"):
        context.user_data["awaiting_salary_teacher"] = False
        # ожидаем ID педагога
        try:
            teacher_id = int(update.message.text.strip())
        except ValueError:
            await update.message.reply_text(
                "Нужно ввести числовой ID педагога.\nПопробуйте снова — нажмите «Зарплата педагога».",
                reply_markup=build_reports_admin_menu(),
            )
            return True

        context.user_data["salary_teacher_id"] = teacher_id
        context.user_data["awaiting_salary_month"] = True
        current_month = date.today().strftime("%Y-%m")
        await update.message.reply_text(
            f"Введите месяц в формате ГГГГ-ММ\nПример: {current_month}",
        )
        return True

    return False


async def _send_salary_report(update, context, teacher_id, month, report_type):
    try:
        data = await get_salary_report(
            update.effective_user.id, teacher_id, month, report_type
        )
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 404:
            await update.message.reply_text("Педагог не найден.", reply_markup=build_reports_admin_menu())
        elif code == 422:
            await update.message.reply_text("Неверный формат месяца. Используйте ГГГГ-ММ.", reply_markup=build_reports_admin_menu())
        else:
            await update.message.reply_text(f"Ошибка: {code}", reply_markup=build_reports_admin_menu())
        return
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи.", reply_markup=build_reports_admin_menu())
        return

    name = data.get("teacher_name") or f'ID {data["teacher_id"]}'
    rtype = "Аванс" if data["report_type"] == "advance" else "Финал"

    msg = (
        f"📊 Зарплата: {name}\n"
        f"Период: {data['period_start']} — {data['period_end']} ({rtype})\n\n"
        f"✅ Проведено уроков: {data['lessons_done']}\n"
        f"❌ Пропуски учеников: {data['lessons_missed']}\n"
        f"⚠️ Долги педагога: {data['lessons_debt']}\n"
        f"🔄 Отработок закрыто: {data['lessons_cancelled_makeup']}\n\n"
        f"💰 Итого: {fmt_sum(data['total_amount'])}"
    )
    await update.message.reply_text(msg, reply_markup=build_reports_admin_menu())


async def _send_studio_report(update, context, month):
    try:
        data = await get_studio_report(update.effective_user.id, month)
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 422:
            await update.message.reply_text("Неверный формат месяца. Используйте ГГГГ-ММ.", reply_markup=build_reports_admin_menu())
        elif code == 403:
            await update.message.reply_text("Только для администратора.", reply_markup=build_reports_admin_menu())
        else:
            await update.message.reply_text(f"Ошибка: {code}", reply_markup=build_reports_admin_menu())
        return
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи.", reply_markup=build_reports_admin_menu())
        return

    total_salary = sum(t["total_amount"] for t in data["teachers"])

    lines = []
    for t in data["teachers"]:
        name = t.get("teacher_name") or f'ID {t["teacher_id"]}'
        lines.append(f'  {name}: {fmt_sum(t["total_amount"])} ({t["lessons_done"]} ур.)')

    msg = (
        f"🏢 Статистика студии — {data['month']}\n\n"
        f"✅ Проведено: {data['total_lessons_done']}\n"
        f"📅 Запланировано: {data['total_lessons_scheduled']}\n"
        f"❌ Пропуски: {data['total_lessons_missed']}\n"
        f"⚠️ Отменено: {data['total_lessons_cancelled']}\n"
        f"👥 Активных учеников: {data['active_students']}\n"
        f"👨‍🏫 Активных педагогов: {data['active_teachers']}\n\n"
        f"💰 Фонд зарплат: {fmt_sum(total_salary)}\n"
    )
    if lines:
        msg += "\nПо педагогам:\n" + "\n".join(lines)

    await update.message.reply_text(msg, reply_markup=build_reports_admin_menu())


async def studio_report_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return
    context.user_data["awaiting_studio_month"] = True
    current_month = date.today().strftime("%Y-%m")
    await update.message.reply_text(
        f"Введите месяц в формате ГГГГ-ММ\nПример: {current_month}",
    )


async def salary_report_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    admin = await require_admin(update, context)
    if admin is None:
        return

    # показываем список педагогов для выбора
    try:
        teachers = await get_teachers(update.effective_user.id)
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка загрузки педагогов.")
        return

    if not teachers:
        await update.message.reply_text("Педагоги не найдены.")
        return

    lines = [f'{t["id"]}. {t.get("teacher_name") or t["login"]}' for t in teachers]
    context.user_data["awaiting_salary_teacher"] = True
    context.user_data["salary_report_type"] = "final"

    await update.message.reply_text(
        "Педагоги:\n" + "\n".join(lines) + "\n\nВведите ID педагога:",
    )
