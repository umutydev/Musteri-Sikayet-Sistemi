import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class PasswordResetToken(Base):
    """
    Sifre sifirlama kodu (FR-1.3).

    Guvenlik notlari:
    - Kodun kendisi degil, SHA-256 ozeti saklanir. Veritabani sizsa bile
      kodlar kullanilamaz (sifrelerde bcrypt kullanmamizla ayni mantik).
    - Kod tek kullanimliktir; kullanilinca is_used=True yapilir.
    - 15 dakika sonra gecersiz olur.
    """

    __tablename__ = "password_reset_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
