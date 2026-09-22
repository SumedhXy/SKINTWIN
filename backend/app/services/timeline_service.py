from typing import List
from sqlalchemy.orm import Session
from app.models.capture import Capture
from app.models.user import User
from app.schemas.timeline import TimelineResponse
from app.services.skintwin_service import _get_owned_twin
from app.services.capture_service import _build_capture_response


class TimelineService:

    @staticmethod
    def get_timeline(
        db: Session,
        user: User,
        skintwin_public_id: str,
        order: str = "desc",
        limit: int = 50,
        offset: int = 0,
    ) -> TimelineResponse:
        """
        Retrieve chronological timeline of captures for a SkinTwin.
        Enforces user ownership (404 if not owned/found).
        """
        twin = _get_owned_twin(db, skintwin_public_id, user)

        query = db.query(Capture).filter(Capture.skintwin_id == twin.id)
        total = query.count()

        if order.lower() == "asc":
            query = query.order_by(Capture.captured_at.asc())
        else:
            query = query.order_by(Capture.captured_at.desc())

        captures = query.offset(offset).limit(limit).all()
        items = [_build_capture_response(c, twin.public_id) for c in captures]

        return TimelineResponse(
            skintwin_public_id=twin.public_id,
            skintwin_name=twin.name,
            baseline_capture_id=twin.baseline_capture_id,
            total_captures=total,
            items=items,
        )
