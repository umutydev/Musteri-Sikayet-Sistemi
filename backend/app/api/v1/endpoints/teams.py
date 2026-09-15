"""
Destek ekibi yonetimi.
Ekipler temsilcileri gruplar; kategoriler ekiplere baglanir.
Bir kayit olusturuldugunda, kategorisinin bagli oldugu ekibin temsilcileri
o kaydi havuzlarinda gorur (bkz. tickets.py::list_tickets).
"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.category import Category
from app.models.team import Team
from app.models.ticket import Ticket
from app.models.user import User
from app.schemas.team import (
    TeamCreate,
    TeamDetailOut,
    TeamMemberAssign,
    TeamMemberOut,
    TeamUpdate,
)

router = APIRouter(prefix="/teams", tags=["Teams"])

OPEN_STATUSES = ("new", "in_review", "pending_info")


async def _build_team_detail(db: AsyncSession, team: Team) -> TeamDetailOut:
    """Bir ekip icin uye sayisi, acik vaka sayisi ve kategori isimlerini hesaplar."""
    member_count_result = await db.execute(
        select(func.count()).select_from(User).where(User.team_id == team.id)
    )

    categories_result = await db.execute(
        select(Category.id, Category.name).where(Category.team_id == team.id)
    )
    category_rows = categories_result.all()
    category_ids = [row[0] for row in category_rows]
    category_names = [row[1] for row in category_rows]

    # Ekibin kategorilerindeki acik kayitlar
    active_count = 0
    if category_ids:
        ticket_count_result = await db.execute(
            select(func.count())
            .select_from(Ticket)
            .where(Ticket.category_id.in_(category_ids), Ticket.status.in_(OPEN_STATUSES))
        )
        active_count = ticket_count_result.scalar() or 0

    return TeamDetailOut(
        id=team.id,
        name=team.name,
        description=team.description,
        is_active=team.is_active,
        member_count=member_count_result.scalar() or 0,
        active_ticket_count=active_count,
        category_names=category_names,
    )


@router.get("", response_model=list[TeamDetailOut])
async def list_teams(
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    """Ekipleri, uye ve acik vaka sayilariyla birlikte listeler."""
    result = await db.execute(select(Team).order_by(Team.name))
    teams = result.scalars().all()
    return [await _build_team_detail(db, team) for team in teams]


@router.post("", response_model=TeamDetailOut, status_code=status.HTTP_201_CREATED)
async def create_team(
    payload: TeamCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    existing = await db.execute(select(Team).where(Team.name == payload.name))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Bu isimde bir ekip zaten var")

    team = Team(name=payload.name, description=payload.description)
    db.add(team)
    await db.commit()
    await db.refresh(team)
    return await _build_team_detail(db, team)


@router.get("/{team_id}/members", response_model=list[TeamMemberOut])
async def list_team_members(
    team_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    team = await db.get(Team, team_id)
    if team is None:
        raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    result = await db.execute(
        select(User).where(User.team_id == team_id).order_by(User.full_name)
    )
    return result.scalars().all()


@router.post("/{team_id}/members", response_model=TeamMemberOut)
async def add_team_member(
    team_id: uuid.UUID,
    payload: TeamMemberAssign,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """Bir temsilciyi ekibe ekler. Kullanici baska bir ekipteyse o ekipten cikarilir."""
    team = await db.get(Team, team_id)
    if team is None:
        raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    user = await db.get(User, payload.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Kullanici bulunamadi")

    # Ekipler destek temsilcileri icindir; musteri bir ekibe atanamaz
    if user.role == "customer":
        raise HTTPException(status_code=400, detail="Musteri bir ekibe atanamaz")

    user.team_id = team_id
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{team_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_team_member(
    team_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    user = await db.get(User, user_id)
    if user is None or user.team_id != team_id:
        raise HTTPException(status_code=404, detail="Bu ekipte boyle bir uye yok")

    user.team_id = None
    await db.commit()


@router.patch("/{team_id}", response_model=TeamDetailOut)
async def update_team(
    team_id: uuid.UUID,
    payload: TeamUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    team = await db.get(Team, team_id)
    if team is None:
        raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    if payload.name is not None:
        team.name = payload.name
    if payload.description is not None:
        team.description = payload.description
    if payload.is_active is not None:
        team.is_active = payload.is_active

    await db.commit()
    await db.refresh(team)
    return await _build_team_detail(db, team)


@router.delete("/{team_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_team(
    team_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """
    Ekibi siler. Once uyelerin ve kategorilerin baglantisi kaldirilir
    (foreign key ihlali olmamasi icin).
    """
    team = await db.get(Team, team_id)
    if team is None:
        raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    members = await db.execute(select(User).where(User.team_id == team_id))
    for member in members.scalars().all():
        member.team_id = None

    categories = await db.execute(select(Category).where(Category.team_id == team_id))
    for category in categories.scalars().all():
        category.team_id = None

    await db.delete(team)
    await db.commit()
