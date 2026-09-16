"""
Sifre sifirlama akisi testleri (FR-1.3).
"""
import pytest

pytestmark = pytest.mark.anyio


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _register(client, email: str = "musteri@test.com", password: str = "Sifre1234"):
    await client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": email, "password": password,
    })


async def _get_reset_code(client, email: str) -> str:
    r = await client.post("/api/v1/auth/forgot-password", json={"email": email})
    assert r.status_code == 200
    return r.json()["debug_code"]


async def test_full_reset_flow(async_client):
    await _register(async_client)

    code = await _get_reset_code(async_client, "musteri@test.com")
    assert code is not None
    assert len(code) == 6

    # Yeni sifreyle sifirla
    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": code, "new_password": "YeniSifre123",
    })
    assert r.status_code == 200

    # Eski sifre artik calismamali
    r = await async_client.post("/api/v1/auth/login", json={
        "email": "musteri@test.com", "password": "Sifre1234",
    })
    assert r.status_code == 401

    # Yeni sifre calismali
    r = await async_client.post("/api/v1/auth/login", json={
        "email": "musteri@test.com", "password": "YeniSifre123",
    })
    assert r.status_code == 200


async def test_unknown_email_returns_same_response(async_client):
    """User enumeration onlemi: kayitli olmayan e-posta da ayni yaniti almali."""
    r = await async_client.post("/api/v1/auth/forgot-password", json={
        "email": "olmayan@test.com",
    })
    assert r.status_code == 200
    assert r.json()["debug_code"] is None  # kod uretilmedi ama hata da vermedi


async def test_code_is_single_use(async_client):
    await _register(async_client)
    code = await _get_reset_code(async_client, "musteri@test.com")

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": code, "new_password": "YeniSifre123",
    })
    assert r.status_code == 200

    # Ayni kod ikinci kez kullanilamaz
    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": code, "new_password": "BaskaSifre123",
    })
    assert r.status_code == 400


async def test_wrong_code_rejected(async_client):
    await _register(async_client)
    await _get_reset_code(async_client, "musteri@test.com")

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": "000000", "new_password": "YeniSifre123",
    })
    assert r.status_code == 400


async def test_new_code_invalidates_previous(async_client):
    """Yeni kod istendiginde onceki kod gecersiz olmali."""
    await _register(async_client)
    first_code = await _get_reset_code(async_client, "musteri@test.com")
    second_code = await _get_reset_code(async_client, "musteri@test.com")

    assert first_code != second_code

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": first_code, "new_password": "YeniSifre123",
    })
    assert r.status_code == 400

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": second_code, "new_password": "YeniSifre123",
    })
    assert r.status_code == 200


async def test_expired_code_rejected(async_client, db_session_factory):
    """Suresi dolmus kod reddedilmeli."""
    from datetime import datetime, timedelta, timezone
    from sqlalchemy import select
    from app.models.password_reset import PasswordResetToken

    await _register(async_client)
    code = await _get_reset_code(async_client, "musteri@test.com")

    # Tokenin son kullanma tarihini gecmise cek
    async with db_session_factory() as db:
        result = await db.execute(select(PasswordResetToken))
        token = result.scalars().first()
        token.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        await db.commit()

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": code, "new_password": "YeniSifre123",
    })
    assert r.status_code == 400


async def test_short_password_rejected(async_client):
    await _register(async_client)
    code = await _get_reset_code(async_client, "musteri@test.com")

    r = await async_client.post("/api/v1/auth/reset-password", json={
        "email": "musteri@test.com", "code": code, "new_password": "kisa",
    })
    assert r.status_code == 422
