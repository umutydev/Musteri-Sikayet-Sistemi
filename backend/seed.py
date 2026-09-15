"""
Gelistirme ortami icin baslangic verisi ekler: ekipler, admin, temsilciler, kategoriler.
Kullanim:  PYTHONPATH=. python3 seed.py
"""
import asyncio

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.category import Category
from app.models.team import Team
from app.models.user import User

# (ekip adi, aciklama, bu ekibe bagli kategoriler)
TEAMS = [
    (
        "Kart İşlemleri Ekibi",
        "Kredi kartı, banka kartı ve ATM ile ilgili talep ve şikayetleri yönetir.",
        [
            ("Kredi Kartı", "Kredi kartı işlemleri, çift çekim, limit sorunları"),
            ("ATM/Kart", "ATM'de kartın yutulması, para çekememe"),
        ],
    ),
    (
        "Hesap ve Transfer Ekibi",
        "Hesap işlemleri, EFT/havale ve bakiye sorunlarını çözer.",
        [
            ("Hesap İşlemleri", "Hesap açma/kapama, EFT/havale, bakiye sorunları"),
        ],
    ),
    (
        "Dijital Bankacılık Ekibi",
        "İnternet ve mobil bankacılık uygulamalarına dair sorunları çözer.",
        [
            ("İnternet Bankacılığı", "Giriş sorunları, uygulama hataları"),
        ],
    ),
    (
        "Güvenlik Ekibi",
        "Şüpheli işlem, dolandırıcılık ve hesap güvenliği vakalarını inceler.",
        [
            ("Dolandırıcılık/Güvenlik", "Şüpheli işlem, hesap güvenliği"),
        ],
    ),
]

# Hicbir ekibe bagli olmayan genel kategori
GENERAL_CATEGORIES = [
    ("Diğer", "Yukarıdaki kategorilere girmeyen konular"),
]


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        admin = User(
            full_name="Admin Kullanıcı", email="admin@banka.com",
            password_hash=hash_password("Admin123!"), role="admin",
        )
        db.add(admin)

        created_teams: list[Team] = []
        for name, description, categories in TEAMS:
            team = Team(name=name, description=description)
            db.add(team)
            await db.flush()  # team.id'yi almak icin
            created_teams.append(team)

            for cat_name, cat_desc in categories:
                db.add(Category(name=cat_name, description=cat_desc, team_id=team.id))

        for cat_name, cat_desc in GENERAL_CATEGORIES:
            db.add(Category(name=cat_name, description=cat_desc))

        # Her ekibe birer temsilci
        agents = [
            ("Ayşe Temsilci", "agent@banka.com", created_teams[0].id),
            ("Mehmet Temsilci", "agent2@banka.com", created_teams[1].id),
            ("Zeynep Temsilci", "agent3@banka.com", created_teams[2].id),
        ]
        for full_name, email, team_id in agents:
            db.add(User(
                full_name=full_name, email=email,
                password_hash=hash_password("Agent123!"), role="agent", team_id=team_id,
            ))

        await db.commit()
        print("Seed tamamlandi:")
        print("  admin@banka.com  / Admin123!")
        print("  agent@banka.com  / Agent123!  (Kart İşlemleri Ekibi)")
        print("  agent2@banka.com / Agent123!  (Hesap ve Transfer Ekibi)")
        print("  agent3@banka.com / Agent123!  (Dijital Bankacılık Ekibi)")


if __name__ == "__main__":
    asyncio.run(seed())
