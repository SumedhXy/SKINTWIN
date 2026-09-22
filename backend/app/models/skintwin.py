import uuid
from datetime import datetime, timezone
from typing import List, Optional, TYPE_CHECKING
from sqlalchemy import String, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.capture import Capture
    from app.models.comparison import Comparison


class SkinTwin(Base):
    __tablename__ = "skintwins"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    public_id: Mapped[str] = mapped_column(
        String(64), unique=True, index=True, default=lambda: f"st-{uuid.uuid4().hex[:10]}"
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    body_location: Mapped[str] = mapped_column(String(100), nullable=False)
    body_side: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="active", nullable=False)
    baseline_capture_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    last_capture_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="skintwins")
    captures: Mapped[List["Capture"]] = relationship("Capture", back_populates="skintwin", cascade="all, delete-orphan")
    comparisons: Mapped[List["Comparison"]] = relationship("Comparison", back_populates="skintwin", cascade="all, delete-orphan")
