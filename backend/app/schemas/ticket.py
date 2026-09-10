import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class TicketCreate(BaseModel):
    type: str = Field(pattern="^(request|complaint)$")
    category_id: uuid.UUID
    subject: str = Field(min_length=5, max_length=200)
    description: str = Field(min_length=20)


class TicketOut(BaseModel):
    id: uuid.UUID
    reference_no: str
    type: str
    subject: str
    description: str
    status: str
    priority: str
    category_id: uuid.UUID
    assigned_to: uuid.UUID | None
    created_at: datetime
    updated_at: datetime | None

    model_config = {"from_attributes": True}


class TicketStatusUpdate(BaseModel):
    new_status: str = Field(pattern="^(in_review|pending_info|resolved|rejected|closed)$")
    resolution_note: str | None = Field(default=None, min_length=20)


class TicketNoteCreate(BaseModel):
    content: str = Field(min_length=1)
    is_internal: bool = False


class TicketNoteOut(BaseModel):
    id: uuid.UUID
    author_id: uuid.UUID
    content: str
    is_internal: bool
    created_at: datetime

    model_config = {"from_attributes": True}
