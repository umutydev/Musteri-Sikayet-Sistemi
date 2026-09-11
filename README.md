# Bankacılık Talep ve Şikayet Yönetim Sistemi

Banka müşterilerinin talep veya şikayet oluşturabildiği, süreç durumunu takip edebildiği;
banka personelinin ise bu kayıtları inceleyip sonuçlandırabildiği bir sistem.

Staj programı kapsamında geliştirilmektedir.

## Mimari
git add README.md

┌─────────────────────────────────────┐
│ iOS Uygulaması (Swift / SwiftUI) │
│ Müşteri · Temsilci · Admin │
│ Tek uygulama, role göre ekranlar │
└──────────────┬──────────────────────┘
│ REST API (JSON + JWT)
▼
┌─────────────────────────────────────┐
│ FastAPI (Python) │
│ Auth · Tickets · Categories │
└──────────────┬──────────────────────┘
│ SQLAlchemy (async)
▼
┌─────────────────────────────────────┐
│ PostgreSQL 16 (Docker) │
└─────────────────────────────────────┘

## Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| Mobil İstemci | Swift, SwiftUI (iOS 17+) |
| Backend | Python 3.12, FastAPI |
| Veritabanı | PostgreSQL 16 |
| ORM / Migration | SQLAlchemy (async), Alembic |
| Kimlik Doğrulama | JWT (python-jose), bcrypt |
| Test | pytest |
| Ortam | Docker Compose |

## Klasör Yapısı
.
├── backend/ FastAPI uygulaması, veritabanı modelleri, migration'lar
├── ios/ SwiftUI mobil uygulama
└── docs/ Proje dokümantasyonu

## Kurulum

### Gereksinimler

- Python 3.12
- Docker Desktop
- Xcode 15+ (iOS geliştirme için, yalnızca macOS)

### Backend

```bash
cd backend

# Sanal ortam
python3.12 -m venv venv
source venv/bin/activate

# Bağımlılıklar
pip install -r requirements.txt

# Ortam değişkenleri
cp .env.example .env

# PostgreSQL'i başlat
docker compose up -d

# Veritabanı şemasını oluştur
alembic upgrade head

# Örnek veri (admin, temsilci, kategoriler)
PYTHONPATH=. python3 seed.py

# Sunucuyu çalıştır
uvicorn app.main:app --reload
```

API dokümantasyonu: http://localhost:8000/docs

### iOS

1. `ios/SikayetApp.xcodeproj` dosyasını Xcode ile aç
2. Bir simulator seç ve `Cmd + R` ile çalıştır

> **Not:** Geliştirme sırasında uygulama `http://localhost:8000` adresine bağlanır.
> iOS varsayılan olarak şifresiz HTTP bağlantılarını engellediği için proje ayarlarında
> `NSAppTransportSecurity → NSAllowsLocalNetworking` değeri `YES` olarak tanımlıdır.
> Gerçek cihazda test için `ios/SikayetApp/Networking/APIConfig.swift` içindeki adresi
> Mac'in yerel IP'si ile değiştirin ve backend'i `--host 0.0.0.0` ile başlatın.

## Örnek Hesaplar

`seed.py` çalıştırıldığında oluşur:

| Rol | E-posta | Şifre |
|---|---|---|
| Admin | admin@banka.com | Admin123! |
| Temsilci | agent@banka.com | Agent123! |
| Müşteri | Uygulamadan "Kayıt Ol" ile oluşturulur | — |

## Roller ve Yetkiler

| Rol | Yetkiler |
|---|---|
| **Müşteri** | Talep/şikayet oluşturur, yalnızca kendi kayıtlarını görüntüler ve takip eder |
| **Temsilci** | Havuzdaki kayıtları üzerine alır, inceler, not ekler, sonuçlandırır |
| **Admin** | Tüm kayıtları görür, kategori yönetir, raporlara erişir |

## Durum Akışı
Yeni → İnceleniyor → (Ek Bilgi Bekleniyor ↔ İnceleniyor) → Çözüldü / Reddedildi → Kapatıldı

Geçersiz durum geçişleri sunucu tarafında engellenir (HTTP 409).

## Veritabanı

7 tablo: `users`, `categories`, `tickets`, `ticket_notes`,
`ticket_status_history`, `ticket_attachments`, `notifications`

ER diyagramı ve tablo detayları için: [docs/](docs/)

## Test

```bash
cd backend
PYTHONPATH=. pytest tests/ -v
```

Kapsanan senaryolar: kayıt/giriş akışı, yetkisiz erişim (403),
eşzamanlı atama koruması (409), geçersiz durum geçişi (409),
dahili not gizliliği, sonuçlandırma doğrulaması (422).

## Güvenlik Yaklaşımı

- Şifreler bcrypt ile hash'lenir, düz metin saklanmaz
- Kimlik doğrulama JWT ile yapılır; access token kısa ömürlüdür, refresh token ile yenilenir
- iOS tarafında token'lar Keychain'de saklanır
- Her endpoint'te rol bazlı yetkilendirme (RBAC) uygulanır
- Müşteri yalnızca kendi kayıtlarına erişebilir; kontrol sunucu tarafında yapılır
- Kayıt sahipliği istemciden gelen veriye değil, token'daki kullanıcı kimliğine göre belirlenir

## Geliştirme Durumu

**Tamamlanan**

- Kimlik doğrulama (kayıt, giriş, token yenileme)
- Rol bazlı yetkilendirme
- Talep/şikayet oluşturma, listeleme, detay görüntüleme
- Kayıt havuzu, atama (eşzamanlılık korumalı)
- Durum yönetimi ve geçiş doğrulaması
- Not sistemi (müşteriye görünür / dahili ayrımı)
- Kategori yönetimi
- Rol bazlı mobil navigasyon ve tüm ekranlar

**Devam Eden**

- Dosya/fotoğraf yükleme
- Bildirim sistemi
- Kullanıcı yönetimi endpoint'leri
- Raporlama endpoint'leri
- Şifremi unuttum akışı
