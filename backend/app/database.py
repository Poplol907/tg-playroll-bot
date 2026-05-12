import os
from dotenv import load_dotenv

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
DEV_MODE = os.getenv("DEV_MODE", "0") == "1"

engine = create_async_engine(
    DATABASE_URL,
    echo=DEV_MODE,       # SQL-логи только в dev
    pool_size=10,        # постоянных соединений
    max_overflow=20,     # дополнительных при пике
    pool_pre_ping=True,  # проверять соединение перед использованием
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_session():
    async with AsyncSessionLocal() as session:
        yield session
