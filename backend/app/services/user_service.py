import logging
from datetime import datetime, timezone
from typing import List
from sqlalchemy.orm import Session

from app.core.errors import UnauthorizedException, SkinTwinException
from app.core.security import verify_password, get_password_hash
from app.models.user import User
from app.models.skintwin import SkinTwin
from app.models.capture import Capture
from app.schemas.user import (
    UserUpdateRequest,
    ChangePasswordRequest,
    DeleteAccountRequest,
    UserResponse,
    ExportSkinTwinData,
    ExportCaptureData,
    UserExportResponse,
)
from app.services.storage import get_storage_adapter
from fastapi import status

logger = logging.getLogger(__name__)


class UserService:

    @staticmethod
    def update_profile(db: Session, user: User, request: UserUpdateRequest) -> UserResponse:
        """
        Update the authenticated user's display name.
        Only modifies fields that are explicitly provided.
        """
        if request.full_name is not None:
            stripped = request.full_name.strip()
            user.full_name = stripped if stripped else None
            user.updated_at = datetime.now(timezone.utc)
            db.commit()
            db.refresh(user)
        return UserResponse.model_validate(user)

    @staticmethod
    def change_password(db: Session, user: User, request: ChangePasswordRequest) -> None:
        """
        Change the authenticated user's password.
        - Verifies the current password before accepting a new one.
        - Enforces minimum password length (delegated to schema).
        - Rejects if new password is identical to current.
        Never logs or returns the plaintext or hashed password.
        """
        if not verify_password(request.current_password, user.password_hash):
            raise UnauthorizedException(
                message="Current password is incorrect.",
                code="INVALID_CURRENT_PASSWORD",
            )

        if request.new_password == request.current_password:
            raise SkinTwinException(
                code="PASSWORD_UNCHANGED",
                message="New password must be different from the current password.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user.password_hash = get_password_hash(request.new_password)
        user.updated_at = datetime.now(timezone.utc)
        db.commit()

    @staticmethod
    def export_data(db: Session, user: User) -> UserExportResponse:
        """
        Build a synchronous JSON export of all personal data owned by the user.
        - Does NOT include password hashes, JWT secrets, or API keys.
        - Does NOT include raw image binary content.
        - image_object_key (storage path) IS included as metadata.
        - Export scope: profile, SkinTwins, captures (metadata only).
        """
        skintwins = (
            db.query(SkinTwin)
            .filter(SkinTwin.user_id == user.id)
            .order_by(SkinTwin.created_at.desc())
            .all()
        )
        captures = (
            db.query(Capture)
            .filter(Capture.user_id == user.id)
            .order_by(Capture.captured_at.desc())
            .all()
        )

        # Build a lookup: skintwin internal ID -> public_id
        twin_id_to_public = {t.id: t.public_id for t in skintwins}
        capture_count_by_twin = {}
        for c in captures:
            capture_count_by_twin[c.skintwin_id] = capture_count_by_twin.get(c.skintwin_id, 0) + 1

        export_skintwins = [
            ExportSkinTwinData(
                public_id=t.public_id,
                name=t.name,
                body_location=t.body_location,
                status=t.status,
                capture_count=capture_count_by_twin.get(t.id, 0),
                created_at=t.created_at,
            )
            for t in skintwins
        ]

        export_captures = [
            ExportCaptureData(
                id=c.id,
                skintwin_public_id=twin_id_to_public.get(c.skintwin_id, "unknown"),
                captured_at=c.captured_at,
                quality_status=c.quality_status,
                comparison_eligible=c.comparison_eligible,
                notes=c.notes,
            )
            for c in captures
        ]

        return UserExportResponse(
            exported_at=datetime.now(timezone.utc),
            profile=UserResponse.model_validate(user),
            skintwins=export_skintwins,
            captures=export_captures,
            total_skintwins=len(export_skintwins),
            total_captures=len(export_captures),
            export_notes=[
                "This export contains profile metadata, SkinTwin records, and capture metadata.",
                "Raw image files are not included in this export.",
                "Password hashes, JWT tokens, and internal secrets are never included.",
                "Comparison results and AI explanations are not included in this export version.",
                "This export represents data stored at the time of the request.",
            ],
        )

    @staticmethod
    def delete_account(db: Session, user: User, request: DeleteAccountRequest) -> None:
        """
        Permanently delete the authenticated user's account.
        - Requires password re-authentication.
        - Deletes all associated storage files (per-capture).
        - If a file deletion fails, the failure is logged but does not block DB deletion.
        - SQLAlchemy cascade ('all, delete-orphan') handles related DB records.
        - After this operation, the user's JWT token remains technically valid until
          it expires (stateless JWT limitation, documented).
        """
        if not verify_password(request.password, user.password_hash):
            raise UnauthorizedException(
                message="Password is incorrect. Account deletion requires valid credentials.",
                code="INVALID_PASSWORD",
            )

        # Delete all private image files from storage
        storage = get_storage_adapter()
        captures = db.query(Capture).filter(Capture.user_id == user.id).all()
        for capture in captures:
            try:
                deleted = storage.delete_file(capture.image_object_key)
                if not deleted:
                    logger.warning(
                        "Storage file '%s' could not be removed during account deletion for user '%s'.",
                        capture.image_object_key,
                        user.id,
                    )
            except Exception as exc:
                logger.error(
                    "Unexpected error deleting storage file '%s' during account deletion: %s",
                    capture.image_object_key,
                    exc,
                )

        # Delete user record — cascades to skintwins, captures, comparisons, sharing_permissions
        db.delete(user)
        db.commit()
        logger.info("Account deletion completed for user_id='%s'.", user.id)
