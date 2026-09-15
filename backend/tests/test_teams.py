"""
Ekip yonetimi ve ekip bazli havuz filtrelemesi testleri.
"""
import pytest

pytestmark = pytest.mark.anyio


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _login(client, email: str, password: str) -> dict:
    r = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def _register_customer(client, email: str = "musteri@test.com") -> dict:
    await client.post("/api/v1/auth/register", json={
        "full_name": "Ali Veli", "email": email, "password": "Sifre1234",
    })
    return await _login(client, email, "Sifre1234")


async def _seed_two_teams(db_session_factory) -> dict:
    """
    Iki ekip, her birine bir temsilci ve bir kategori olusturur.
    Ayrica hicbir ekibe bagli olmayan bir kategori ve ekipsiz bir temsilci ekler.
    """
    from app.core.security import hash_password
    from app.models.category import Category
    from app.models.team import Team
    from app.models.user import User

    async with db_session_factory() as db:
        admin = User(full_name="Admin", email="admin@test.com",
                     password_hash=hash_password("Admin1234"), role="admin")
        db.add(admin)

        kart_team = Team(name="Kart Ekibi", description="Kart islemleri")
        hesap_team = Team(name="Hesap Ekibi", description="Hesap islemleri")
        db.add_all([kart_team, hesap_team])
        await db.flush()

        kart_cat = Category(name="Kredi Karti", team_id=kart_team.id)
        hesap_cat = Category(name="Hesap Islemleri", team_id=hesap_team.id)
        genel_cat = Category(name="Diger")  # ekipsiz kategori
        db.add_all([kart_cat, hesap_cat, genel_cat])

        db.add_all([
            User(full_name="Kart Temsilcisi", email="kart@test.com",
                 password_hash=hash_password("Agent1234"), role="agent", team_id=kart_team.id),
            User(full_name="Hesap Temsilcisi", email="hesap@test.com",
                 password_hash=hash_password("Agent1234"), role="agent", team_id=hesap_team.id),
            User(full_name="Ekipsiz Temsilci", email="ekipsiz@test.com",
                 password_hash=hash_password("Agent1234"), role="agent"),
        ])
        await db.commit()

        return {
            "kart_team_id": str(kart_team.id),
            "hesap_team_id": str(hesap_team.id),
            "kart_cat_id": str(kart_cat.id),
            "hesap_cat_id": str(hesap_cat.id),
            "genel_cat_id": str(genel_cat.id),
        }


# ---------------------------------------------------------------- Ekip CRUD

async def test_admin_can_create_and_list_teams(async_client, db_session_factory):
    await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    r = await async_client.get("/api/v1/teams", headers=admin_headers)
    assert r.status_code == 200
    assert len(r.json()) == 2

    r = await async_client.post("/api/v1/teams", headers=admin_headers, json={
        "name": "Guvenlik Ekibi", "description": "Dolandiricilik vakalari",
    })
    assert r.status_code == 201
    assert r.json()["member_count"] == 0
    assert r.json()["active_ticket_count"] == 0


async def test_duplicate_team_name_rejected(async_client, db_session_factory):
    await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    r = await async_client.post("/api/v1/teams", headers=admin_headers, json={"name": "Kart Ekibi"})
    assert r.status_code == 400


async def test_agent_cannot_create_team(async_client, db_session_factory):
    await _seed_two_teams(db_session_factory)
    agent_headers = await _login(async_client, "kart@test.com", "Agent1234")

    r = await async_client.post("/api/v1/teams", headers=agent_headers, json={"name": "Yeni Ekip"})
    assert r.status_code == 403


async def test_team_detail_shows_member_and_ticket_counts(async_client, db_session_factory):
    ids = await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")
    customer_headers = await _register_customer(async_client)

    # Kart kategorisinde iki kayit olustur
    for i in range(2):
        await async_client.post("/api/v1/tickets", headers=customer_headers, json={
            "type": "complaint", "category_id": ids["kart_cat_id"], "subject": f"Kart sorunu {i}",
            "description": "Kartimdan cift cekim yapildi, aciklama yeterince uzun olmali.",
        })

    r = await async_client.get("/api/v1/teams", headers=admin_headers)
    kart_team = next(t for t in r.json() if t["name"] == "Kart Ekibi")
    assert kart_team["member_count"] == 1
    assert kart_team["active_ticket_count"] == 2
    assert "Kredi Karti" in kart_team["category_names"]

    hesap_team = next(t for t in r.json() if t["name"] == "Hesap Ekibi")
    assert hesap_team["active_ticket_count"] == 0


# ---------------------------------------------------------------- Uye yonetimi

async def test_add_and_remove_team_member(async_client, db_session_factory):
    ids = await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    users = (await async_client.get("/api/v1/users?role=agent", headers=admin_headers)).json()
    ekipsiz = next(u for u in users if u["email"] == "ekipsiz@test.com")
    assert ekipsiz["team_id"] is None

    # Ekibe ekle
    r = await async_client.post(
        f"/api/v1/teams/{ids['kart_team_id']}/members",
        headers=admin_headers, json={"user_id": ekipsiz["id"]},
    )
    assert r.status_code == 200

    members = (await async_client.get(
        f"/api/v1/teams/{ids['kart_team_id']}/members", headers=admin_headers
    )).json()
    assert len(members) == 2

    # Ekipten cikar
    r = await async_client.delete(
        f"/api/v1/teams/{ids['kart_team_id']}/members/{ekipsiz['id']}", headers=admin_headers
    )
    assert r.status_code == 204

    members = (await async_client.get(
        f"/api/v1/teams/{ids['kart_team_id']}/members", headers=admin_headers
    )).json()
    assert len(members) == 1


async def test_customer_cannot_be_added_to_team(async_client, db_session_factory):
    ids = await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")
    await _register_customer(async_client)

    users = (await async_client.get("/api/v1/users?role=customer", headers=admin_headers)).json()
    customer_id = users[0]["id"]

    r = await async_client.post(
        f"/api/v1/teams/{ids['kart_team_id']}/members",
        headers=admin_headers, json={"user_id": customer_id},
    )
    assert r.status_code == 400


# ---------------------------------------------------------------- Havuz filtrelemesi

async def test_agent_pool_filtered_by_team(async_client, db_session_factory):
    """
    Kart ekibindeki temsilci yalnizca kart kategorisindeki (ve ekipsiz kategorideki)
    kayitlari havuzda gormeli; hesap kategorisindekileri GORMEMELI.
    """
    ids = await _seed_two_teams(db_session_factory)
    customer_headers = await _register_customer(async_client)

    # Her kategoriden birer kayit
    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": ids["kart_cat_id"], "subject": "Kart sorunu",
        "description": "Kartimdan cift cekim yapildi, aciklama yeterince uzun olmali.",
    })
    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": ids["hesap_cat_id"], "subject": "Havale sorunu",
        "description": "Havalem karsi hesaba gecmedi, aciklama yeterince uzun olmali.",
    })
    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "request", "category_id": ids["genel_cat_id"], "subject": "Genel talep",
        "description": "Genel bir talebim var, aciklama yeterince uzun olmali.",
    })

    kart_headers = await _login(async_client, "kart@test.com", "Agent1234")
    r = await async_client.get("/api/v1/tickets?pool=true", headers=kart_headers)
    subjects = {t["subject"] for t in r.json()}
    assert "Kart sorunu" in subjects
    assert "Genel talep" in subjects          # ekipsiz kategori herkese acik
    assert "Havale sorunu" not in subjects    # baska ekibin kategorisi

    hesap_headers = await _login(async_client, "hesap@test.com", "Agent1234")
    r = await async_client.get("/api/v1/tickets?pool=true", headers=hesap_headers)
    subjects = {t["subject"] for t in r.json()}
    assert "Havale sorunu" in subjects
    assert "Kart sorunu" not in subjects


async def test_agent_without_team_sees_all_pool(async_client, db_session_factory):
    """Ekibi olmayan temsilci tum havuzu gorur (geriye donuk uyumluluk)."""
    ids = await _seed_two_teams(db_session_factory)
    customer_headers = await _register_customer(async_client)

    for cat_key in ("kart_cat_id", "hesap_cat_id"):
        await async_client.post("/api/v1/tickets", headers=customer_headers, json={
            "type": "complaint", "category_id": ids[cat_key], "subject": f"Kayit {cat_key}",
            "description": "Bu bir test aciklamasidir, yeterince uzun olmasi gerekiyor.",
        })

    ekipsiz_headers = await _login(async_client, "ekipsiz@test.com", "Agent1234")
    r = await async_client.get("/api/v1/tickets?pool=true", headers=ekipsiz_headers)
    assert len(r.json()) == 2


async def test_new_ticket_notifies_only_relevant_team(async_client, db_session_factory):
    """Yeni kayit bildirimi yalnizca ilgili ekibin temsilcisine gitmeli."""
    ids = await _seed_two_teams(db_session_factory)
    customer_headers = await _register_customer(async_client)

    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "complaint", "category_id": ids["kart_cat_id"], "subject": "Kart sorunu",
        "description": "Kartimdan cift cekim yapildi, aciklama yeterince uzun olmali.",
    })

    kart_headers = await _login(async_client, "kart@test.com", "Agent1234")
    hesap_headers = await _login(async_client, "hesap@test.com", "Agent1234")

    kart_notifications = (await async_client.get("/api/v1/notifications", headers=kart_headers)).json()
    hesap_notifications = (await async_client.get("/api/v1/notifications", headers=hesap_headers)).json()

    assert len(kart_notifications) == 1
    assert len(hesap_notifications) == 0


# ---------------------------------------------------------------- Kategori-ekip baglantisi

async def test_assign_category_to_team(async_client, db_session_factory):
    ids = await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    # Ekipsiz kategoriyi hesap ekibine devret
    r = await async_client.patch(
        f"/api/v1/categories/{ids['genel_cat_id']}",
        headers=admin_headers, json={"team_id": ids["hesap_team_id"]},
    )
    assert r.status_code == 200
    assert r.json()["team_id"] == ids["hesap_team_id"]

    # Artik kart ekibi bu kategorideki kayitlari havuzda gormemeli
    customer_headers = await _register_customer(async_client)
    await async_client.post("/api/v1/tickets", headers=customer_headers, json={
        "type": "request", "category_id": ids["genel_cat_id"], "subject": "Genel talep",
        "description": "Genel bir talebim var, aciklama yeterince uzun olmali.",
    })

    kart_headers = await _login(async_client, "kart@test.com", "Agent1234")
    r = await async_client.get("/api/v1/tickets?pool=true", headers=kart_headers)
    assert len(r.json()) == 0


async def test_delete_team_unlinks_members_and_categories(async_client, db_session_factory):
    ids = await _seed_two_teams(db_session_factory)
    admin_headers = await _login(async_client, "admin@test.com", "Admin1234")

    r = await async_client.delete(f"/api/v1/teams/{ids['kart_team_id']}", headers=admin_headers)
    assert r.status_code == 204

    # Uye artik ekipsiz
    users = (await async_client.get("/api/v1/users?role=agent", headers=admin_headers)).json()
    kart_agent = next(u for u in users if u["email"] == "kart@test.com")
    assert kart_agent["team_id"] is None

    # Kategori artik ekipsiz - ve ekipsiz temsilci onu havuzda gorebilmeli
    categories = (await async_client.get("/api/v1/categories", headers=admin_headers)).json()
    kart_cat = next(c for c in categories if c["name"] == "Kredi Karti")
    assert kart_cat["team_id"] is None
