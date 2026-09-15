import uuid

from pydantic import BaseModel, Field


class TeamCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    description: str | None = None


class TeamUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    description: str | None = None
    is_active: bool | None = None


class TeamMemberOut(BaseModel):
    """Ekip detayinda gosterilen uye ozeti."""
    id: uuid.UUID
    full_name: str
    email: str
    is_active: bool

    model_config = {"from_attributes": True}


class TeamOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    is_active: bool

    model_config = {"from_attributes": True}


class TeamDetailOut(TeamOut):
    """
    Liste ekraninda gosterilen zenginlestirilmis ekip bilgisi.
    Tasarimdaki "15 aktif vaka · +5 uye" gostergesi bu alanlardan beslenir.
    """
    member_count: int
    active_ticket_count: int
    category_names: list[str]


class TeamMemberAssign(BaseModel):
    user_id: uuid.UUID


class CategoryTeamAssign(BaseModel):
    team_id: uuid.UUID | None = None
