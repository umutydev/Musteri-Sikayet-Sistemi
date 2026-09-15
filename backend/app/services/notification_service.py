"""
Bildirim olusturma mantigi tek yerde toplanir (FR-5.x).
Endpoint'ler dogrudan Notification nesnesi olusturmak yerine bu fonksiyonlari cagirir;
boylece bildirim metinleri ve kurallari tek noktadan yonetilir.
"""
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ticket import Ticket
from app.models.ticket_extras import Notification
from app.models.user import User

# Durum kodlarinin bildirim metinlerindeki Turkce karsiliklari.
# iOS tarafindaki TicketStatus.displayName ile ayni metinler kullanilir.
STATUS_LABELS = {
    "new": "Yeni",
    "in_review": "İnceleniyor",
    "pending_info": "Ek Bilgi Bekleniyor",
    "resolved": "Çözüldü",
    "rejected": "Reddedildi",
    "closed": "Kapatıldı",
}


async def notify_status_change(
    db: AsyncSession, ticket: Ticket, old_status: str | None, new_status: str
) -> None:
    """
    FR-5.2: Durum degistiginde kaydin sahibi musteriye bildirim olusturur.
    Not: commit cagirmaz - cagiran endpoint'in transaction'ina dahil olur.
    """
    label = STATUS_LABELS.get(new_status, new_status)
    message = f"{ticket.reference_no} numarali kaydinizin durumu \"{label}\" olarak guncellendi."

    db.add(
        Notification(
            user_id=ticket.customer_id,
            ticket_id=ticket.id,
            message=message,
        )
    )


async def notify_new_note(
    db: AsyncSession, ticket: Ticket, author: User, is_internal: bool
) -> None:
    """
    Musteriye gorunur bir yanit eklendiginde musteriyi bilgilendirir.
    Dahili notlar icin bildirim olusturulmaz (FR-4.4 gizlilik kurali).
    """
    if is_internal:
        return

    # Musteri kendi notunu eklediyse kendine bildirim gitmesin
    if author.id == ticket.customer_id:
        return

    message = f"{ticket.reference_no} numarali kaydiniza yeni bir yanit eklendi."
    db.add(
        Notification(
            user_id=ticket.customer_id,
            ticket_id=ticket.id,
            message=message,
        )
    )


async def notify_agents_new_ticket(db: AsyncSession, ticket: Ticket) -> None:
    """
    FR-5.1: Yeni kayit olustugunda ilgili temsilcilere bildirim duser.

    Ekip mantigi: kaydin kategorisi bir ekibe bagliysa yalnizca o ekibin uyeleri
    bilgilendirilir. Kategori bir ekibe bagli degilse, ekibi olmayan tum
    temsilciler bilgilendirilir (genel havuz).
    """
    from app.models.category import Category  # dairesel import olmamasi icin lokal

    category = await db.get(Category, ticket.category_id)
    team_id = category.team_id if category else None

    query = select(User).where(User.role == "agent", User.is_active.is_(True))
    if team_id is not None:
        query = query.where(User.team_id == team_id)

    result = await db.execute(query)
    agents = result.scalars().all()

    message = f"Havuza yeni bir kayit eklendi: {ticket.reference_no}"
    for agent in agents:
        db.add(
            Notification(
                user_id=agent.id,
                ticket_id=ticket.id,
                message=message,
            )
        )


async def notify_assignment(
    db: AsyncSession, ticket: Ticket, assignee_id: uuid.UUID
) -> None:
    """Bir kayit bir temsilciye atandiginda temsilciyi bilgilendirir."""
    message = f"{ticket.reference_no} numarali kayit size atandi."
    db.add(
        Notification(
            user_id=assignee_id,
            ticket_id=ticket.id,
            message=message,
        )
    )
