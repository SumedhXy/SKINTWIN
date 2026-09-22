from typing import Optional, List
from pydantic import BaseModel
from app.schemas.capture import CaptureResponse


class TimelineResponse(BaseModel):
    skintwin_public_id: str
    skintwin_name: str
    baseline_capture_id: Optional[str] = None
    total_captures: int
    items: List[CaptureResponse]
