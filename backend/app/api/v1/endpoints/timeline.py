from typing import Literal
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.timeline import TimelineResponse
from app.services.timeline_service import TimelineService

router = APIRouter()


@router.get(
    "/skintwins/{public_id}/timeline",
    response_model=TimelineResponse,
    summary="Get chronological timeline of captures for a SkinTwin",
)
def get_skintwin_timeline(
    public_id: str,
    order: Literal["asc", "desc"] = Query("desc", description="Sort order by captured_at ('asc' or 'desc')"),
    limit: int = Query(50, ge=1, le=100, description="Max items to return"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve chronological capture progression for a SkinTwin owned by the authenticated user.
    Supports pagination and sorting order. Returns 404 if SkinTwin not found or wrong user.
    """
    return TimelineService.get_timeline(
        db=db,
        user=current_user,
        skintwin_public_id=public_id,
        order=order,
        limit=limit,
        offset=offset,
    )
