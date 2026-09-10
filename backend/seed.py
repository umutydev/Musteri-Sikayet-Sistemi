"""
Gelistirme ortami icin baslangic verisi ekler: admin, temsilci, kategoriler.
Kullanim:  PYTHONPATH=. python3 seed.py
"""
import asyncio

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.category import Category
from app.models.user import User

CATEGORIES = [
    ("Kredi Kartı", "Kredi kartı işlemleri, çift çekim, limit sorunları"),
    ("Hesap İşlemleri", "Hesap açma/kapama, EFT/havale, bakiye sorunları"),
    ("İnternet Bankacılığı", "Giriş sorunları, uygulama hataları"),
    ("ATM/Kart", "ATM'de kartın yutulması, para çekememe"),
    ("Dolandırıcılık/Güvenlik", "Şüpheli işlem, hesap güvenliği"),
    ("Diğer", "Yukarıdaki kategorilere girmeyen konular"),
]


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        admin = User(
            full_name="Admin Kullanıcı", email="admin@banka.com",
            password_hash=hash_password("Admin123!"), role="admin",
        )
        agent = User(
            full_name="Ayşe Temsilci", email="agent@banka.com",
            password_hash=hash_password("Agent123!"), role="agent",
        )
        db.add_all([admin, agent])
        db.add_all([Category(name=n, description=d) for n, d in CATEGORIES])
        await db.commit()
        print("Seed tamamlandi: admin@banka.com / Admin123!, agent@banka.com / Agent123!")


if __name__ == "__main__":
    asyncio.run(seed())
