from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.skintwin import (
    SkinTwinCreateRequest,
    SkinTwinUpdateRequest,
    SkinTwinResponse,
    SkinTwinListResponse,
)
from app.services.skintwin_service import SkinTwinService

router = APIRouter()


@router.post(
    "",
    response_model=SkinTwinResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new SkinTwin",
)
def create_skintwin(
    request: SkinTwinCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create a persistent digital representation of an individual skin finding.
    The SkinTwin is owned exclusively by the authenticated user.
    """
    return SkinTwinService.create(db, current_user, request)


@router.get(
    "",
    response_model=SkinTwinListResponse,
    summary="List all SkinTwins for the current user",
)
def list_skintwins(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return all SkinTwins belonging to the authenticated user, newest first."""
    items = SkinTwinService.list_for_user(db, current_user)
    return SkinTwinListResponse(total=len(items), items=items)


@router.get(
    "/{public_id}",
    response_model=SkinTwinResponse,
    summary="Get a specific SkinTwin by public_id",
)
def get_skintwin(
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve a single SkinTwin by its public_id.
    Returns 404 if not found or if the record belongs to another user.
    """
    return SkinTwinService.get_by_public_id(db, public_id, current_user)


@router.patch(
    "/{public_id}",
    response_model=SkinTwinResponse,
    summary="Update a SkinTwin",
)
def update_skintwin(
    public_id: str,
    request: SkinTwinUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Partially update a SkinTwin's details.
    Only the authenticated owner can update their SkinTwins.
    """
    return SkinTwinService.update(db, public_id, current_user, request)


@router.delete(
    "/{public_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a SkinTwin",
)
def delete_skintwin(
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Permanently delete a SkinTwin and all associated captures, comparisons, and notes.
    Only the authenticated owner can delete their SkinTwins.
    """
    SkinTwinService.delete(db, public_id, current_user)
