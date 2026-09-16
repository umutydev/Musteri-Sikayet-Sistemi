"""
Alembic'in autogenerate ozelligi icin tum modeller burada toplanir.
"""
from app.models.team import Team  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.password_reset import PasswordResetToken  # noqa: F401
from app.models.category import Category  # noqa: F401
from app.models.ticket import Ticket  # noqa: F401
from app.models.ticket_extras import (  # noqa: F401
    TicketAttachment,
    TicketNote,
    TicketStatusHistory,
    Notification,
)
