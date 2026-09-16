"""
E-posta gonderim servisi.

Iki farkli "backend" destekler, .env'deki EMAIL_BACKEND ayariyla secilir:
  - console : e-posta gonderilmez, icerigi sunucu loguna yazar (gelistirme)
  - smtp    : gercek SMTP sunucusu uzerinden gonderir (Gmail, kurumsal sunucu vb.)

Neden boyle: gelistirme sirasinda her testte gercek e-posta gitmesini istemiyoruz.
Gonderim mantigini tek bir arayuz (send_email) arkasina aldik; cagiran kod hangi
yontemin kullanildigini bilmek zorunda degil.

Gonderim ASENKRON ve HATA TOLERANSLIDIR: e-posta gonderilemezse istisna firlatmaz,
yalnizca loglar. Boylece SMTP sunucusu cokse bile kullanici sifre sifirlama
veya kayit olusturma islemini tamamlayabilir.
"""
import asyncio
import logging
import smtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


def _send_via_console(to: str, subject: str, body: str) -> None:
    logger.info(
        "\n%s\n[E-POSTA - konsol modu]\nKime : %s\nKonu : %s\n\n%s\n%s",
        "=" * 60, to, subject, body, "=" * 60,
    )


def _send_via_smtp(to: str, subject: str, body: str) -> None:
    """
    Senkron SMTP gonderimi. send_email() bunu ayri bir thread'de calistirir,
    boylece agi bekleyen bu islem FastAPI'nin olay dongusunu bloklamaz.
    """
    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        logger.error("SMTP kullanici adi veya sifresi tanimli degil, e-posta gonderilemedi")
        return

    sender = settings.EMAIL_FROM or settings.SMTP_USER

    message = EmailMessage()
    message["From"] = f"{settings.EMAIL_FROM_NAME} <{sender}>"
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body)

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as smtp:
        smtp.starttls()  # baglantiyi sifrele
        smtp.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        smtp.send_message(message)

    logger.info("E-posta gonderildi: %s (%s)", to, subject)


async def send_email(to: str, subject: str, body: str) -> None:
    """
    E-postayi yapilandirilmis yontemle gonderir.
    Hata durumunda istisna firlatmaz - yalnizca loglar (bkz. modul aciklamasi).
    """
    try:
        if settings.EMAIL_BACKEND == "smtp":
            # Bloklayan SMTP cagrisini thread havuzuna atiyoruz
            await asyncio.to_thread(_send_via_smtp, to, subject, body)
        else:
            _send_via_console(to, subject, body)
    except Exception:
        logger.exception("E-posta gonderilemedi: %s", to)


# --------------------------------------------------------------------------
# Hazir e-posta sablonlari
# Metinler tek yerde toplanir; ileride HTML sablona gecilirse burasi degisir.
# --------------------------------------------------------------------------

async def send_password_reset_code(to: str, code: str) -> None:
    await send_email(
        to=to,
        subject="Sifre Sifirlama Kodunuz",
        body=(
            f"Merhaba,\n\n"
            f"Sifre sifirlama kodunuz: {code}\n\n"
            f"Bu kod 15 dakika boyunca gecerlidir ve yalnizca bir kez kullanilabilir.\n"
            f"Eger bu talebi siz olusturmadiysaniz bu e-postayi dikkate almayiniz.\n\n"
            f"{settings.EMAIL_FROM_NAME}"
        ),
    )


async def send_ticket_created(to: str, reference_no: str, subject_line: str) -> None:
    await send_email(
        to=to,
        subject=f"Basvurunuz alindi - {reference_no}",
        body=(
            f"Merhaba,\n\n"
            f"\"{subject_line}\" konulu basvurunuz alinmistir.\n"
            f"Referans numaraniz: {reference_no}\n\n"
            f"Basvurunuzun durumunu uygulama uzerinden takip edebilirsiniz.\n\n"
            f"{settings.EMAIL_FROM_NAME}"
        ),
    )


async def send_status_changed(
    to: str, reference_no: str, status_label: str, resolution_note: str | None = None
) -> None:
    body = (
        f"Merhaba,\n\n"
        f"{reference_no} numarali basvurunuzun durumu \"{status_label}\" olarak guncellendi.\n"
    )
    if resolution_note:
        body += f"\nSonuc aciklamasi:\n{resolution_note}\n"
    body += f"\nDetaylari uygulama uzerinden gorebilirsiniz.\n\n{settings.EMAIL_FROM_NAME}"

    await send_email(
        to=to,
        subject=f"Basvurunuzun durumu guncellendi - {reference_no}",
        body=body,
    )
