import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.category import Category
from app.models.team import Team
from app.models.user import User

router = APIRouter(prefix="/categories", tags=["Categories"])


class CategoryCreate(BaseModel):
    name: str
    description: str | None = None
    team_id: uuid.UUID | None = None


class CategoryUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    is_active: bool | None = None
    team_id: uuid.UUID | None = None


class CategoryOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    is_active: bool
    team_id: uuid.UUID | None

    model_config = {"from_attributes": True}


@router.get("", response_model=list[CategoryOut])
async def list_categories(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Category).where(Category.is_active.is_(True)))
    return result.scalars().all()


@router.post("", response_model=CategoryOut, status_code=201)
async def create_category(
    payload: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    if payload.team_id is not None:
        team = await db.get(Team, payload.team_id)
        if team is None:
            raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    category = Category(
        name=payload.name, description=payload.description, team_id=payload.team_id
    )
    db.add(category)
    await db.commit()
    await db.refresh(category)
    return category


@router.patch("/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: uuid.UUID,
    payload: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """Kategoriyi gunceller. team_id degistirilerek kategori baska bir ekibe devredilebilir."""
    category = await db.get(Category, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="Kategori bulunamadi")

    if payload.team_id is not None:
        team = await db.get(Team, payload.team_id)
        if team is None:
            raise HTTPException(status_code=404, detail="Ekip bulunamadi")

    if payload.name is not None:
        category.name = payload.name
    if payload.description is not None:
        category.description = payload.description
    if payload.is_active is not None:
        category.is_active = payload.is_active
    # team_id icin None anlamli bir deger (ekipten cikarma), bu yuzden
    # payload'da alanin gonderilip gonderilmedigini kontrol ediyoruz
    if "team_id" in payload.model_fields_set:
        category.team_id = payload.team_id

    await db.commit()
    await db.refresh(category)
    return category
