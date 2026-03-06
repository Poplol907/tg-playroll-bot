import os
import asyncio
from dotenv import load_dotenv
from passlib.context import CryptContext
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models import User

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

async def main():
    login = os.getenv("ADMIN_LOGIN", "admin")
    password = os.getenv("ADMIN_PASSWORD", "admin123")

    async with AsyncSessionLocal() as session:
        existing = await session.execute(select(User).where(User.login == login))
        if existing.scalar_one_or_none() is not None:
            print(f"Admin '{login}' already exists")
            return

        user = User(
            login=login,
            role="ADMIN",
            telegram_user_id=None,
            teacher_name=None,
        )
        # пока просто храним хэш в teacher_name? нет. добавим поле password_hash нормально.
        # поэтому СТОП: сначала обновим модель.
        print("STOP: update model to include password_hash first.")

if __name__ == "__main__":
    asyncio.run(main())
