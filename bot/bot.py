import logging
import os
import sys
from pathlib import Path

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
    whoami,
    myid
)
from bot.handlers.admin import (
    admin_users_cmd,
    admin_bind_cmd
)
from bot.handlers.reports import (
    calc_cmd,
    handle_text,
    last_report_cmd,
    report_cmd,
)

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


def main():
    if not TOKEN or ":" not in TOKEN:
        raise RuntimeError("BOT_TOKEN не найден или выглядит неправильно. Проверь .env в корне проекта.")

    app = ApplicationBuilder().token(TOKEN).build()
    app.bot_data["get_user_by_telegram_id"] = get_user_by_telegram_id

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("whoami", whoami))
    app.add_handler(CommandHandler("myid", myid))

    app.add_handler(CommandHandler("calc", calc_cmd))
    app.add_handler(CommandHandler("last", last_report_cmd))
    app.add_handler(CommandHandler("report", report_cmd))


    app.add_handler(CommandHandler("admin_users", admin_users_cmd))
    app.add_handler(CommandHandler("admin_bind", admin_bind_cmd))

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    app.run_polling()


if __name__ == "__main__":
    main()