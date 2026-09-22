import json
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, model_validator, field_validator


class UncertaintyReasonItem(BaseModel):
    category: str = Field(..., description="Category: image_quality, lighting, blur, framing, alignment, segmentation, measurement, missing_data, capture_conditions")
    severity: str = Field(..., description="Severity level: low, moderate, high")
    message: str = Field(..., description="Plain-language description of the uncertainty factor")


class ComponentStatusItem(BaseModel):
    name: str = Field(..., description="Component name, e.g. Image Quality, Alignment, Segmentation, Measurements")
    status: str = Field(..., description="Status label: acceptable/limited/poor/unavailable or high/moderate/low/unavailable")
    score: Optional[float] = Field(None, description="Component quality/confidence score (0.0 to 1.0)")
    explanation: str = Field(..., description="Clear explanation of component analysis outcome")
    limitation: Optional[str] = Field(None, description="Component-specific limitation if any")
    is_fallback: bool = Field(False, description="True if fallback algorithmic processing was used")


class SignalReliabilityItem(BaseModel):
    name: str = Field(..., description="Signal name: Area, Shape, Color, Position, Segmentation Overlap")
    reliability: str = Field(..., description="Signal reliability: high, moderate, low, unavailable, insufficient")
    uncertainty: bool = Field(False, description="True if uncertainty affects this signal")
    limitation: Optional[str] = Field(None, description="Signal-specific limitation")
    interpretation: str = Field(..., description="Actionable non-diagnostic interpretation guidance")


class ReliabilityDetailsResponse(BaseModel):
    overall_reliability: str = Field(..., description="Overall engineering reliability: high, moderate, low, insufficient")
    reliability_score: float = Field(..., description="Composite engineering reliability score (0.0 to 1.0)")
    uncertainty_present: bool = Field(False, description="True if uncertainty indicators exist")
    uncertainty_reasons: List[UncertaintyReasonItem] = Field(default_factory=list)
    affected_signals: List[str] = Field(default_factory=list)
    limitations: List[str] = Field(default_factory=list)
    component_statuses: Dict[str, ComponentStatusItem] = Field(default_factory=dict)
    signal_reliabilities: Dict[str, SignalReliabilityItem] = Field(default_factory=dict)
    disclaimer: str = Field(
        default="SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance."
    )


class ComparisonCreateRequest(BaseModel):
    earlier_capture_id: str = Field(..., description="ID of the earlier capture")
    latest_capture_id: str = Field(..., description="ID of the later capture")
    earlier_prompt: Optional[Dict[str, Any]] = Field(None, description="Optional MedSAM ROI prompt for earlier image e.g. {'bbox': [x1, y1, x2, y2]}")
    latest_prompt: Optional[Dict[str, Any]] = Field(None, description="Optional MedSAM ROI prompt for latest image e.g. {'bbox': [x1, y1, x2, y2]}")

    @model_validator(mode="after")
    def check_captures_not_identical(self):
        if self.earlier_capture_id == self.latest_capture_id:
            raise ValueError("Earlier capture and latest capture cannot be identical.")
        return self


class ComparisonResponse(BaseModel):
    id: str
    skintwin_public_id: str
    earlier_capture_id: str
    latest_capture_id: str
    processing_status: str = "pending"
    processing_error_code: Optional[str] = None

    # OpenCV Alignment Fields
    alignment_status: str = "not_evaluated"
    alignment_score: Optional[float] = None
    match_count: Optional[int] = None
    inlier_count: Optional[int] = None
    inlier_ratio: Optional[float] = None
    alignment_method: Optional[str] = None
    alignment_error_code: Optional[str] = None

    # MedSAM ViT-B Segmentation Fields
    localization_status: str = "not_evaluated"
    localization_confidence: Optional[float] = None
    segmentation_model: Optional[str] = "medsam_vit_b"
    segmentation_model_version: Optional[str] = "1.0.0"
    segmentation_error_code: Optional[str] = None
    
    # Real Inference Metadata (Dynamically Computed)
    inference_mode: str = "unavailable"
    weights_loaded: bool = False
    fallback_used: bool = True

    # Observable Quantitative Measurements
    earlier_area: Optional[float] = None
    latest_area: Optional[float] = None
    area_change_percent: Optional[float] = None
    color_change_metrics: Optional[Dict[str, Any]] = None
    shape_change_metrics: Optional[Dict[str, Any]] = None
    boundary_change_metrics: Optional[Dict[str, Any]] = None
    position_change_metrics: Optional[Dict[str, Any]] = None

    # Status, Reliability & Uncertainty Fields
    comparison_status: str = "completed"
    measurement_status: str = "unavailable"
    reliability_status: str = "unavailable"
    overall_reliability: Optional[str] = None
    reliability_score: Optional[float] = None
    uncertainty_reasons: Optional[List[str]] = None
    uncertainty_reasons_structured: Optional[List[UncertaintyReasonItem]] = None
    affected_signals: Optional[List[str]] = None
    limitations: Optional[List[str]] = None
    reliability_details: Optional[ReliabilityDetailsResponse] = None

    observable_change_summary: Optional[str] = None
    observable_metrics: Optional[Dict[str, Any]] = None
    ai_explanation: Optional[Dict[str, Any]] = None
    comparison_version: str = "1.0.0"
    non_diagnostic_disclaimer: str = "SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance."

    analyzed_at: Optional[datetime] = None
    created_at: datetime

    @field_validator("color_change_metrics", "shape_change_metrics", "boundary_change_metrics", "position_change_metrics", "observable_metrics", "ai_explanation", mode="before")
    @classmethod
    def parse_dict_json(cls, v: Any) -> Optional[Dict[str, Any]]:
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return {"raw": v}
        return v

    @field_validator("uncertainty_reasons", mode="before")
    @classmethod
    def parse_list_json(cls, v: Any) -> Optional[List[str]]:
        if isinstance(v, str):
            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    # Handle both strings and objects in legacy list
                    return [item if isinstance(item, str) else item.get("message", str(item)) for item in parsed]
                return [str(parsed)]
            except Exception:
                return [v]
        elif isinstance(v, list):
            return [item if isinstance(item, str) else item.get("message", str(item)) for item in v]
        return v

    @model_validator(mode="after")
    def populate_reliability_and_inference_metadata(self):
        # 1. Compute Inference Metadata
        if self.segmentation_model == "fallback_cv":
            self.inference_mode = "fallback_cv"
            self.weights_loaded = False
            self.fallback_used = True
        elif self.segmentation_model in ["medsam_vit_b", "MedSAM ViT-B"]:
            self.inference_mode = "real_medsam"
            self.weights_loaded = True
            self.fallback_used = False
        else:
            self.inference_mode = "unavailable"
            self.weights_loaded = False
            self.fallback_used = True

        # 2. Extract structured reliability_details from observable_metrics if present
        if self.observable_metrics and isinstance(self.observable_metrics, dict):
            rel_dict = self.observable_metrics.get("reliability_details")
            if rel_dict and isinstance(rel_dict, dict):
                try:
                    self.reliability_details = ReliabilityDetailsResponse(**rel_dict)
                    self.overall_reliability = self.reliability_details.overall_reliability
                    self.uncertainty_reasons_structured = self.reliability_details.uncertainty_reasons
                    self.affected_signals = self.reliability_details.affected_signals
                    self.limitations = self.reliability_details.limitations
                    self.non_diagnostic_disclaimer = self.reliability_details.disclaimer
                except Exception:
                    pass

        # 3. Fallback derivation for overall_reliability if missing
        if not self.overall_reliability:
            if self.reliability_status == "reliable":
                self.overall_reliability = "high"
            elif self.reliability_status == "needs_review":
                self.overall_reliability = "moderate"
            elif self.reliability_status == "unreliable":
                self.overall_reliability = "low"
            elif self.reliability_status == "unavailable":
                self.overall_reliability = "insufficient"
            else:
                self.overall_reliability = self.reliability_status or "insufficient"

        return self

    model_config = {"from_attributes": True}


class ComparisonListResponse(BaseModel):
    total: int
    items: List[ComparisonResponse]
