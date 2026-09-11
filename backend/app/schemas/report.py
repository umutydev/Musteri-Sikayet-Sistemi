import uuid

from pydantic import BaseModel


class StatusBreakdownOut(BaseModel):
    status: str
    count: int


class CategoryBreakdownOut(BaseModel):
    category: str
    count: int


class SummaryOut(BaseModel):
    total_tickets: int
    open_tickets: int
    closed_tickets: int
    unassigned_tickets: int
    avg_resolution_days: float | None
    status_breakdown: list[StatusBreakdownOut]
    category_breakdown: list[CategoryBreakdownOut]


class AgentPerformanceOut(BaseModel):
    agent_id: uuid.UUID
    agent_name: str
    assigned_count: int
    closed_count: int
    avg_resolution_days: float | None
