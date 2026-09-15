import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    """Admin'in yeni temsilci/admin olustururken gonderdigi govde."""
    full_name: str = Field(min_length=2, max_length=150)
    email: EmailStr
    phone: str | None = None
    password: str = Field(min_length=8, max_length=72)
    role: str = Field(pattern="^(customer|agent|admin)$")


class UserUpdate(BaseModel):
    """Admin'in bir kullaniciyi guncellerken gonderdigi govde. Tum alanlar opsiyonel."""
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    phone: str | None = None
    role: str | None = Field(default=None, pattern="^(customer|agent|admin)$")
    is_active: bool | None = None
    team_id: uuid.UUID | None = None


class UserSelfUpdate(BaseModel):
    """
    Kullanicinin kendi profilini guncellerken gonderdigi govde.
    role ve is_active BILEREK yok - kullanici kendini admin yapamasin.
    """
    full_name: str | None = Field(default=None, min_length=2, max_length=150)
    phone: str | None = None


class UserDetailOut(BaseModel):
    """Admin listelerinde donen detayli kullanici bilgisi. password_hash asla yok."""
    id: uuid.UUID
    full_name: str
    email: EmailStr
    phone: str | None
    role: str
    is_active: bool
    team_id: uuid.UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}
