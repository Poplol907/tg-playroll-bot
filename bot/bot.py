import logging
import os
import sys
from pathlib import Path


from sqlalchemy.exc import IntegrityError
from dotenv import load_dotenv
from sqlalchemy import select
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    filters,
)

from bot.handlers.common import (
    start,
    help_cmd,
    whoami,
    myid,
    menu_button_handler,
    set_login_cmd,
)

from bot.handlers.admin import (
    admin_users_cmd,
    admin_bind_cmd,
    admin_create_user_cmd,
    admin_set_role_cmd,
    admin_set_login_cmd,
)


from bot.handlers.reports import (
    calc_cmd,
    handle_text,
    last_report_cmd,
    report_cmd,
)

from bot.handlers.teacher import (
    teacher_home_cmd
)

from bot.handlers.students import student_create_cmd, students_list_cmd
from bot.handlers.reports_v2 import salary_report_cmd, studio_report_cmd
from bot.handlers.rates import set_rate_cmd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

load_dotenv(ROOT / ".env")

from backend.app.database import AsyncSessionLocal  # noqa: E402
from backend.app.models import User  # noqa: E402

TOKEN = os.getenv("BOT_TOKEN")

logging.basicConfig(level=logging.INFO)
logging.getLogger("httpx").setLevel(logging.WARNING)



async def get_user_by_telegram_id(telegram_id: int):
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.telegram_user_id == telegram_id)
        )
        return result.scalar_one_or_none()

DEFAULT_ORG_ID = 1

async def create_pending_user(telegram_id: int):
    async with AsyncSessionLocal() as session:
        login = f"tg_{telegram_id}"

        user = User(
            org_id=DEFAULT_ORG_ID,
            login=login,
            role="PENDING",
            telegram_user_id=telegram_id,
            teacher_name=None,
        )
        session.add(user)

        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()

            result = await session.execute(
                select(User).where(User.telegram_user_id == telegram_id)
            )
            existing = result.scalar_one_or_none()
            if existing is not None:
                return existing
            raise

        await session.refresh(user)
        return user

def main():
    if not TOKEN or ":" not in TOKEN:
        raise RuntimeError("BOT_TOKEN не найден или выглядит неправильно. Проверь .env в корне проекта.")

    app = ApplicationBuilder().token(TOKEN).build()
    app.bot_data["get_user_by_telegram_id"] = get_user_by_telegram_id
    app.bot_data["create_pending_user"] = create_pending_user


    app.bot_data["calc_cmd"] = calc_cmd
    app.bot_data["last_report_cmd"] = last_report_cmd
    app.bot_data["admin_users_cmd"] = admin_users_cmd
    app.bot_data["teacher_home_cmd"] = teacher_home_cmd
    app.bot_data["salary_report_cmd"] = salary_report_cmd
    app.bot_data["studio_report_cmd"] = studio_report_cmd

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("whoami", whoami))
    app.add_handler(CommandHandler("myid", myid))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("set_login", set_login_cmd))

    app.add_handler(CommandHandler("calc", calc_cmd))
    app.add_handler(CommandHandler("last", last_report_cmd))
    app.add_handler(CommandHandler("report", report_cmd))


    app.add_handler(CommandHandler("admin_users", admin_users_cmd))
    app.add_handler(CommandHandler("admin_bind", admin_bind_cmd))
    app.add_handler(CommandHandler("admin_create_user", admin_create_user_cmd))
    app.add_handler(CommandHandler("admin_set_role", admin_set_role_cmd))
    app.add_handler(CommandHandler("admin_set_login", admin_set_login_cmd))

    app.add_handler(CommandHandler("student_create", student_create_cmd))
    app.add_handler(CommandHandler("students", students_list_cmd))
    app.add_handler(CommandHandler("set_rate", set_rate_cmd))

    app.add_handler(
        MessageHandler(
            filters.Regex(
                "^("
                "Меню админа|Меню преподавателя|Профиль|Помощь|Назад|Назад в меню админа|"
                "Ученики|Список учеников|Добавить ученика|"
                "Педагоги|Список педагогов|Ставки педагогов|"
                "Инструменты|Список инструментов|Добавить инструмент|"
                "Отчёты|Зарплата педагога|Статистика студии|"
                "Настройки|Установить пароль|Список пользователей|"
                "Привязать Telegram|Назначить роль|Изменить логин|"
                "Рассчитать отчёт|Последний отчёт|Мои отчёты"
                ")$"
            ),
            menu_button_handler,
        )
    )

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    app.run_polling()


if __name__ == "__main__":
    main()