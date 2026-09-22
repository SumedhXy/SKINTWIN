import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, DateTime, ForeignKey, Text, Float, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.skintwin import SkinTwin


class Capture(Base):
    __tablename__ = "captures"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    skintwin_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("skintwins.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    image_object_key: Mapped[str] = mapped_column(String(500), nullable=False)
    image_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    body_location: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    device_metadata: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Image Quality Assessment Fields
    quality_status: Mapped[str] = mapped_column(String(50), default="acceptable", nullable=False)
    quality_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    blur_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    lighting_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    resolution_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    framing_status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    comparison_eligible: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    quality_details: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    quality_analyzed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    reference_scale_available: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    measurement_status: Mapped[str] = mapped_column(String(50), default="unavailable", nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="captures")
    skintwin: Mapped["SkinTwin"] = relationship("SkinTwin", back_populates="captures")
