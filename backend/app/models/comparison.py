import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, DateTime, ForeignKey, Text, Float, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.base import Base

if TYPE_CHECKING:
    from app.models.skintwin import SkinTwin


class Comparison(Base):
    __tablename__ = "comparisons"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    skintwin_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("skintwins.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    earlier_capture_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("captures.id", ondelete="CASCADE"), nullable=False
    )
    latest_capture_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("captures.id", ondelete="CASCADE"), nullable=False
    )

    # Processing Pipeline Status
    processing_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False)
    processing_error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # OpenCV Alignment Fields
    alignment_status: Mapped[str] = mapped_column(String(50), default="not_evaluated", nullable=False)
    alignment_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    match_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    inlier_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    inlier_ratio: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    alignment_method: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    alignment_error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # MedSAM ViT-B Segmentation / Localization Fields
    localization_status: Mapped[str] = mapped_column(String(50), default="not_evaluated", nullable=False)
    localization_confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    segmentation_model: Mapped[Optional[str]] = mapped_column(String(50), default="medsam_vit_b", nullable=True)
    segmentation_model_version: Mapped[Optional[str]] = mapped_column(String(50), default="1.0.0", nullable=True)
    segmentation_error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Observable Quantitative Measurements
    earlier_area: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    latest_area: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    area_change_percent: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    color_change_metrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    shape_change_metrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    boundary_change_metrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    position_change_metrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Status, Reliability & Uncertainty Fields
    comparison_status: Mapped[str] = mapped_column(String(50), default="completed", nullable=False)
    measurement_status: Mapped[str] = mapped_column(String(50), default="unavailable", nullable=False)
    reliability_status: Mapped[str] = mapped_column(String(50), default="unavailable", nullable=False)
    reliability_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    uncertainty_reasons: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    observable_change_summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    observable_metrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    ai_explanation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    comparison_version: Mapped[str] = mapped_column(String(50), default="1.0.0", nullable=False)

    analyzed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    # Relationships
    skintwin: Mapped["SkinTwin"] = relationship("SkinTwin", back_populates="comparisons")
