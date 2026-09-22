from typing import Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from app.dependencies.db import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.capture import CaptureResponse, CaptureListResponse, CaptureCoachResponse
from app.services.capture_service import CaptureService

router = APIRouter()


@router.post(
    "/skintwins/{public_id}/captures/coach",
    response_model=CaptureCoachResponse,
    status_code=status.HTTP_200_OK,
    summary="Evaluate an image candidate against capture coach quality & baseline consistency guidelines",
)
async def evaluate_skintwin_capture_coach(
    public_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Evaluate photo sharpness, lighting, contrast, resolution, framing, and baseline consistency.
    Returns prioritized guidance, blocking/override readiness status, and actionable recommendations
    without persisting or saving the file.
    """
    file_bytes = await file.read()
    filename = file.filename or "candidate.jpg"
    return CaptureService.evaluate_coach(
        db=db,
        user=current_user,
        skintwin_public_id=public_id,
        file_bytes=file_bytes,
        filename=filename,
    )


@router.post(
    "/skintwins/{public_id}/captures",
    response_model=CaptureResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a new capture for a SkinTwin",
)
async def upload_skintwin_capture(
    public_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    device_metadata: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload an image for a SkinTwin owned by the authenticated user.
    Validates JPEG/PNG/WebP formats, magic bytes, file size, and computes SHA-256 hash.
    Saves image to private storage.
    """
    file_bytes = await file.read()
    filename = file.filename or "uploaded_image"
    return CaptureService.create_capture(
        db=db,
        user=current_user,
        skintwin_public_id=public_id,
        file_bytes=file_bytes,
        filename=filename,
        notes=notes,
        device_metadata=device_metadata,
    )


@router.get(
    "/skintwins/{public_id}/captures",
    response_model=CaptureListResponse,
    summary="List all captures for a SkinTwin",
)
def list_skintwin_captures(
    public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all captures for a specific SkinTwin owned by the authenticated user."""
    items = CaptureService.list_for_skintwin(db, current_user, public_id)
    return CaptureListResponse(total=len(items), items=items)


@router.get(
    "/captures/{capture_id}",
    response_model=CaptureResponse,
    summary="Get capture details by capture_id",
)
def get_capture(
    capture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get metadata for a specific capture.
    Returns 404 if capture does not exist or belongs to another user.
    """
    return CaptureService.get_by_id(db, current_user, capture_id)


@router.get(
    "/captures/{capture_id}/image",
    summary="Securely stream binary image for an authorized capture",
    responses={
        200: {"content": {"image/jpeg": {}, "image/png": {}, "image/webp": {}}},
    },
)
def get_capture_image(
    capture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Stream private capture image bytes for authorized users only.
    Returns 404 if capture does not exist or belongs to another user.
    """
    image_bytes, mime_type = CaptureService.get_capture_image_bytes(db, current_user, capture_id)
    return Response(content=image_bytes, media_type=mime_type)


@router.delete(
    "/captures/{capture_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a capture",
)
def delete_capture(
    capture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Permanently delete a capture record and its private storage file.
    Only the authenticated owner can delete their capture.
    """
    CaptureService.delete_capture(db, current_user, capture_id)
