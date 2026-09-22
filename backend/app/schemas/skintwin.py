from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


# ── Request Schemas ────────────────────────────────────────────────────────────

class SkinTwinCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150, description="Name for this SkinTwin (e.g. 'Left Shoulder Mole')")
    body_location: str = Field(..., min_length=1, max_length=100, description="Body region (e.g. 'shoulder', 'back', 'forearm')")
    body_side: Optional[str] = Field(None, max_length=50, description="Side of the body: 'left', 'right', 'center'")
    description: Optional[str] = Field(None, description="Optional free-text description")


class SkinTwinUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    body_location: Optional[str] = Field(None, min_length=1, max_length=100)
    body_side: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = None
    status: Optional[str] = Field(None, max_length=50, description="Status: 'active', 'archived', 'needs_review'")


# ── Response Schemas ───────────────────────────────────────────────────────────

class SkinTwinResponse(BaseModel):
    public_id: str
    name: str
    body_location: str
    body_side: Optional[str] = None
    description: Optional[str] = None
    status: str
    capture_count: int = 0
    created_at: datetime
    updated_at: datetime
    last_capture_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class SkinTwinListResponse(BaseModel):
    total: int
    items: list[SkinTwinResponse]
