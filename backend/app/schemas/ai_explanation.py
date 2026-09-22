from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field
from datetime import datetime


# ==========================================================
# MULTI-SIGNAL CHANGE NARRATIVE SCHEMAS
# ==========================================================

class NarrativeSummary(BaseModel):
    title: str = Field(..., description="Observable summary title, e.g., 'Observable differences detected'")
    description: str = Field(..., description="Concise non-diagnostic description of observable comparison differences")
    status: str = Field(..., description="'observable_difference', 'no_significant_difference', 'review_required', or 'insufficient_data'")


class SignalItem(BaseModel):
    name: str = Field(..., description="Signal name: 'Area', 'Shape', 'Color', 'Position', 'Segmentation Overlap'")
    baseline_value: Optional[Any] = Field(None, description="Measured baseline value")
    followup_value: Optional[Any] = Field(None, description="Measured follow-up value")
    change_value: Optional[Any] = Field(None, description="Quantitative difference / score")
    change_unit: Optional[str] = Field(None, description="Measurement unit ('percent', 'px', 'score', 'delta_e')")
    direction: str = Field(..., description="Direction: 'increased', 'decreased', 'shifted', 'differed', 'stable', 'unavailable'")
    status: str = Field(..., description="Status: 'observable_difference', 'stable', 'unavailable'")
    reliability: str = Field(..., description="Signal engineering reliability: 'high', 'moderate', 'low', 'insufficient'")
    explanation: str = Field(..., description="Plain-language non-diagnostic description of the observable signal")


class NarrativeReliability(BaseModel):
    overall: str = Field(..., description="Engineering reliability: 'high', 'moderate', 'low', 'insufficient'")
    quality_status: str = Field("acceptable", description="Image quality check status")
    alignment_status: str = Field("acceptable", description="Alignment pipeline status")
    segmentation_status: str = Field("completed", description="Segmentation localization status")
    limitations: List[str] = Field(default_factory=list, description="Concrete photographic or processing limitations")


class NarrativeUncertainty(BaseModel):
    present: bool = Field(False, description="True if capture or processing uncertainty was detected")
    explanation: str = Field("", description="Clear explanation of uncertainty factors")


# ==========================================================
# LEGACY OBSERVATION & EXPLANATION SCHEMAS (BACKWARD COMPATIBLE)
# ==========================================================

class ObservationItem(BaseModel):
    metric: str = Field(..., description="The metric observed (e.g., area, color, shape, boundary, position)")
    status: str = Field(..., description="Status of the metric: 'changed', 'unchanged', or 'unavailable'")
    value: Optional[Any] = Field(None, description="The quantitative value of the change, if available")
    explanation: str = Field(..., description="A user-friendly, non-diagnostic explanation of the metric and its change")


class ReliabilityExplanation(BaseModel):
    status: str = Field(..., description="Reliability status: 'reliable', 'needs_review', or 'unavailable'")
    explanation: str = Field(..., description="Explanation of why this comparison is reliable or needs review")


class ModelMetadataInfo(BaseModel):
    model_name: str
    model_version: str
    inference_mode: str


class AIExplanationResponse(BaseModel):
    # Multi-Signal Narrative Schema
    narrative_summary: NarrativeSummary = Field(
        default_factory=lambda: NarrativeSummary(
            title="Observable Image Comparison",
            description="Observable image features compared across captures.",
            status="observable_difference"
        )
    )
    signals: List[SignalItem] = Field(default_factory=list)
    narrative_reliability: NarrativeReliability = Field(
        default_factory=lambda: NarrativeReliability(
            overall="moderate",
            quality_status="acceptable",
            alignment_status="acceptable",
            segmentation_status="completed",
            limitations=[]
        )
    )
    narrative_uncertainty: NarrativeUncertainty = Field(
        default_factory=lambda: NarrativeUncertainty(present=False, explanation="")
    )
    safety_message: str = Field(
        default="This is an analysis of observable image differences and is not a medical diagnosis."
    )
    recommended_next_step: str = Field(
        default="Continue standardized tracking. If you notice concerning changes or have health concerns, consider consulting a qualified healthcare professional."
    )

    # Legacy Fields for Existing UI Compatibility
    summary: str = Field(..., description="A high-level summary of observable changes. Must not contain medical diagnosis.")
    observations: List[ObservationItem] = Field(default_factory=list)
    reliability: ReliabilityExplanation
    limitations: List[str] = Field(default_factory=list)
    missing_information: List[str] = Field(default_factory=list)
    recommended_next_steps: List[str] = Field(default_factory=list)
    medical_disclaimer: str = Field(..., description="Mandatory medical safety disclaimer")
    model_metadata: ModelMetadataInfo


class ComparisonExplanationInput(BaseModel):
    comparison_id: str
    skintwin_id: str
    baseline_capture_date: Optional[datetime] = None
    followup_capture_date: Optional[datetime] = None
    alignment_status: str
    alignment_score: Optional[float] = None
    inlier_ratio: Optional[float] = None
    match_count: Optional[int] = None
    segmentation_status: str
    localization_confidence: Optional[float] = None
    model_name: str
    model_version: str
    inference_mode: str
    fallback_used: bool
    area_change_percent: Optional[float] = None
    earlier_area: Optional[float] = None
    latest_area: Optional[float] = None
    color_change_metrics: Optional[Dict[str, Any]] = None
    shape_change_metrics: Optional[Dict[str, Any]] = None
    boundary_change_metrics: Optional[Dict[str, Any]] = None
    position_change_metrics: Optional[Dict[str, Any]] = None
    reliability_status: str
    reliability_score: Optional[float] = None
    uncertainty_indicators: List[str] = Field(default_factory=list)
    missing_or_unavailable_values: List[str] = Field(default_factory=list)
