from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.user import (
    UserResponse,
    UserUpdateRequest,
    ChangePasswordRequest,
    DeleteAccountRequest,
    UserExportResponse,
)
from app.services.user_service import UserService
from app.core.rate_limit import limiter

router = APIRouter()


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user profile",
)
def get_user_me(current_user: User = Depends(get_current_user)):
    """Return the currently authenticated user's profile."""
    return UserResponse.model_validate(current_user)


@router.patch(
    "/me",
    response_model=UserResponse,
    summary="Update current user's display name",
)
def update_user_me(
    request_body: UserUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Update the authenticated user's profile (display name only).
    Only the authenticated owner can update their own profile.
    """
    return UserService.update_profile(db, current_user, request_body)


@router.post(
    "/change-password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Change the authenticated user's password",
)
@limiter.limit("5/minute")
def change_password(
    request: Request,
    request_body: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Change the authenticated user's password.
    Requires the current password for verification.
    New password must be at least 8 characters and differ from the current password.
    Rate limited to 5 attempts per minute.
    """
    UserService.change_password(db, current_user, request_body)


@router.get(
    "/me/export",
    response_model=UserExportResponse,
    summary="Export personal data as JSON",
)
@limiter.limit("3/minute")
def export_user_data(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Export a JSON snapshot of the authenticated user's personal data.
    Includes profile metadata, SkinTwins, and capture metadata.
    Does NOT include password hashes, JWT secrets, or raw image files.
    Rate limited to 3 requests per minute.
    """
    return UserService.export_data(db, current_user)


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Permanently delete the authenticated user's account",
)
@limiter.limit("3/minute")
def delete_account(
    request: Request,
    request_body: DeleteAccountRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Permanently delete the authenticated user's account and all associated data.
    Requires the current password for re-authentication.
    This operation is destructive:
    - Deletes the user record and all owned SkinTwins, captures, comparisons, and sharing permissions.
    - Attempts to delete all private image files from storage.
    - If an image file cannot be deleted, the failure is logged but DB deletion proceeds.

    IMPORTANT: This system uses stateless JWT tokens without a server-side blacklist.
    After account deletion, any active JWT tokens remain cryptographically valid until they expire
    (up to 30 minutes). The client must clear its local token immediately after calling this endpoint.
    """
    UserService.delete_account(db, current_user, request_body)
