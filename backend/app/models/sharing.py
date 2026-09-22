import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database.base import Base


class SharingPermission(Base):
    __tablename__ = "sharing_permissions"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    skintwin_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("skintwins.id", ondelete="CASCADE"), nullable=False, index=True
    )
    recipient_identifier: Mapped[str] = mapped_column(String(255), nullable=False)
    permission_level: Mapped[str] = mapped_column(String(50), default="view", nullable=False)
    expiry_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
