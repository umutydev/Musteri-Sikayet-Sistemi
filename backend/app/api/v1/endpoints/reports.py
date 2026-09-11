"""
Raporlama uclari (FR-6.1, FR-6.2, FR-6.3).
Yalnizca admin erisebilir. Hesaplamalar veritabaninda (SQL) yapilir,
tum kayitlari cekip Python'da saymak yerine - buyuk veri setlerinde fark yaratir.
"""
from sqlalchemy import Float, case, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from fastapi import APIRouter, Depends

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.category import Category
from app.models.ticket import Ticket
from app.models.user import User
from app.schemas.report import (
    AgentPerformanceOut,
    CategoryBreakdownOut,
    StatusBreakdownOut,
    SummaryOut,
)

router = APIRouter(prefix="/reports", tags=["Reports"])

OPEN_STATUSES = ("new", "in_review", "pending_info")
CLOSED_STATUSES = ("resolved", "rejected", "closed")


@router.get("/summary", response_model=SummaryOut)
async def summary(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """
    FR-6.1 + FR-6.3: Acik/kapali kayit sayilari, durum ve kategori dagilimi,
    ortalama cozum suresi.
    """
    # Durum bazinda sayim - tek sorguda
    status_result = await db.execute(
        select(Ticket.status, func.count(Ticket.id)).group_by(Ticket.status)
    )
    status_counts = {row[0]: row[1] for row in status_result.all()}

    total = sum(status_counts.values())
    open_count = sum(status_counts.get(s, 0) for s in OPEN_STATUSES)
    closed_count = sum(status_counts.get(s, 0) for s in CLOSED_STATUSES)
    unassigned_count = status_counts.get("new", 0)

    status_breakdown = [
        StatusBreakdownOut(status=status, count=count)
        for status, count in sorted(status_counts.items())
    ]

    # Kategori dagilimi - LEFT JOIN, kaydi olmayan kategoriler de 0 ile gorunur
    category_result = await db.execute(
        select(Category.name, func.count(Ticket.id))
        .select_from(Category)
        .outerjoin(Ticket, Ticket.category_id == Category.id)
        .group_by(Category.name)
        .order_by(func.count(Ticket.id).desc())
    )
    category_breakdown = [
        CategoryBreakdownOut(category=row[0], count=row[1]) for row in category_result.all()
    ]

    # Ortalama cozum suresi (gun) - yalnizca sonuclanmis kayitlar
    avg_result = await db.execute(
        select(
            func.avg(
                cast(func.extract("epoch", Ticket.resolved_at - Ticket.created_at), Float)
            )
        ).where(Ticket.resolved_at.isnot(None))
    )
    avg_seconds = avg_result.scalar()
    avg_days = round(avg_seconds / 86400, 1) if avg_seconds else None

    return SummaryOut(
        total_tickets=total,
        open_tickets=open_count,
        closed_tickets=closed_count,
        unassigned_tickets=unassigned_count,
        avg_resolution_days=avg_days,
        status_breakdown=status_breakdown,
        category_breakdown=category_breakdown,
    )


@router.get("/agent-performance", response_model=list[AgentPerformanceOut])
async def agent_performance(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """
    FR-6.2: Temsilci bazinda atanan/cozulen kayit sayisi ve ortalama cozum suresi.
    Hic kaydi olmayan temsilciler de listede 0 degerleriyle yer alir.
    """
    result = await db.execute(
        select(
            User.id,
            User.full_name,
            func.count(Ticket.id).label("assigned"),
            func.sum(case((Ticket.status.in_(CLOSED_STATUSES), 1), else_=0)).label("closed"),
            func.avg(
                cast(func.extract("epoch", Ticket.resolved_at - Ticket.created_at), Float)
            ).label("avg_seconds"),
        )
        .select_from(User)
        .outerjoin(Ticket, Ticket.assigned_to == User.id)
        .where(User.role == "agent")
        .group_by(User.id, User.full_name)
        .order_by(func.count(Ticket.id).desc())
    )

    output: list[AgentPerformanceOut] = []
    for row in result.all():
        avg_seconds = row.avg_seconds
        output.append(
            AgentPerformanceOut(
                agent_id=row.id,
                agent_name=row.full_name,
                assigned_count=row.assigned or 0,
                closed_count=int(row.closed or 0),
                avg_resolution_days=round(avg_seconds / 86400, 1) if avg_seconds else None,
            )
        )
    return output
