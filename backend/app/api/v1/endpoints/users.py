"""
Kullanici yonetimi (FR-1.5, FR-1.6, US-09).
Admin: temsilci/admin hesabi olusturur, rolleri ve aktiflik durumunu yonetir.
Tum kullanicilar: kendi profilini guncelleyebilir.
"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.core.security import hash_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import (
    UserCreate,
    UserDetailOut,
    UserSelfUpdate,
    UserUpdate,
)

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", response_model=list[UserDetailOut])
async def list_users(
    role: str | None = Query(default=None, description="customer | agent | admin"),
    is_active: bool | None = None,
    search: str | None = Query(default=None, description="ad veya e-postada arama"),
    page: int = 1,
    page_size: int = 50,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """FR-1.5: Admin tum kullanicilari listeler, rol/durum/arama ile filtreler."""
    query = select(User)

    if role:
        query = query.where(User.role == role)
    if is_active is not None:
        query = query.where(User.is_active.is_(is_active))
    if search:
        pattern = f"%{search}%"
        query = query.where(User.full_name.ilike(pattern) | User.email.ilike(pattern))

    query = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return result.scalars().all()


@router.post("", response_model=UserDetailOut, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    """FR-1.5: Admin yeni temsilci veya admin hesabi olusturur."""
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Bu e-posta zaten kayitli")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.patch("/me", response_model=UserDetailOut)
async def update_own_profile(
    payload: UserSelfUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    FR-1.6: Kullanici kendi profilini gunceller.
    Rol ve aktiflik durumu BURADAN degistirilemez - yetki yukseltmeyi onler.
    """
    if payload.full_name is not None:
        current_user.full_name = payload.full_name
    if payload.phone is not None:
        current_user.phone = payload.phone

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.get("/{user_id}", response_model=UserDetailOut)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_roles("admin")),
):
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Kullanici bulunamadi")
    return user


@router.patch("/{user_id}", response_model=UserDetailOut)
async def update_user(
    user_id: uuid.UUID,
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(require_roles("admin")),
):
    """
    FR-1.5: Admin kullanici bilgisini/rolunu/durumunu gunceller.
    Guvenlik: admin kendi hesabini pasiflestiremez veya rolunu dusuremez
    (sistemde admin kalmama riskine karsi).
    """
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Kullanici bulunamadi")

    if user.id == current_admin.id:
        if payload.is_active is False:
            raise HTTPException(status_code=400, detail="Kendi hesabinizi pasiflestiremezsiniz")
        if payload.role is not None and payload.role != "admin":
            raise HTTPException(status_code=400, detail="Kendi rolunuzu degistiremezsiniz")

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.phone is not None:
        user.phone = payload.phone
    if payload.role is not None:
        user.role = payload.role
    if payload.is_active is not None:
        user.is_active = payload.is_active
    # team_id icin None anlamli bir deger (ekipten cikarma), bu yuzden
    # alanin gonderilip gonderilmedigini kontrol ediyoruz
    if "team_id" in payload.model_fields_set:
        user.team_id = payload.team_id

    await db.commit()
    await db.refresh(user)
    return user
