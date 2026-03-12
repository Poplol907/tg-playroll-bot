import os
import asyncio
from dotenv import load_dotenv
from sqlalchemy import select

from backend.app.database import AsyncSessionLocal
from backend.app.models import User, Org

load_dotenv()

DEFAULT_ORG_ID = 1


async def main():
    login = os.getenv("ADMIN_LOGIN", "admin")

    async with AsyncSessionLocal() as session:
        org = await session.get(Org, DEFAULT_ORG_ID)
        if org is None:
            org = Org(
                id=DEFAULT_ORG_ID,
                name="My Studio",
                slug="my-studio",
                is_active=True,
            )
            session.add(org)
            await session.commit()

        existing = await session.execute(
            select(User).where(
                User.org_id == DEFAULT_ORG_ID,
                User.login == login,
            )
        )
        if existing.scalar_one_or_none() is not None:
            print(f"Admin '{login}' already exists")
            return

        user = User(
            org_id=DEFAULT_ORG_ID,
            login=login,
            role="ADMIN",
            telegram_user_id=None,
            teacher_name=None,
        )

        session.add(user)
        await session.commit()
        print(f"Admin '{login}' created")


if __name__ == "__main__":
    asyncio.run(main())