"""
Kullanici yonetimi, bildirimler, dosya eki ve raporlama uclari icin testler.
"""
import io

import pytest

pytestmark = pytest.mark.anyio


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _seed_staff(db_session_factory):
    """Admin, temsilci ve bir kategori olusturur; kategori id'sini dondurur."""
    from app.core.security import hash_password
    from app.models.category import Category
    from app.models.user import User

    async with db_session_factory() as db:
        admin = User(full_name="Admin Kullanici", email="admin@test.com",
                     password_hash=hash_password("Admin1234"), role="admin")
        agent = User(full_name="Ayse Temsilci", email="agent@test.com",
                     password_hash=hash_password("Agent1234"), role="agent")
        category = Category(name="Kredi Karti", description="Kredi karti islemleri")
        db.add_all([admin, agent, category])
        await db.commit()
        return str(category.id)


async def _login(client, email: str, password: str) -> dict:
    r = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def _register_customer(client, email: str = "musteri@test.com") -> dict:
    await client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": email, "password": "Sifre1234",
    })
    return await _login(client, email, "Sifre1234")


# ---------------------------------------------------------------- Kullanici yonetimi

async def test_admin_can_list_and_create_users(async_client, db_session_factory):
    await _seed_staff(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    r = await async_client.get("/api/v1/users", headers=admin_headers)
    assert r.status_code == 200
    assert len(r.json()) == 2  # admin + agent

    # Yeni temsilci olustur
    r = await async_client.post("/api/v1/users", headers=admin_headers, json={
        "full_name": "Mehmet Temsilci", "email": "mehmet@test.com",
        "password": "Mehmet1234", "role": "agent",
    })
    assert r.status_code == 201
    assert r.json()["role"] == "agent"
    assert "password_hash" not in r.json()  # sifre hash'i asla disari sizmaz

    # Rol filtresi
    r = await async_client.get("/api/v1/users?role=agent", headers=admin_headers)
    assert len(r.json()) == 2


async def test_customer_cannot_access_user_management(async_client, db_session_factory):
    await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.get("/api/v1/users", headers=customer_headers)
    assert r.status_code == 403


async def test_admin_cannot_deactivate_self(async_client, db_session_factory):
    await _seed_staff(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    me = await async_client.get("/api/v1/auth/me", headers=admin_headers)
    admin_id = me.json()["id"]

    r = await async_client.patch(f"/api/v1/users/{admin_id}", headers=admin_headers,
                                 json={"is_active": False})
    assert r.status_code == 400


async def test_user_can_update_own_profile_but_not_role(async_client, db_session_factory):
    await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.patch("/api/v1/users/me", headers=customer_headers,
                                 json={"full_name": "Ali Yeni Ad", "phone": "5551234567"})
    assert r.status_code == 200
    assert r.json()["full_name"] == "Ali Yeni Ad"
    assert r.json()["role"] == "customer"  # rol degismedi

    # Govdeye role gondermeye calissa bile semada olmadigi icin yok sayilir
    r = await async_client.patch("/api/v1/users/me", headers=customer_headers,
                                 json={"role": "admin"})
    assert r.status_code == 200
    assert r.json()["role"] == "customer"


# ---------------------------------------------------------------- Bildirimler

async def test_notifications_created_on_status_change(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")

    # Musteri kayit olusturur -> temsilciye bildirim duser (FR-5.1)
    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id,
        "subject": "Kartimdan cift cekim",
        "description": "12.08.2026 tarihinde iki kez cekim yapildi, iade istiyorum.",
    })
    ticket_id = r.json()["id"]

    r = await async_client.get("/api/v1/notifications", headers=agent_headers)
    assert r.status_code == 200
    assert len(r.json()) == 1

    # Temsilci uzerine alir -> musteriye durum bildirimi duser (FR-5.2)
    await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)

    r = await async_client.get("/api/v1/notifications", headers=customer_headers)
    assert len(r.json()) == 1
    assert "İnceleniyor" in r.json()[0]["message"]


async def test_internal_note_creates_no_customer_notification(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]
    await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)

    before = len((await async_client.get("/api/v1/notifications", headers=customer_headers)).json())

    # Dahili not -> musteriye bildirim GITMEMELI
    await async_client.post(f"/api/v1/tickets/{ticket_id}/notes", headers=agent_headers, json={
        "content": "Dahili inceleme notu", "is_internal": True,
    })
    after_internal = len((await async_client.get("/api/v1/notifications", headers=customer_headers)).json())
    assert after_internal == before

    # Musteriye gorunur yanit -> bildirim GITMELI
    await async_client.post(f"/api/v1/tickets/{ticket_id}/notes", headers=agent_headers, json={
        "content": "Talebiniz inceleniyor, en kisa surede donus yapacagiz.", "is_internal": False,
    })
    after_public = len((await async_client.get("/api/v1/notifications", headers=customer_headers)).json())
    assert after_public == before + 1


async def test_mark_notifications_read(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    await async_client.post(f"/api/v1/tickets/{r.json()['id']}/assign", headers=agent_headers)

    r = await async_client.get("/api/v1/notifications/unread-count", headers=customer_headers)
    assert r.json()["unread_count"] == 1

    r = await async_client.patch("/api/v1/notifications/read-all", headers=customer_headers)
    assert r.json()["unread_count"] == 0


async def test_cannot_read_others_notification(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")

    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })

    # Temsilcinin bildirimi
    agent_notifications = (await async_client.get("/api/v1/notifications", headers=agent_headers)).json()
    notification_id = agent_notifications[0]["id"]

    # Musteri onu okundu isaretlemeye calisir
    r = await async_client.patch(f"/api/v1/notifications/{notification_id}/read", headers=customer_headers)
    assert r.status_code == 403


# ---------------------------------------------------------------- Dosya eki

async def test_upload_and_list_attachment(async_client, db_session_factory, tmp_path, monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))

    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Ekli sikayet",
        "description": "Bu sikayete ekstre dosyasi ekleyecegim, aciklama yeterince uzun.",
    })
    ticket_id = r.json()["id"]

    files = {"file": ("ekstre.pdf", io.BytesIO(b"%PDF-1.4 fake content"), "application/pdf")}
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/attachments",
                                headers=customer_headers, files=files)
    assert r.status_code == 201
    assert r.json()["file_name"] == "ekstre.pdf"
    assert "file_url" not in r.json()  # disk yolu disari sizmamali

    r = await async_client.get(f"/api/v1/tickets/{ticket_id}/attachments", headers=customer_headers)
    assert len(r.json()) == 1


async def test_reject_unsupported_file_type(async_client, db_session_factory, tmp_path, monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))

    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]

    files = {"file": ("virus.exe", io.BytesIO(b"MZ"), "application/x-msdownload")}
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/attachments",
                                headers=customer_headers, files=files)
    assert r.status_code == 400


async def test_attachment_limit(async_client, db_session_factory, tmp_path, monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))

    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]

    # 5 dosya yukle
    for i in range(5):
        files = {"file": (f"dosya{i}.png", io.BytesIO(b"\x89PNG fake"), "image/png")}
        r = await async_client.post(f"/api/v1/tickets/{ticket_id}/attachments",
                                    headers=customer_headers, files=files)
        assert r.status_code == 201

    # 6. dosya reddedilmeli (TC-13)
    files = {"file": ("dosya6.png", io.BytesIO(b"\x89PNG fake"), "image/png")}
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/attachments",
                                headers=customer_headers, files=files)
    assert r.status_code == 400


async def test_cannot_upload_to_others_ticket(async_client, db_session_factory, tmp_path, monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))

    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client, "musteri1@test.com")

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]

    other_headers = await _register_customer(async_client, "musteri2@test.com")
    files = {"file": ("dosya.png", io.BytesIO(b"\x89PNG"), "image/png")}
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/attachments",
                                headers=other_headers, files=files)
    assert r.status_code == 403


# ---------------------------------------------------------------- Raporlama

async def test_summary_report(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    for i in range(3):
        await async_client.post("/api/v1/tickets", headers=customer_headers, json={
            "type": "complaint", "category_id": category_id, "subject": f"Sikayet {i}",
            "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
        })

    r = await async_client.get("/api/v1/reports/summary", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["total_tickets"] == 3
    assert data["open_tickets"] == 3
    assert data["closed_tickets"] == 0
    assert data["unassigned_tickets"] == 3
    assert any(c["category"] == "Kredi Karti" and c["count"] == 3 for c in data["category_breakdown"])


async def test_agent_performance_report(async_client, db_session_factory):
    category_id = await _seed_staff(db_session_factory)
    customer_headers = await _register_customer(async_client)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id, "subject": "Test konusu",
        "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
    })
    ticket_id = r.json()["id"]
    await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)

    r = await async_client.get("/api/v1/reports/agent-performance", headers=admin_headers)
    assert r.status_code == 200
    agent_row = next(a for a in r.json() if a["agent_name"] == "Ayse Temsilci")
    assert agent_row["assigned_count"] == 1
    assert agent_row["closed_count"] == 0


async def test_reports_require_admin(async_client, db_session_factory):
    await _seed_staff(db_session_factory)
    agent_headers = await _login(async_client, "agent@test.com", "Agent1234")

    r = await async_client.get("/api/v1/reports/summary", headers=agent_headers)
    assert r.status_code == 403
