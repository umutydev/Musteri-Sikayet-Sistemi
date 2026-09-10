import uuid

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.category import Category
from app.models.user import User

router = APIRouter(prefix="/categories", tags=["Categories"])


class CategoryCreate(BaseModel):
    name: str
    description: str | None = None


class CategoryOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    is_active: bool

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
    category = Category(name=payload.name, description=payload.description)
    db.add(category)
    await db.commit()
    await db.refresh(category)
    return category
