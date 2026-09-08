"""
Uctan uca akis testleri. bkz. 08-test-senaryolari.md
(TC-01, TC-04, TC-21, TC-23, TC-31, TC-32, TC-33, TC-35)
"""
import pytest

pytestmark = pytest.mark.anyio


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _register_and_login(client, email: str, password: str = "Sifre1234", full_name: str = "Test User"):
    await client.post("/api/v1/auth/register", json={
        "full_name": full_name, "email": email, "password": password,
    })
    r = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    token = r.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_register_and_login(async_client):
    r = await async_client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": "ali@example.com", "password": "Sifre1234",
    })
    assert r.status_code == 201
    assert r.json()["role"] == "customer"

    r = await async_client.post("/api/v1/auth/login", json={
        "email": "ali@example.com", "password": "Sifre1234",
    })
    assert r.status_code == 200
    assert "access_token" in r.json()


async def test_login_wrong_password_returns_401(async_client):
    await async_client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": "ali2@example.com", "password": "Sifre1234",
    })
    r = await async_client.post("/api/v1/auth/login", json={
        "email": "ali2@example.com", "password": "YanlisSifre",
    })
    assert r.status_code == 401


async def test_full_ticket_lifecycle(async_client, db_session_factory):
    from app.core.security import hash_password
    from app.models.category import Category
    from app.models.user import User

    # Admin ve temsilciyi dogrudan DB'ye ekle (henuz admin endpoint'i yok)
    async with db_session_factory() as db:
        agent = User(full_name="Ayse Temsilci", email="agent@example.com",
                     password_hash=hash_password("Agent1234"), role="agent")
        category = Category(name="Kredi Karti", description="Kredi karti islemleri")
        db.add_all([agent, category])
        await db.commit()
        category_id = str(category.id)

    customer_headers = await _register_and_login(async_client, "musteri@example.com")
    r = await async_client.post("/api/v1/auth/login", json={
        "email": "agent@example.com", "password": "Agent1234",
    })
    agent_headers = {"Authorization": f"Bearer {r.json()['access_token']}"}

    # US-03: musteri sikayet olusturur
    r = await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": category_id,
        "subject": "Kartimdan cift cekim yapildi",
        "description": "12.08.2026 tarihinde marketten yaptigim odeme iki kez cekildi.",
    })
    assert r.status_code == 201
    ticket = r.json()
    assert ticket["status"] == "new"
    assert ticket["reference_no"].startswith("TSK-")
    ticket_id = ticket["id"]

    # TC-21: baska musteri erisemez
    other_headers = await _register_and_login(async_client, "baska@example.com")
    r = await async_client.get(f"/api/v1/tickets/{ticket_id}", headers=other_headers)
    assert r.status_code == 403

    # US-06: temsilci havuzdan alir
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)
    assert r.status_code == 200
    assert r.json()["status"] == "in_review"

    # TC-31: ikinci kez atama denemesi -> 409 (race condition korumasi)
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/assign", headers=agent_headers)
    assert r.status_code == 409

    # FR-4.4: dahili not ekleme
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/notes", headers=agent_headers, json={
        "content": "Cift cekim onaylandi, iade baslatildi.", "is_internal": True,
    })
    assert r.status_code == 201

    # TC-23: musteri dahili notu goremez
    r = await async_client.get(f"/api/v1/tickets/{ticket_id}/notes", headers=customer_headers)
    assert r.status_code == 200
    assert len(r.json()) == 0

    # Musteri dahili not eklemeye calisirsa 403
    r = await async_client.post(f"/api/v1/tickets/{ticket_id}/notes", headers=customer_headers, json={
        "content": "deneme", "is_internal": True,
    })
    assert r.status_code == 403

    # TC-32: gecersiz durum gecisi
    r = await async_client.patch(f"/api/v1/tickets/{ticket_id}/status", headers=agent_headers, json={
        "new_status": "closed",
    })
    assert r.status_code == 409

    # TC-33: resolution_note olmadan sonuclandirma
    r = await async_client.patch(f"/api/v1/tickets/{ticket_id}/status", headers=agent_headers, json={
        "new_status": "resolved",
    })
    assert r.status_code == 422

    # Basarili sonuclandirma
    r = await async_client.patch(f"/api/v1/tickets/{ticket_id}/status", headers=agent_headers, json={
        "new_status": "resolved",
        "resolution_note": "Cift cekim tespit edildi, tutar 3 is gunu icinde iade edildi.",
    })
    assert r.status_code == 200
    assert r.json()["status"] == "resolved"

    # TC-35: musteri durum degistiremez
    r = await async_client.patch(f"/api/v1/tickets/{ticket_id}/status", headers=customer_headers, json={
        "new_status": "closed",
    })
    assert r.status_code == 403
