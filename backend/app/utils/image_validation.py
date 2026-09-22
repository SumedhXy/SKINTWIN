import hashlib
from typing import Tuple
from app.core.config import settings
from app.core.errors import SkinTwinException
from fastapi import status


def validate_and_inspect_image(file_bytes: bytes, filename: str) -> Tuple[str, str, str]:
    """
    Validates uploaded image bytes against size limits, empty check, and magic bytes.

    Returns:
        (detected_format, detected_mime_type, file_extension)

    Raises:
        SkinTwinException: If file is empty, too large, or fails magic byte verification.
    """
    # 1. Empty file check
    if not file_bytes or len(file_bytes) == 0:
        raise SkinTwinException(
            code="EMPTY_FILE",
            message="Uploaded file is empty.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    # 2. Size limit check
    if len(file_bytes) > settings.MAX_UPLOAD_SIZE_BYTES:
        max_mb = settings.MAX_UPLOAD_SIZE_BYTES / (1024 * 1024)
        raise SkinTwinException(
            code="FILE_TOO_LARGE",
            message=f"File size exceeds the maximum limit of {max_mb:.1f} MB.",
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        )

    # 3. Magic byte signature verification
    # JPEG magic bytes: FF D8 FF
    if file_bytes.startswith(b"\xff\xd8\xff"):
        return "JPEG", "image/jpeg", "jpg"

    # PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
    if file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "PNG", "image/png", "png"

    # WebP magic bytes: RIFF....WEBP
    if len(file_bytes) >= 12 and file_bytes.startswith(b"RIFF") and file_bytes[8:12] == b"WEBP":
        return "WEBP", "image/webp", "webp"

    # Unsupported signature
    raise SkinTwinException(
        code="UNSUPPORTED_IMAGE_FORMAT",
        message="Unsupported image format. Allowed formats: JPEG, PNG, WebP.",
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def compute_sha256(file_bytes: bytes) -> str:
    """Compute SHA-256 hex digest of file bytes."""
    return hashlib.sha256(file_bytes).hexdigest()
