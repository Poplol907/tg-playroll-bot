import httpx
from telegram import Update
from telegram.ext import ContextTypes

from bot.ui.keyboards import (
    build_admin_menu,
    build_teacher_menu,
    build_root_menu,
    build_students_menu,
    build_instruments_menu,
    build_reports_admin_menu,
    build_settings_menu,
    build_teachers_menu,
)
from bot.services.api import (
    user_set_login, get_students, get_instruments,
    get_teachers, init_password, get_teacher_rates, set_teacher_rate,
)


def build_help_text(role: str) -> str:
    common = (
        "Доступные команды:\n\n"
        "/help — показать это меню\n"
        "/whoami — показать ваш аккаунт\n"
        "/myid — показать Telegram ID\n"
        "/set_login <new_login> — изменить ваш логин\n"
    )
    teacher = (
        "\nПреподаватель:\n"
        "/calc — рассчитать отчёт\n"
        "/last — последний отчёт\n"
        "/report <id> — отчёт по ID\n"
    )
    admin = (
        "\nАдминистрирование:\n"
        "/admin_users — список пользователей\n"
        "/admin_bind <login> <tg_id> — привязать Telegram\n"
        "/admin_create_user <login> <role> [name] — создать пользователя\n"
        "/admin_set_role <login> <role> — изменить роль\n"
        "/admin_set_login <old> <new> — изменить логин\n"
        "/student_create <Имя> <Фамилия> [тел] — добавить ученика\n"
        "/students — список учеников\n"
    )
    if role == "ADMIN":
        return common + teacher + admin
    if role == "TEACHER":
        return common + teacher
    return common + "\nВаш аккаунт ещё не активирован."


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)

    if user is None:
        user = await context.bot_data["create_pending_user"](telegram_id)
        await update.message.reply_text(
            f"Вы зарегистрированы.\n\n"
            f"Логин: {user.login}\nРоль: {user.role}\nTelegram ID: {telegram_id}\n\n"
            f"Смените временный логин: /set_login <новый_логин>\n"
            f"Ожидайте активации администратором.",
            reply_markup=build_root_menu(),
        )
        return

    await update.message.reply_text(
        f"Добро пожаловать, {user.login}. Роль: {user.role}",
        reply_markup=build_root_menu(),
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)
    if user is None:
        await update.message.reply_text("Вы не зарегистрированы. Нажмите /start")
        return
    await update.message.reply_text(build_help_text(user.role), reply_markup=build_root_menu())


async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE):
    telegram_id = update.effective_user.id
    user = await context.bot_data["get_user_by_telegram_id"](telegram_id)
    if user is None:
        await update.message.reply_text("Вы не зарегистрированы.")
        return
    await update.message.reply_text(
        f"Логин: {user.login}\nРоль: {user.role}\nTelegram ID: {telegram_id}",
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
        await update.message.reply_text("Вы не зарегистрированы. /start")
        return
    if len(context.args) != 1:
        await update.message.reply_text("Использование: /set_login <new_login>")
        return
    try:
        data = await user_set_login(update.effective_user.id, context.args[0])
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 409:
            await update.message.reply_text("Этот логин уже занят.")
        else:
            await update.message.reply_text(f"Ошибка: {code}")
        return
    except httpx.HTTPError:
        await update.message.reply_text("Ошибка связи.")
        return
    await update.message.reply_text(f"Логин обновлён: {data['login']}")


# ─── Главный обработчик кнопок ────────────────────────────────────────────────

_RESET_STATES = {
    "Помощь", "Профиль", "Меню админа", "Меню преподавателя", "Назад",
    "Назад в меню админа",
    "Пользователи", "Ученики", "Педагоги", "Инструменты", "Отчёты", "Настройки",
    "Список учеников", "Список инструментов", "Список педагогов", "Ставки педагогов",
    "Зарплата педагога", "Статистика студии",
    "Привязать Telegram", "Назначить роль", "Изменить логин",
    "Рассчитать отчёт", "Последний отчёт", "Мои отчёты",
    "Список пользователей",
}


def _reset_states(context: ContextTypes.DEFAULT_TYPE):
    for key in (
        "awaiting_calc_text",
        "awaiting_student_input",
        "awaiting_instrument_name",
        "awaiting_studio_month",
        "awaiting_salary_month",
        "awaiting_salary_teacher",
        "awaiting_password_input",
    ):
        context.user_data[key] = False


async def menu_button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    user = await context.bot_data["get_user_by_telegram_id"](update.effective_user.id)

    if text in _RESET_STATES:
        _reset_states(context)

    # ── Навигация ──────────────────────────────────────────────────────────
    if text == "Меню админа":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Меню админа", reply_markup=build_admin_menu())
        return

    if text == "Меню преподавателя":
        await update.message.reply_text("Меню преподавателя", reply_markup=build_teacher_menu())
        return

    if text in ("Назад", "Назад в меню админа"):
        if text == "Назад":
            await update.message.reply_text("Главное меню", reply_markup=build_root_menu())
        else:
            await update.message.reply_text("Меню админа", reply_markup=build_admin_menu())
        return

    if text == "Помощь":
        await help_cmd(update, context)
        return

    if text == "Профиль":
        await whoami(update, context)
        return

    # ── Ученики ────────────────────────────────────────────────────────────
    if text == "Ученики":
        if user is None or user.role not in ("ADMIN", "TEACHER"):
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Управление учениками", reply_markup=build_students_menu())
        return

    if text == "Список учеников":
        if user is None or user.role not in ("ADMIN", "TEACHER"):
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        try:
            data = await get_students(user.telegram_user_id)
        except httpx.HTTPError:
            await update.message.reply_text("Ошибка связи.", reply_markup=build_students_menu())
            return
        if not data:
            await update.message.reply_text("Список учеников пуст.", reply_markup=build_students_menu())
            return
        lines = [f'{s["id"]}. {s["first_name"]} {s["last_name"]} | {s["status"]}' + (f' | {s["phone"]}' if s["phone"] else "") for s in data]
        msg = "Ученики:\n" + "\n".join(lines)
        if len(msg) > 3500:
            msg = msg[:3500] + "\n..."
        await update.message.reply_text(msg, reply_markup=build_students_menu())
        return

    if text == "Добавить ученика":
        if user is None or user.role not in ("ADMIN", "TEACHER"):
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        context.user_data["awaiting_student_input"] = True
        await update.message.reply_text("Введите: <Имя> <Фамилия> [телефон]\nПример: Иван Иванов +998901234567")
        return

    # ── Педагоги ───────────────────────────────────────────────────────────
    if text == "Педагоги":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Педагоги", reply_markup=build_teachers_menu())
        return

    if text == "Список педагогов":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        try:
            data = await get_teachers(user.telegram_user_id)
        except httpx.HTTPError:
            await update.message.reply_text("Ошибка связи.", reply_markup=build_teachers_menu())
            return
        if not data:
            await update.message.reply_text("Педагогов нет.", reply_markup=build_teachers_menu())
            return
        lines = [f'{t["id"]}. {t.get("teacher_name") or t["login"]}' for t in data]
        await update.message.reply_text("Педагоги:\n" + "\n".join(lines), reply_markup=build_teachers_menu())
        return

    if text == "Ставки педагогов":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        try:
            teachers = await get_teachers(user.telegram_user_id)
        except httpx.HTTPError:
            await update.message.reply_text("Ошибка связи.", reply_markup=build_teachers_menu())
            return
        if not teachers:
            await update.message.reply_text("Педагогов нет.", reply_markup=build_teachers_menu())
            return

        lines = []
        for t in teachers:
            try:
                rate_data = await get_teacher_rates(user.telegram_user_id, t["id"])
                default = rate_data["default_rate"]
                name = rate_data.get("teacher_name") or t["login"]
                lines.append(f'{t["id"]}. {name} — {default:,} сум/урок'.replace(",", " "))
            except httpx.HTTPError:
                lines.append(f'{t["id"]}. {t.get("teacher_name") or t["login"]} — ставка не задана')

        msg = (
            "Текущие ставки:\n" + "\n".join(lines) +
            "\n\nЧтобы установить ставку:\n"
            "/set_rate <id_педагога> <ставка> [ГГГГ-ММ-ДД]\n"
            "Пример: /set_rate 3 25000 2026-05-01"
        )
        await update.message.reply_text(msg, reply_markup=build_teachers_menu())
        return

    # ── Инструменты ────────────────────────────────────────────────────────
    if text == "Инструменты":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Инструменты студии", reply_markup=build_instruments_menu())
        return

    if text == "Список инструментов":
        if user is None or user.role not in ("ADMIN", "TEACHER"):
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        try:
            data = await get_instruments(user.telegram_user_id)
        except httpx.HTTPError:
            await update.message.reply_text("Ошибка связи.", reply_markup=build_instruments_menu())
            return
        if not data:
            await update.message.reply_text("Инструментов нет.", reply_markup=build_instruments_menu())
            return
        lines = [f'{i["id"]}. {i["name"]}' for i in data]
        await update.message.reply_text("Инструменты:\n" + "\n".join(lines), reply_markup=build_instruments_menu())
        return

    if text == "Добавить инструмент":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        context.user_data["awaiting_instrument_name"] = True
        await update.message.reply_text("Введите название инструмента:\nПример: Фортепиано")
        return

    # ── Отчёты ─────────────────────────────────────────────────────────────
    if text == "Отчёты":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Отчёты", reply_markup=build_reports_admin_menu())
        return

    if text == "Зарплата педагога":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await context.bot_data["salary_report_cmd"](update, context)
        return

    if text == "Статистика студии":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await context.bot_data["studio_report_cmd"](update, context)
        return

    # ── Настройки ──────────────────────────────────────────────────────────
    if text == "Настройки":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text("Настройки", reply_markup=build_settings_menu())
        return

    if text == "Список пользователей":
        await context.bot_data["admin_users_cmd"](update, context)
        return

    if text == "Установить пароль":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        context.user_data["awaiting_password_input"] = True
        await update.message.reply_text(
            "Введите логин и пароль через пробел:\n<login> <пароль>\n\nПример: teacher mypass123"
        )
        return

    if text == "Привязать Telegram":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text(
            "Использование:\n/admin_bind <login> <telegram_id>",
            reply_markup=build_settings_menu(),
        )
        return

    if text == "Назначить роль":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text(
            "Использование:\n/admin_set_role <login> <role>",
            reply_markup=build_settings_menu(),
        )
        return

    if text == "Изменить логин":
        if user is None or user.role != "ADMIN":
            await update.message.reply_text("Недостаточно прав.", reply_markup=build_root_menu())
            return
        await update.message.reply_text(
            "Для себя: /set_login <new_login>\n"
            "Для другого: /admin_set_login <old_login> <new_login>",
            reply_markup=build_settings_menu(),
        )
        return

    # ── Учитель ────────────────────────────────────────────────────────────
    if text == "Мои отчёты":
        await context.bot_data["last_report_cmd"](update, context)
        return

    if text == "Рассчитать отчёт":
        await context.bot_data["calc_cmd"](update, context)
        return

    if text == "Последний отчёт":
        await context.bot_data["last_report_cmd"](update, context)
        return
