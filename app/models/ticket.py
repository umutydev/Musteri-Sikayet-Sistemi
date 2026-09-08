import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base

# Durum degerleri (state machine) - bkz. 02-fonksiyonel-gereksinimler.md
TICKET_STATUSES = ("new", "in_review", "pending_info", "resolved", "rejected", "closed")
TICKET_TYPES = ("request", "complaint")
TICKET_PRIORITIES = ("low", "medium", "high")

# Gecerli durum gecisleri (FR-4.7)
VALID_TRANSITIONS: dict[str, set[str]] = {
    "new": {"in_review"},
    "in_review": {"pending_info", "resolved", "rejected"},
    "pending_info": {"in_review"},
    "resolved": {"closed"},
    "rejected": {"closed"},
    "closed": set(),  # terminal durum
}


class Ticket(Base):
    __tablename__ = "tickets"
    __table_args__ = (
        CheckConstraint(f"status IN {TICKET_STATUSES}", name="ck_tickets_status"),
        CheckConstraint(f"type IN {TICKET_TYPES}", name="ck_tickets_type"),
        CheckConstraint(f"priority IN {TICKET_PRIORITIES}", name="ck_tickets_priority"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reference_no: Mapped[str] = mapped_column(String(30), unique=True, index=True, nullable=False)
    customer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    category_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"))
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    subject: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="new", index=True)
    priority: Mapped[str] = mapped_column(String(10), nullable=False, default="medium")
    assigned_to: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True
    )
    resolution_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), onupdate=func.now())
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
