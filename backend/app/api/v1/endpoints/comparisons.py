from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.comparison import (
    ComparisonCreateRequest,
    ComparisonResponse,
    ComparisonListResponse,
)
from app.services.comparison_service import ComparisonService

router = APIRouter()


@router.post(
    "/skintwins/{public_id}/comparisons",
    response_model=ComparisonResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new capture comparison pair",
)
def create_skintwin_comparison(
    public_id: str,
    request: ComparisonCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create a comparison record linking an earlier and latest capture for a SkinTwin.
    Validates ownership, capture existence, and chronological ordering.
    """
    return ComparisonService.create(db, current_user, public_id, request)


@router.get(
    "/skintwins/{public_id}/comparisons",
    response_model=ComparisonListResponse,
    summary="List all comparisons for a SkinTwin",
)
def list_skintwin_comparisons(
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all comparisons for a specific SkinTwin owned by the authenticated user."""
    items = ComparisonService.list_for_skintwin(db, current_user, public_id)
    return ComparisonListResponse(total=len(items), items=items)


@router.get(
    "/comparisons/{comparison_id}",
    response_model=ComparisonResponse,
    summary="Get comparison details by comparison_id",
)
def get_comparison(
    comparison_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve comparison details by comparison_id.
    Returns 404 if comparison does not exist or belongs to another user.
    """
    return ComparisonService.get_by_id(db, current_user, comparison_id)


@router.delete(
    "/comparisons/{comparison_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a comparison",
)
def delete_comparison(
    comparison_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Delete a comparison record.
    Only the authenticated owner can delete their comparison.
    """
    ComparisonService.delete(db, current_user, comparison_id)


from app.schemas.ai_explanation import AIExplanationResponse
from app.services.explanation import ExplanationService
from app.core.errors import NotFoundException
from app.models.comparison import Comparison

@router.get(
    "/comparisons/{comparison_id}/explanation",
    response_model=AIExplanationResponse,
    summary="Get AI explanation for a comparison",
)
def get_comparison_explanation(
    comparison_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get the AI-generated context and explanation for a comparison.
    Generates it on the fly if it hasn't been cached yet.
    """
    comp = db.query(Comparison).filter(Comparison.id == comparison_id).first()
    if not comp or comp.user_id != current_user.id:
        raise NotFoundException(message="Comparison not found.", code="COMPARISON_NOT_FOUND")
    
    return ExplanationService.get_or_generate_explanation(db, comp)


@router.post(
    "/comparisons/{comparison_id}/explanation",
    response_model=AIExplanationResponse,
    summary="Force generate AI explanation for a comparison",
)
def force_generate_comparison_explanation(
    comparison_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Force re-generation of the AI explanation for a comparison.
    """
    comp = db.query(Comparison).filter(Comparison.id == comparison_id).first()
    if not comp or comp.user_id != current_user.id:
        raise NotFoundException(message="Comparison not found.", code="COMPARISON_NOT_FOUND")
    
    return ExplanationService.generate_explanation_force(db, comp)
