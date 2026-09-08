"""
Test icin izole, bellek-ici SQLite veritabani kurar ve FastAPI'nin
get_db bagimliligini bununla degistirir (production DB'ye dokunulmaz).
"""
import asyncio

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.session import Base, get_db
from app.main import app
from app import models as _models  # noqa: F401  (Base.metadata'ya modelleri kaydeder)

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture()
async def async_client(db_session_factory):
    async def override_get_db():
        async with db_session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()


@pytest.fixture()
async def db_session_factory():
    """Her test icin izole, bellek-ici bir SQLite engine + session factory dondurur."""
    engine = create_async_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield session_factory
    await engine.dispose()
