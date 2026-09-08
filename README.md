# Backend — Bankacılık Talep ve Şikayet Yönetim Sistemi

FastAPI + PostgreSQL ile yazılmış REST API. Proje dokümantasyonundaki (06 ve 07 numaralı
dokümanlar) veritabanı ve API tasarımıyla birebir uyumludur.

**Bu iskelet test edilmiştir** — `python3 test_smoke.py` ile 15 senaryoluk uçtan uca test
(kayıt, giriş, yetki kontrolü, atama race-condition koruması, durum makinesi, dahili not
gizliliği) SQLite üzerinde çalıştırılıp doğrulanmıştır.

## Kurulum

```bash
# 1. Sanal ortam oluştur
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# 2. Bağımlılıkları kur
pip install -r requirements.txt

# 3. .env dosyasını oluştur
cp .env.example .env
# .env içindeki DATABASE_URL, JWT_SECRET_KEY vb. değerleri gerekirse düzenle

# 4. PostgreSQL'i Docker ile ayağa kaldır
docker compose up -d

# 5. Migration'ları uygula (ilk migration'ı oluşturup çalıştır)
alembic revision --autogenerate -m "init"
alembic upgrade head

# 6. (Opsiyonel) Örnek admin/temsilci/kategori verisi ekle
PYTHONPATH=. python3 seed.py

# 7. Sunucuyu başlat
uvicorn app.main:app --reload
```

Sunucu ayağa kalktığında:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health check: http://localhost:8000/health

## Proje Yapısı

```
backend/
├── app/
│   ├── main.py              # FastAPI giriş noktası
│   ├── core/
│   │   ├── config.py        # .env'den okunan ayarlar
│   │   └── security.py      # JWT + bcrypt şifre işlemleri
│   ├── db/
│   │   └── session.py       # Async SQLAlchemy engine/session
│   ├── models/               # SQLAlchemy modelleri (06-veritabani-tasarimi.md ile eşleşir)
│   │   ├── user.py
│   │   ├── category.py
│   │   ├── ticket.py         # Durum makinesi (VALID_TRANSITIONS) burada
│   │   └── ticket_extras.py  # attachments, notes, status_history, notifications
│   ├── schemas/               # Pydantic request/response modelleri
│   └── api/
│       ├── deps.py            # get_current_user, require_roles (RBAC)
│       └── v1/
│           ├── router.py
│           └── endpoints/
│               ├── auth.py
│               ├── tickets.py    # Ana iş mantığı burada
│               └── categories.py
├── alembic/                    # DB migration'ları
├── seed.py                     # Örnek veri ekleme scripti
├── docker-compose.yml           # PostgreSQL için
└── requirements.txt
```

## Uygulanan İş Kuralları (Fonksiyonel Gereksinimler Dokümanına Referansla)

| Kod | Kural | Nerede |
|---|---|---|
| FR-2.5 | Referans no otomatik üretimi (`TSK-2026-xxxxxx`) | `tickets.py::create_ticket` |
| FR-4.7 | Geçersiz durum geçişi engellenir | `models/ticket.py::VALID_TRANSITIONS` |
| FR-7.1 | Müşteri sadece kendi kaydını görür | `tickets.py::get_ticket` |
| FR-4.4 | Dahili notlar müşteriye gösterilmez | `tickets.py::list_notes` |
| US-06 (TC-31) | Atamada race condition koruması (atomik `UPDATE ... WHERE assigned_to IS NULL`) | `tickets.py::assign_ticket` |
| US-08 (TC-33) | Sonuçlandırmada resolution_note zorunlu | `tickets.py::update_status` |

## Sırada Ne Var (Sprint 1+)

- [ ] Dosya yükleme endpoint'i (`/tickets/{id}/attachments`)
- [ ] Bildirim oluşturma tetikleyicileri (durum değiştiğinde)
- [ ] Şifremi unuttum akışı
- [ ] Kullanıcı yönetimi endpoint'leri (admin: `/users`)
- [ ] Raporlama endpoint'leri (`/reports/summary`)
- [ ] Unit testlerin pytest ile resmi test suit'ine taşınması
