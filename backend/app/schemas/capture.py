import json
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, field_validator


class CaptureCoachCheckItem(BaseModel):
    category: str  # "sharpness", "lighting", "resolution", "framing", "baseline_consistency"
    status: str  # "pass", "warning", "fail", "unknown"
    score: Optional[float] = None  # 0.0 to 1.0
    message: str
    details: Optional[Dict[str, Any]] = None


class CaptureCoachResponse(BaseModel):
    status: str  # "ready", "needs_adjustment", "blocked", "processing", "unavailable"
    can_continue: bool
    quality_score: Optional[float] = None
    primary_message: str
    suggestions: List[str]
    checks: List[CaptureCoachCheckItem]
    limitations: List[str]
    has_baseline_comparison: bool = False


class CaptureResponse(BaseModel):
    id: str
    skintwin_public_id: str
    image_object_key: str
    image_hash: Optional[str] = None
    captured_at: datetime
    uploaded_at: datetime
    body_location: Optional[str] = None
    quality_status: str
    quality_score: Optional[float] = None
    blur_status: Optional[str] = None
    lighting_status: Optional[str] = None
    resolution_status: Optional[str] = None
    framing_status: Optional[str] = None
    comparison_eligible: bool = False
    quality_details: Optional[Dict[str, Any]] = None
    quality_analyzed_at: Optional[datetime] = None
    reference_scale_available: bool = False
    measurement_status: str
    device_metadata: Optional[str] = None
    notes: Optional[str] = None

    @field_validator("quality_details", mode="before")
    @classmethod
    def parse_quality_details_json(cls, v: Any) -> Optional[Dict[str, Any]]:
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return {"raw": v}
        return v

    model_config = {"from_attributes": True}


class CaptureListResponse(BaseModel):
    total: int
    items: List[CaptureResponse]


class CaptureDetailResponse(CaptureResponse):
    """Detailed capture information."""
    pass
