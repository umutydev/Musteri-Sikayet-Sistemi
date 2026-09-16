"""
E-posta servisi testleri.

Gercek e-posta gondermeyiz; send_email fonksiyonunu izleyerek (monkeypatch)
dogru adrese, dogru icerikle cagrilip cagrilmadigini kontrol ederiz.
"""
import pytest

pytestmark = pytest.mark.anyio


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
def sent_emails(monkeypatch):
    """
    email_service.send_email'i sahte bir fonksiyonla degistirir ve
    gonderilmek istenen e-postalari listeye toplar.
    """
    captured: list[dict] = []

    async def fake_send_email(to: str, subject: str, body: str) -> None:
        captured.append({"to": to, "subject": subject, "body": body})

    from app.services import email_service
    monkeypatch.setattr(email_service, "send_email", fake_send_email)
    return captured


async def _seed(db_session_factory) -> str:
    from app.core.security import hash_password
    from app.models.category import Category
    from app.models.user import User

    async with db_session_factory() as db:
        agent = User(full_name="Ayse Temsilci", email="agent@test.com",
                     password_hash=hash_password("Agent1234"), role="agent")
        category = Category(name="Kredi Karti")
        db.add_all([agent, category])
        await db.commit()
        return str(category.id)


async def _register_customer(client, email: str = "musteri@test.com") -> dict:
    await client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": email, "password": "Sifre1234",
    })
    r = await client.post("/api/v1/auth/login", json={
        "email": email, "password": "Sifre1234",
    })
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def test_password_reset_sends_email(async_client, sent_emails):
    await async_client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": "musteri@test.com", "password": "Sifre1234",
    })

    r = await async_client.post("/api/v1/auth/forgot-password", json={
        "email": "musteri@test.com",
    })
    code = r.json()["debug_code"]

    assert len(sent_emails) == 1
    assert sent_emails[0]["to"] == "musteri@test.com"
    assert code in sent_emails[0]["body"]


async def test_unknown_email_sends_nothing(async_client, sent_emails):
    """Kayitli olmayan e-postaya gonderim yapilmamali."""
    await async_client.post("/api/v1/auth/forgot-password", json={
        "email": "olmayan@test.com",
    })
    assert len(sent_emails) == 0


async def test_ticket_created_sends_email(async_client, db_session_factory, sent_emails):
    category_id = await _seed(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id,
        "subject": "Kartimdan cift cekim",
        "description": "12.08.2026 tarihinde iki kez cekim yapildi, iade istiyorum.",
    })
    reference_no = r.json()["reference_no"]

    assert len(sent_emails) == 1
    assert sent_emails[0]["to"] == "musteri@test.com"
    assert reference_no in sent_emails[0]["body"]


async def test_status_change_sends_email(async_client, db_session_factory, sent_emails):
    category_id = await _seed(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]
    reference_no = r.json()["reference_no"]

    agent_r = await async_client.post("/api/v1/auth/login", json={
        "email": "agent@test.com", "password": "Agent1234",
    })
    agent_headers = {"Authorization": f"Bearer {agent_r.json()['access_token']}"}

    await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)

    sent_emails.clear()  # olusturma e-postasini sayma

    await async_client.patch(f"/api/v1/tickets/{ticket_id}/status", headers=agent_headers, json={
        "new_status": "resolved",
        "resolution_note": "Cift cekim tespit edildi, tutar 3 is gunu icinde iade edildi.",
    })

    assert len(sent_emails) == 1
    assert sent_emails[0]["to"] == "musteri@test.com"
    assert reference_no in sent_emails[0]["body"]
    assert "Çözüldü" in sent_emails[0]["body"]
    assert "iade edildi" in sent_emails[0]["body"]


async def test_console_backend_does_not_raise(monkeypatch):
    """Konsol modunda gonderim hata firlatmamali."""
    from app.core.config import settings
    from app.services import email_service

    monkeypatch.setattr(settings, "EMAIL_BACKEND", "console")
    await email_service.send_email(to="test@test.com", subject="Konu", body="Icerik")


async def test_smtp_failure_does_not_raise(monkeypatch):
    """
    SMTP sunucusu cokse bile istisna firlatilmamali - kullanicinin islemi
    e-posta yuzunden basarisiz olmasin.
    """
    from app.core.config import settings
    from app.services import email_service

    monkeypatch.setattr(settings, "EMAIL_BACKEND", "smtp")
    monkeypatch.setattr(settings, "SMTP_USER", "test@test.com")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "sahte")

    def broken_smtp(*args, **kwargs):
        raise ConnectionError("SMTP sunucusuna ulasilamadi")

    monkeypatch.setattr(email_service.smtplib, "SMTP", broken_smtp)

    # Istisna firlatmamali
    await email_service.send_email(to="test@test.com", subject="Konu", body="Icerik")
