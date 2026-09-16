import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models.password_reset import PasswordResetToken
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserOut,
)
from app.services import email_service

router = APIRouter(prefix="/auth", tags=["Auth"])

# Sifirlama kodunun gecerlilik suresi
RESET_CODE_TTL_MINUTES = 15


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Bu e-posta zaten kayitli")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        password_hash=hash_password(payload.password),
        role="customer",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Guvenlik: hangi alanin yanlis oldugunu belirtme (US-02 acceptance criteria)
    invalid_credentials = HTTPException(status_code=401, detail="E-posta veya sifre hatali")
    if user is None or not verify_password(payload.password, user.password_hash):
        raise invalid_credentials
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Hesabiniz pasif durumda")

    access_token = create_access_token(subject=str(user.id), role=user.role)
    refresh_token = create_refresh_token(subject=str(user.id))
    return TokenResponse(access_token=access_token, refresh_token=refresh_token, user=user)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    data = decode_token(payload.refresh_token)
    if data is None or data.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Gecersiz refresh token")

    result = await db.execute(select(User).where(User.id == uuid.UUID(data["sub"])))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Kullanici bulunamadi veya pasif")

    access_token = create_access_token(subject=str(user.id), role=user.role)
    new_refresh_token = create_refresh_token(subject=str(user.id))
    return TokenResponse(access_token=access_token, refresh_token=new_refresh_token, user=user)


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
async def forgot_password(payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    FR-1.3: Sifre sifirlama kodu uretir.

    Guvenlik: e-posta kayitli olmasa bile ayni yanit doner (user enumeration onlemi).
    Kod veritabaninda duz metin degil, SHA-256 ozeti olarak saklanir.

    NOT: E-posta servisi henuz entegre edilmedi. Gelistirme ortaminda kod
    yanitta debug_code alaninda doner; production'da bu alan None olur ve
    kod e-posta ile gonderilir.
    """
    generic_response = ForgotPasswordResponse(
        message="Eger bu e-posta sistemde kayitliysa, sifirlama kodu gonderildi."
    )

    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        return generic_response

    # Onceki kullanilmamis kodlari gecersiz kil - ayni anda birden fazla
    # gecerli kod olmasin
    await db.execute(
        sa_update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.is_used.is_(False))
        .values(is_used=True)
    )

    code = f"{secrets.randbelow(1_000_000):06d}"
    token = PasswordResetToken(
        user_id=user.id,
        code_hash=hashlib.sha256(code.encode()).hexdigest(),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=RESET_CODE_TTL_MINUTES),
    )
    db.add(token)
    await db.commit()

    # FR-1.3: kodu e-posta ile gonder.
    # EMAIL_BACKEND=console ise sunucu loguna yazilir, gercek e-posta gitmez.
    await email_service.send_password_reset_code(to=user.email, code=code)

    if settings.ENV == "development":
        generic_response.debug_code = code
    return generic_response


@router.post("/reset-password", response_model=UserOut)
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    FR-1.3: Kodu dogrulayip yeni sifreyi kaydeder.
    Kod tek kullanimliktir ve 15 dakika sonra gecersiz olur.
    """
    invalid = HTTPException(status_code=400, detail="Kod gecersiz veya suresi dolmus")

    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise invalid

    code_hash = hashlib.sha256(payload.code.encode()).hexdigest()
    token_result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.code_hash == code_hash,
            PasswordResetToken.is_used.is_(False),
        )
    )
    token = token_result.scalar_one_or_none()
    if token is None:
        raise invalid

    # SQLite timezone bilgisini saklamaz, PostgreSQL saklar. Her iki ortamda da
    # dogru calismasi icin naive gelen degeri UTC kabul ediyoruz.
    expires_at = token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise invalid

    user.password_hash = hash_password(payload.new_password)
    token.is_used = True
    await db.commit()
    await db.refresh(user)
    return user
