from datetime import datetime, timezone
from typing import List
from sqlalchemy.orm import Session
from app.core.errors import NotFoundException, ForbiddenException
from app.models.skintwin import SkinTwin
from app.models.capture import Capture
from app.models.user import User
from app.schemas.skintwin import SkinTwinCreateRequest, SkinTwinUpdateRequest, SkinTwinResponse


def _build_response(twin: SkinTwin, db: Session) -> SkinTwinResponse:
    """Build a SkinTwinResponse enriched with capture count."""
    capture_count = db.query(Capture).filter(Capture.skintwin_id == twin.id).count()
    return SkinTwinResponse(
        public_id=twin.public_id,
        name=twin.name,
        body_location=twin.body_location,
        body_side=twin.body_side,
        description=twin.description,
        status=twin.status,
        capture_count=capture_count,
        created_at=twin.created_at,
        updated_at=twin.updated_at,
        last_capture_at=twin.last_capture_at,
    )


def _get_owned_twin(db: Session, public_id: str, user: User) -> SkinTwin:
    """
    Fetch a SkinTwin by public_id.
    - Returns 404 if not found regardless of owner (prevents user-enumeration).
    - Returns 404 (not 403) if the twin belongs to a different user
      so that private records are not revealed to unauthorized callers.
    """
    twin = db.query(SkinTwin).filter(SkinTwin.public_id == public_id).first()
    if not twin:
        raise NotFoundException(message="SkinTwin not found.", code="SKINTWIN_NOT_FOUND")
    if twin.user_id != user.id:
        # Return 404 — not 403 — to avoid confirming the record exists
        raise NotFoundException(message="SkinTwin not found.", code="SKINTWIN_NOT_FOUND")
    return twin


class SkinTwinService:

    @staticmethod
    def create(db: Session, user: User, request: SkinTwinCreateRequest) -> SkinTwinResponse:
        """Create a new SkinTwin owned by the authenticated user."""
        twin = SkinTwin(
            user_id=user.id,
            name=request.name.strip(),
            body_location=request.body_location.strip(),
            body_side=request.body_side.strip() if request.body_side else None,
            description=request.description.strip() if request.description else None,
            status="active",
        )
        db.add(twin)
        db.commit()
        db.refresh(twin)
        return _build_response(twin, db)

    @staticmethod
    def list_for_user(db: Session, user: User) -> List[SkinTwinResponse]:
        """Return all SkinTwins belonging to the authenticated user."""
        twins = (
            db.query(SkinTwin)
            .filter(SkinTwin.user_id == user.id)
            .order_by(SkinTwin.created_at.desc())
            .all()
        )
        return [_build_response(t, db) for t in twins]

    @staticmethod
    def get_by_public_id(db: Session, public_id: str, user: User) -> SkinTwinResponse:
        """Return a single SkinTwin by public_id (ownership enforced)."""
        twin = _get_owned_twin(db, public_id, user)
        return _build_response(twin, db)

    @staticmethod
    def update(
        db: Session, public_id: str, user: User, request: SkinTwinUpdateRequest
    ) -> SkinTwinResponse:
        """Partially update a SkinTwin (ownership enforced)."""
        twin = _get_owned_twin(db, public_id, user)

        if request.name is not None:
            twin.name = request.name.strip()
        if request.body_location is not None:
            twin.body_location = request.body_location.strip()
        if request.body_side is not None:
            twin.body_side = request.body_side.strip()
        if request.description is not None:
            twin.description = request.description.strip()
        if request.status is not None:
            allowed_statuses = {"active", "archived", "needs_review"}
            if request.status not in allowed_statuses:
                from app.core.errors import SkinTwinException
                from fastapi import status
                raise SkinTwinException(
                    code="INVALID_STATUS",
                    message=f"Status must be one of: {', '.join(sorted(allowed_statuses))}.",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
            twin.status = request.status

        twin.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(twin)
        return _build_response(twin, db)

    @staticmethod
    def delete(db: Session, public_id: str, user: User) -> None:
        """Delete a SkinTwin and cascade-delete all linked captures, comparisons, etc."""
        twin = _get_owned_twin(db, public_id, user)
        db.delete(twin)
        db.commit()
