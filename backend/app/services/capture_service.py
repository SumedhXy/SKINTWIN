import json
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from app.core.errors import NotFoundException, SkinTwinException
from app.models.capture import Capture
from app.models.skintwin import SkinTwin
from app.models.user import User
from app.schemas.capture import CaptureResponse, CaptureDetailResponse, CaptureCoachResponse
from app.services.skintwin_service import _get_owned_twin
from app.services.storage import get_storage_adapter
from app.services.image_quality_service import ImageQualityService
from app.services.capture_coach_service import CaptureCoachService
from app.utils.image_validation import validate_and_inspect_image, compute_sha256

logger = logging.getLogger(__name__)


def _build_capture_response(capture: Capture, skintwin_public_id: str) -> CaptureResponse:
    return CaptureResponse(
        id=capture.id,
        skintwin_public_id=skintwin_public_id,
        image_object_key=capture.image_object_key,
        image_hash=capture.image_hash,
        captured_at=capture.captured_at,
        uploaded_at=capture.uploaded_at,
        body_location=capture.body_location,
        quality_status=capture.quality_status,
        quality_score=capture.quality_score,
        blur_status=capture.blur_status,
        lighting_status=capture.lighting_status,
        resolution_status=capture.resolution_status,
        framing_status=capture.framing_status,
        comparison_eligible=capture.comparison_eligible,
        quality_details=capture.quality_details,
        quality_analyzed_at=capture.quality_analyzed_at,
        reference_scale_available=capture.reference_scale_available,
        measurement_status=capture.measurement_status,
        device_metadata=capture.device_metadata,
        notes=capture.notes,
    )


class CaptureService:

    @staticmethod
    def create_capture(
        db: Session,
        user: User,
        skintwin_public_id: str,
        file_bytes: bytes,
        filename: str,
        notes: Optional[str] = None,
        captured_at: Optional[datetime] = None,
        device_metadata: Optional[str] = None,
    ) -> CaptureResponse:
        """
        Validate image, save to private storage, perform quality assessment,
        persist capture metadata, and link to SkinTwin.
        """
        # 1. Enforce ownership of SkinTwin (raises 404 if not found or wrong user)
        twin = _get_owned_twin(db, skintwin_public_id, user)

        # 2. Validate image format, size, and magic bytes
        fmt, mime_type, ext = validate_and_inspect_image(file_bytes, filename)

        # 3. Compute SHA-256 hash of raw bytes
        img_hash = compute_sha256(file_bytes)

        # 4. Generate unique object key (never use raw user-provided filenames)
        unique_filename = f"{uuid.uuid4().hex}.{ext}"
        object_key = f"users/{user.id}/skintwins/{twin.id}/captures/{unique_filename}"

        # 5. Save file to storage
        storage = get_storage_adapter()
        storage.save_file(file_bytes, object_key)

        now = datetime.now(timezone.utc)
        cap_time = captured_at if captured_at else now

        # 6. Evaluate image quality & coach guidance
        quality_eval = ImageQualityService.evaluate(file_bytes)

        # Optional baseline comparison for coach guidance
        baseline_bytes = None
        if twin.baseline_capture_id:
            try:
                base_cap = db.query(Capture).filter(Capture.id == twin.baseline_capture_id).first()
                if base_cap and base_cap.image_object_key:
                    baseline_bytes = storage.get_file(base_cap.image_object_key)
            except Exception as e:
                logger.warning(f"Could not load baseline image for coach evaluation: {e}")

        coach_eval = CaptureCoachService.evaluate_capture(file_bytes, baseline_bytes)
        merged_quality_details = dict(quality_eval.quality_details)
        merged_quality_details["coach"] = {
            "status": coach_eval.status,
            "can_continue": coach_eval.can_continue,
            "primary_message": coach_eval.primary_message,
            "suggestions": coach_eval.suggestions,
            "checks": [c.model_dump() for c in coach_eval.checks],
            "limitations": coach_eval.limitations,
            "has_baseline_comparison": coach_eval.has_baseline_comparison,
        }

        capture = Capture(
            skintwin_id=twin.id,
            user_id=user.id,
            image_object_key=object_key,
            image_hash=img_hash,
            captured_at=cap_time,
            uploaded_at=now,
            body_location=twin.body_location,
            device_metadata=device_metadata,
            quality_status=quality_eval.quality_status,
            quality_score=quality_eval.quality_score,
            blur_status=quality_eval.blur_status,
            lighting_status=quality_eval.lighting_status,
            resolution_status=quality_eval.resolution_status,
            framing_status=quality_eval.framing_status,
            comparison_eligible=quality_eval.comparison_eligible,
            quality_details=json.dumps(merged_quality_details),
            quality_analyzed_at=quality_eval.quality_analyzed_at,
            reference_scale_available=False,
            measurement_status="unavailable",
            notes=notes.strip() if notes else None,
        )

        try:
            db.add(capture)
            db.flush()  # assign capture.id

            # Update SkinTwin metadata
            twin.last_capture_at = now
            if not twin.baseline_capture_id:
                # Set initial baseline capture rule
                twin.baseline_capture_id = capture.id

            db.commit()
            db.refresh(capture)
            db.refresh(twin)
            return _build_capture_response(capture, twin.public_id)

        except Exception as e:
            db.rollback()
            # Clean up uploaded storage file on DB error
            storage.delete_file(object_key)
            logger.error(f"Failed to save capture DB record: {e}")
            raise e

    @staticmethod
    def list_for_skintwin(
        db: Session, user: User, skintwin_public_id: str
    ) -> List[CaptureResponse]:
        """List all captures for a given SkinTwin owned by the authenticated user."""
        twin = _get_owned_twin(db, skintwin_public_id, user)
        captures = (
            db.query(Capture)
            .filter(Capture.skintwin_id == twin.id)
            .order_by(Capture.captured_at.desc())
            .all()
        )
        return [_build_capture_response(c, twin.public_id) for c in captures]

    @staticmethod
    def get_by_id(db: Session, user: User, capture_id: str) -> CaptureResponse:
        """
        Get capture details by capture_id.
        Returns 404 if capture doesn't exist or belongs to a different user.
        """
        capture = db.query(Capture).filter(Capture.id == capture_id).first()
        if not capture or capture.user_id != user.id:
            raise NotFoundException(message="Capture not found.", code="CAPTURE_NOT_FOUND")

        twin = db.query(SkinTwin).filter(SkinTwin.id == capture.skintwin_id).first()
        twin_public_id = twin.public_id if twin else ""
        return _build_capture_response(capture, twin_public_id)

    @staticmethod
    def delete_capture(db: Session, user: User, capture_id: str) -> None:
        """
        Delete a capture record from DB and remove its private storage file.
        Updates baseline_capture_id and last_capture_at on parent SkinTwin.
        """
        capture = db.query(Capture).filter(Capture.id == capture_id).first()
        if not capture or capture.user_id != user.id:
            raise NotFoundException(message="Capture not found.", code="CAPTURE_NOT_FOUND")

        twin = db.query(SkinTwin).filter(SkinTwin.id == capture.skintwin_id).first()
        object_key = capture.image_object_key

        db.delete(capture)

        if twin:
            # Check if this was baseline capture
            if twin.baseline_capture_id == capture_id:
                remaining = (
                    db.query(Capture)
                    .filter(Capture.skintwin_id == twin.id, Capture.id != capture_id)
                    .order_by(Capture.captured_at.asc())
                    .first()
                )
                twin.baseline_capture_id = remaining.id if remaining else None

            # Update last_capture_at
            latest = (
                db.query(Capture)
                .filter(Capture.skintwin_id == twin.id, Capture.id != capture_id)
                .order_by(Capture.captured_at.desc())
                .first()
            )
            twin.last_capture_at = latest.captured_at if latest else None

        db.commit()

        # Clean up storage file safely
        storage = get_storage_adapter()
        deleted = storage.delete_file(object_key)
        if not deleted:
            logger.warning(
                f"Storage file for object_key '{object_key}' could not be removed during capture deletion."
            )

    @staticmethod
    def get_capture_image_bytes(db: Session, user: User, capture_id: str) -> tuple[bytes, str]:
        """
        Securely retrieve private capture image bytes and MIME type.
        Returns 404 if capture doesn't exist or belongs to another user.
        """
        capture = db.query(Capture).filter(Capture.id == capture_id).first()
        if not capture or capture.user_id != user.id:
            raise NotFoundException(message="Capture not found.", code="CAPTURE_NOT_FOUND")

        storage = get_storage_adapter()
        image_bytes = storage.get_file(capture.image_object_key)

        # Infer MIME type from object_key extension
        ext = capture.image_object_key.split(".")[-1].lower()
        mime_type = "image/jpeg"
        if ext == "png":
            mime_type = "image/png"
        elif ext == "webp":
            mime_type = "image/webp"

        return image_bytes, mime_type

    @staticmethod
    def evaluate_coach(
        db: Session,
        user: User,
        skintwin_public_id: str,
        file_bytes: bytes,
        filename: str = "capture.jpg",
    ) -> CaptureCoachResponse:
        """
        Evaluate an unuploaded or candidate image against capture coach quality thresholds
        and baseline consistency. Does not persist the image or alter DB state.
        """
        twin = _get_owned_twin(db, skintwin_public_id, user)
        baseline_bytes = None
        if twin.baseline_capture_id:
            try:
                base_cap = db.query(Capture).filter(Capture.id == twin.baseline_capture_id).first()
                if base_cap and base_cap.image_object_key:
                    storage = get_storage_adapter()
                    baseline_bytes = storage.get_file(base_cap.image_object_key)
            except Exception as e:
                logger.warning(f"Could not load baseline image for coach evaluation: {e}")

        return CaptureCoachService.evaluate_capture(file_bytes, baseline_bytes)
