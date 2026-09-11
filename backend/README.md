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

| FR-1.5 | Admin kendi hesabını pasifleştiremez/rolünü düşüremez | `users.py::update_user` |
| FR-1.6 | Kullanıcı kendi rolünü değiştiremez (`UserSelfUpdate` şemasında `role` alanı yok) | `schemas/user.py` |
| FR-2.4 | Dosya eki: max 5 adet, ≤10MB, yalnızca jpg/png/pdf | `attachments.py::upload_attachment` |
| FR-5.1 | Yeni kayıtta temsilci havuzuna bildirim | `services/notification_service.py` |
| FR-5.2 | Durum değişiminde müşteriye bildirim | `services/notification_service.py` |

## Endpoint Listesi

### Auth
| Method | Yol | Yetki |
|---|---|---|
| POST | `/auth/register` | Herkes |
| POST | `/auth/login` | Herkes |
| POST | `/auth/refresh` | Refresh token sahibi |
| GET | `/auth/me` | Auth |

### Kullanıcılar
| Method | Yol | Yetki |
|---|---|---|
| GET | `/users` | Admin (filtre: role, is_active, search) |
| POST | `/users` | Admin |
| GET | `/users/{id}` | Admin |
| PATCH | `/users/{id}` | Admin |
| PATCH | `/users/me` | Auth (yalnızca ad/telefon) |

### Kayıtlar
| Method | Yol | Yetki |
|---|---|---|
| POST | `/tickets` | Müşteri |
| GET | `/tickets` | Auth (role göre kapsam) |
| GET | `/tickets/{id}` | Sahibi / personel |
| POST | `/tickets/{id}/assign` | Temsilci, Admin |
| PATCH | `/tickets/{id}/status` | Temsilci, Admin |
| POST/GET | `/tickets/{id}/notes` | Auth |
| POST/GET | `/tickets/{id}/attachments` | Sahibi / personel |
| GET | `/tickets/{id}/attachments/{aid}/download` | Sahibi / personel |

### Bildirimler
| Method | Yol | Yetki |
|---|---|---|
| GET | `/notifications` | Auth (yalnızca kendi bildirimleri) |
| GET | `/notifications/unread-count` | Auth |
| PATCH | `/notifications/read-all` | Auth |
| PATCH | `/notifications/{id}/read` | Auth (sahiplik kontrollü) |

### Raporlar
| Method | Yol | Yetki |
|---|---|---|
| GET | `/reports/summary` | Admin |
| GET | `/reports/agent-performance` | Admin |

### Kategoriler
| Method | Yol | Yetki |
|---|---|---|
| GET | `/categories` | Auth |
| POST | `/categories` | Admin |

## Test

```bash
PYTHONPATH=. pytest tests/ -v
```

18 test, tümü geçiyor. Kapsanan senaryolar:

- Kayıt/giriş akışı, hatalı şifrede 401
- Tam kayıt yaşam döngüsü (oluştur → ata → not ekle → sonuçlandır)
- Yetkisiz erişim (403): başka müşterinin kaydı, kullanıcı yönetimi, raporlar
- Eşzamanlı atama koruması (409)
- Geçersiz durum geçişi (409)
- Sonuç notu olmadan sonuçlandırma (422)
- Dahili not gizliliği (müşteri göremez, bildirim almaz)
- Dosya eki: format reddi, adet limiti, sahiplik kontrolü
- Bildirim oluşturma, okundu işaretleme, başkasının bildirimine erişim engeli
- Admin'in kendi hesabını pasifleştirememesi
- Kullanıcının kendi rolünü yükseltememesi

## Dosya Yükleme Notu

v1'de dosyalar yerel diske (`UPLOAD_DIR`, varsayılan `./uploads`) kaydedilir.
Dosya adları çakışmayı önlemek için UUID ile yeniden üretilir; orijinal ad
veritabanında tutulur. Diskteki gerçek yol (`file_url`) API yanıtlarında
döndürülmez — erişim yalnızca yetki kontrolü yapılan `/download` ucu üzerindendir.

Production ortamında S3 uyumlu bir obje deposuna geçiş önerilir; bu durumda
yalnızca `attachments.py` içindeki kaydetme/okuma bölümü değişir.

## Sırada Ne Var

- [ ] Şifremi unuttum akışı (`/auth/forgot-password`, `/auth/reset-password`)
- [ ] E-posta gönderme servisi (bildirimler şu an yalnızca uygulama içi)
- [ ] Ekipler (teams) modülü — veri modeli ve endpoint'ler
- [ ] Sonuçlanan kayıtların 7 gün sonra otomatik kapatılması (zamanlanmış görev)
- [ ] Müşteri memnuniyet puanı (FR-3.4)
