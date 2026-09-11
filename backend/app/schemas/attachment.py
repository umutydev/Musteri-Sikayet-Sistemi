import uuid
from datetime import datetime

from pydantic import BaseModel


class AttachmentOut(BaseModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    file_name: str
    content_type: str
    uploaded_by: uuid.UUID
    uploaded_at: datetime

    # Not: file_url (diskteki gercek yol) BILEREK disari verilmiyor.
    # Dosyaya erisim /attachments/{id}/download ucu uzerinden, yetki kontrolu ile yapilir.

    model_config = {"from_attributes": True}
