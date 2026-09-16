"""
Uygulama genelindeki ayarlar. .env dosyasindan okunur (pydantic-settings).
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "Bankacilik Talep ve Sikayet Sistemi"
    API_V1_PREFIX: str = "/api/v1"
    ENV: str = "development"

    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/sikayet_db"

    JWT_SECRET_KEY: str = "change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_SIZE_MB: int = 10

    # --- E-posta ---
    # "console" : e-postalar gonderilmez, sunucu loguna yazilir (gelistirme)
    # "smtp"    : gercek e-posta gonderilir (asagidaki SMTP ayarlari gerekir)
    EMAIL_BACKEND: str = "console"

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""        # Gmail icin "uygulama sifresi", normal sifre calismaz
    EMAIL_FROM: str = ""           # Bos birakilirsa SMTP_USER kullanilir
    EMAIL_FROM_NAME: str = "Banka Destek"


settings = Settings()
