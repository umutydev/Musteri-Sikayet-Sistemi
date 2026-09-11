"""
Dosya eki yukleme ve listeleme (FR-2.4).
v1'de dosyalar yerel diske kaydedilir (UPLOAD_DIR). Production'da S3 benzeri
bir obje deposuna tasinmasi onerilir - sadece storage katmani degisir.
"""
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.models.ticket import Ticket
from app.models.ticket_extras import TicketAttachment
from app.models.user import User
from app.schemas.attachment import AttachmentOut

router = APIRouter(prefix="/tickets", tags=["Attachments"])

MAX_ATTACHMENTS_PER_TICKET = 5
ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "application/pdf": ".pdf",
}


async def _get_ticket_with_access_check(
    ticket_id: uuid.UUID, db: AsyncSession, current_user: User
) -> Ticket:
    """Kaydi getirir ve erisim yetkisini dogrular (FR-7.1)."""
    ticket = await db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Kayit bulunamadi")
    if current_user.role == "customer" and ticket.customer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu kayda erisim yetkiniz yok")
    return ticket


@router.post(
    "/{ticket_id}/attachments",
    response_model=AttachmentOut,
    status_code=status.HTTP_201_CREATED,
)
async def upload_attachment(
    ticket_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    FR-2.4: Kayda dosya eki yukler.
    Kisitlar: en fazla 5 dosya, tek dosya <= 10MB, sadece jpg/png/pdf.
    """
    ticket = await _get_ticket_with_access_check(ticket_id, db, current_user)

    # Kapali kayda ek dosya yuklenemez
    if ticket.status == "closed":
        raise HTTPException(status_code=409, detail="Kapatilmis kayda dosya eklenemez")

    # Format kontrolu (TC-14)
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Desteklenmeyen dosya formati. Yalnizca JPG, PNG ve PDF yuklenebilir.",
        )

    # Adet kontrolu (TC-13)
    count_result = await db.execute(
        select(func.count()).select_from(TicketAttachment).where(
            TicketAttachment.ticket_id == ticket_id
        )
    )
    if (count_result.scalar() or 0) >= MAX_ATTACHMENTS_PER_TICKET:
        raise HTTPException(
            status_code=400,
            detail=f"En fazla {MAX_ATTACHMENTS_PER_TICKET} dosya eklenebilir",
        )

    # Boyut kontrolu (TC-15) - dosyayi belleğe okuyup olcuyoruz
    contents = await file.read()
    max_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"Dosya boyutu {settings.MAX_UPLOAD_SIZE_MB}MB'i asamaz",
        )

    # Diske kaydet - cakismayi onlemek icin UUID tabanli ad uretiyoruz
    upload_dir = Path(settings.UPLOAD_DIR) / str(ticket_id)
    upload_dir.mkdir(parents=True, exist_ok=True)

    extension = ALLOWED_CONTENT_TYPES[file.content_type]
    stored_name = f"{uuid.uuid4()}{extension}"
    file_path = upload_dir / stored_name
    file_path.write_bytes(contents)

    attachment = TicketAttachment(
        ticket_id=ticket_id,
        file_url=str(file_path),
        file_name=file.filename or stored_name,
        content_type=file.content_type,
        uploaded_by=current_user.id,
    )
    db.add(attachment)
    await db.commit()
    await db.refresh(attachment)
    return attachment


@router.get("/{ticket_id}/attachments", response_model=list[AttachmentOut])
async def list_attachments(
    ticket_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _get_ticket_with_access_check(ticket_id, db, current_user)
    result = await db.execute(
        select(TicketAttachment)
        .where(TicketAttachment.ticket_id == ticket_id)
        .order_by(TicketAttachment.uploaded_at.asc())
    )
    return result.scalars().all()


@router.get("/{ticket_id}/attachments/{attachment_id}/download")
async def download_attachment(
    ticket_id: uuid.UUID,
    attachment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Dosyayi indirir. Yetki kontrolu yine kayit sahipligi uzerinden yapilir."""
    await _get_ticket_with_access_check(ticket_id, db, current_user)

    attachment = await db.get(TicketAttachment, attachment_id)
    if attachment is None or attachment.ticket_id != ticket_id:
        raise HTTPException(status_code=404, detail="Dosya bulunamadi")

    path = Path(attachment.file_url)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dosya diskte bulunamadi")

    return FileResponse(
        path=path, filename=attachment.file_name, media_type=attachment.content_type
    )
