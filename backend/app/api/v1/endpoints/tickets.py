import random
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.category import Category
from app.models.ticket import VALID_TRANSITIONS, Ticket
from app.models.ticket_extras import TicketNote, TicketStatusHistory
from app.models.user import User
from app.schemas.ticket import (
    TicketCreate,
    TicketNoteCreate,
    TicketNoteOut,
    TicketOut,
    TicketStatusUpdate,
)
from app.services import email_service, notification_service

router = APIRouter(prefix="/tickets", tags=["Tickets"])


def _generate_reference_no() -> str:
    year = datetime.now(timezone.utc).year
    rand_part = random.randint(100000, 999999)
    return f"TSK-{year}-{rand_part}"


@router.post("", response_model=TicketOut, status_code=status.HTTP_201_CREATED)
async def create_ticket(
    payload: TicketCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("customer")),
):
    """FR-2: Musteri yeni talep/sikayet olusturur (US-03)."""
    ticket = Ticket(
        reference_no=_generate_reference_no(),
        customer_id=current_user.id,
        category_id=payload.category_id,
        type=payload.type,
        subject=payload.subject,
        description=payload.description,
        status="new",
    )
    db.add(ticket)
    await db.flush()

    db.add(TicketStatusHistory(
        ticket_id=ticket.id, old_status=None, new_status="new", changed_by=current_user.id,
    ))

    # FR-5.1: havuzdaki temsilcilere yeni kayit bildirimi
    await notification_service.notify_agents_new_ticket(db, ticket)

    await db.commit()
    await db.refresh(ticket)

    # Basvuru alindi e-postasi (EMAIL_BACKEND=console ise yalnizca loglanir)
    await email_service.send_ticket_created(
        to=current_user.email, reference_no=ticket.reference_no, subject_line=ticket.subject
    )
    return ticket


@router.get("", response_model=list[TicketOut])
async def list_tickets(
    status_filter: str | None = Query(default=None, alias="status"),
    category_id: uuid.UUID | None = None,
    pool: bool = Query(default=False, description="agent icin: atanmamis havuz kayitlari"),
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Yetki kapsami (bkz. 07-rest-api-tasarimi.md):
    - customer -> sadece kendi kayitlari
    - agent    -> kendisine atananlar + (pool=true ise) ekibinin havuzu
    - admin    -> tum kayitlar

    Ekip mantigi: temsilci bir ekibe atanmissa, havuzda yalnizca kendi ekibine
    bagli kategorilerdeki kayitlari gorur. Ekibi yoksa tum havuzu gorur
    (geriye donuk uyumluluk - ekip tanimlanmadan once olusturulmus hesaplar icin).
    """
    query = select(Ticket)

    if current_user.role == "customer":
        query = query.where(Ticket.customer_id == current_user.id)
    elif current_user.role == "agent":
        if pool:
            query = query.where(Ticket.assigned_to.is_(None), Ticket.status == "new")

            if current_user.team_id is not None:
                # Ekibin sorumlu oldugu kategoriler + hicbir ekibe atanmamis kategoriler
                team_categories = select(Category.id).where(
                    (Category.team_id == current_user.team_id) | (Category.team_id.is_(None))
                )
                query = query.where(Ticket.category_id.in_(team_categories))
        else:
            query = query.where(Ticket.assigned_to == current_user.id)
    # admin -> filtre yok, tum kayitlar

    if status_filter:
        query = query.where(Ticket.status == status_filter)
    if category_id:
        query = query.where(Ticket.category_id == category_id)

    query = query.order_by(Ticket.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{ticket_id}", response_model=TicketOut)
async def get_ticket(
    ticket_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = await db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Kayit bulunamadi")

    # FR-7.1: musteri sadece kendi kaydini gorebilir
    if current_user.role == "customer" and ticket.customer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu kayda erisim yetkiniz yok")

    return ticket


@router.post("/{ticket_id}/assign", response_model=TicketOut)
async def assign_ticket(
    ticket_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("agent", "admin")),
):
    """
    US-06: Temsilci havuzdan kaydi uzerine alir.
    Race condition korumasi: WHERE assigned_to IS NULL sarti ile atomik guncelleme (TC-31).
    """
    result = await db.execute(
        update(Ticket)
        .where(Ticket.id == ticket_id, Ticket.assigned_to.is_(None))
        .values(assigned_to=current_user.id, status="in_review")
        .returning(Ticket)
    )
    ticket = result.scalar_one_or_none()
    if ticket is None:
        raise HTTPException(status_code=409, detail="Bu kayit zaten baskasina atanmis")

    db.add(TicketStatusHistory(
        ticket_id=ticket.id, old_status="new", new_status="in_review", changed_by=current_user.id,
    ))

    # FR-5.2: musteriye durum degisikligi bildirimi
    await notification_service.notify_status_change(db, ticket, "new", "in_review")

    await db.commit()
    await db.refresh(ticket)
    return ticket


@router.patch("/{ticket_id}/status", response_model=TicketOut)
async def update_status(
    ticket_id: uuid.UUID,
    payload: TicketStatusUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("agent", "admin")),
):
    """FR-4.6 / FR-4.7: durum gecisi, state machine'e gore dogrulanir (TC-32)."""
    ticket = await db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Kayit bulunamadi")

    allowed_next = VALID_TRANSITIONS.get(ticket.status, set())
    if payload.new_status not in allowed_next:
        raise HTTPException(
            status_code=409,
            detail=f"Gecersiz durum gecisi: {ticket.status} -> {payload.new_status}",
        )

    if payload.new_status in ("resolved", "rejected") and not payload.resolution_note:
        raise HTTPException(
            status_code=422, detail="Sonuclandirma icin resolution_note zorunludur (min 20 karakter)"
        )

    old_status = ticket.status
    ticket.status = payload.new_status
    if payload.resolution_note:
        ticket.resolution_note = payload.resolution_note
    if payload.new_status in ("resolved", "rejected"):
        ticket.resolved_at = datetime.now(timezone.utc)
    if payload.new_status == "closed":
        ticket.closed_at = datetime.now(timezone.utc)

    db.add(TicketStatusHistory(
        ticket_id=ticket.id, old_status=old_status, new_status=payload.new_status,
        changed_by=current_user.id,
    ))

    # FR-5.2: musteriye durum degisikligi bildirimi
    await notification_service.notify_status_change(db, ticket, old_status, payload.new_status)

    await db.commit()
    await db.refresh(ticket)

    # Durum degisikligi e-postasi - musterinin adresini ayrica cekiyoruz
    customer = await db.get(User, ticket.customer_id)
    if customer is not None:
        await email_service.send_status_changed(
            to=customer.email,
            reference_no=ticket.reference_no,
            status_label=notification_service.STATUS_LABELS.get(
                payload.new_status, payload.new_status
            ),
            resolution_note=payload.resolution_note,
        )
    return ticket


@router.post("/{ticket_id}/notes", response_model=TicketNoteOut, status_code=status.HTTP_201_CREATED)
async def add_note(
    ticket_id: uuid.UUID,
    payload: TicketNoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """FR-4.4 / FR-4.5: musteriye gorunur veya dahili not eklenir."""
    ticket = await db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Kayit bulunamadi")

    # Musteri sadece kendi kaydina, ve sadece musteriye-gorunur (is_internal=False) not ekleyebilir
    if current_user.role == "customer":
        if ticket.customer_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bu kayda erisim yetkiniz yok")
        if payload.is_internal:
            raise HTTPException(status_code=403, detail="Musteri dahili not ekleyemez")

    note = TicketNote(
        ticket_id=ticket_id,
        author_id=current_user.id,
        content=payload.content,
        is_internal=payload.is_internal,
    )
    db.add(note)

    # Musteriye gorunur bir yanit eklendiyse musteriyi bilgilendir (dahili notlarda bildirim yok)
    await notification_service.notify_new_note(db, ticket, current_user, payload.is_internal)

    await db.commit()
    await db.refresh(note)
    return note


@router.get("/{ticket_id}/notes", response_model=list[TicketNoteOut])
async def list_notes(
    ticket_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(TicketNote).where(TicketNote.ticket_id == ticket_id)

    # FR-4.4: dahili notlar sadece personele (agent/admin) gorunur
    if current_user.role == "customer":
        query = query.where(TicketNote.is_internal.is_(False))

    query = query.order_by(TicketNote.created_at.asc())
    result = await db.execute(query)
    return result.scalars().all()
