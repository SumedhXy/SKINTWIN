import cv2
import numpy as np
import pytest
from app.services.image_quality_service import ImageQualityService


# ── Synthetic Image Generators ─────────────────────────────────────────────────

def _make_clear_jpeg_bytes() -> bytes:
    """Generate a sharp, well-lit, high-contrast 400x400 image."""
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    # Fill with medium background (120)
    img.fill(120)
    # Add sharp high-contrast grid lines
    for i in range(0, 400, 20):
        cv2.line(img, (i, 0), (i, 400), (255, 255, 255), 2)
        cv2.line(img, (0, i), (400, i), (0, 0, 0), 2)
    # Add circle
    cv2.circle(img, (200, 200), 50, (50, 180, 50), -1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_blurry_jpeg_bytes() -> bytes:
    """Generate a heavily blurred image."""
    clear_bytes = _make_clear_jpeg_bytes()
    np_arr = np.frombuffer(clear_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    # Apply severe Gaussian blur
    blurred = cv2.GaussianBlur(img, (55, 55), 0)
    _, encoded = cv2.imencode(".jpg", blurred)
    return encoded.tobytes()


def _make_dark_jpeg_bytes() -> bytes:
    """Generate an underexposed / dark image."""
    img = np.full((400, 400, 3), 15, dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_overexposed_jpeg_bytes() -> bytes:
    """Generate an overexposed / bright image."""
    img = np.full((400, 400, 3), 245, dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_lowres_jpeg_bytes() -> bytes:
    """Generate a low-resolution image (80x80)."""
    img = np.full((80, 80, 3), 120, dtype=np.uint8)
    cv2.line(img, (0, 0), (80, 80), (255, 255, 255), 1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


# ── Auth & Helper Functions for API Integration ───────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Quality Mole"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "arm", "body_side": "left"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


# ── Direct Unit Tests for ImageQualityService ──────────────────────────────────

def test_quality_service_clear_image():
    file_bytes = _make_clear_jpeg_bytes()
    res = ImageQualityService.evaluate(file_bytes)
    assert res.quality_status == "acceptable"
    assert res.blur_status == "pass"
    assert res.lighting_status == "pass"
    assert res.resolution_status == "pass"
    assert res.framing_status == "unknown"
    assert res.comparison_eligible is True
    assert res.quality_score is not None and res.quality_score >= 0.8
    assert "resolution" in res.quality_details


def test_quality_service_blurry_image():
    file_bytes = _make_blurry_jpeg_bytes()
    res = ImageQualityService.evaluate(file_bytes)
    assert res.blur_status == "fail"
    assert res.quality_status == "unacceptable"
    assert res.comparison_eligible is False


def test_quality_service_dark_image():
    file_bytes = _make_dark_jpeg_bytes()
    res = ImageQualityService.evaluate(file_bytes)
    assert res.lighting_status == "fail"
    assert res.quality_status == "unacceptable"
    assert res.comparison_eligible is False


def test_quality_service_overexposed_image():
    file_bytes = _make_overexposed_jpeg_bytes()
    res = ImageQualityService.evaluate(file_bytes)
    assert res.lighting_status == "fail"
    assert res.quality_status == "unacceptable"
    assert res.comparison_eligible is False


def test_quality_service_lowres_image():
    file_bytes = _make_lowres_jpeg_bytes()
    res = ImageQualityService.evaluate(file_bytes)
    assert res.resolution_status == "fail"
    assert res.quality_status == "unacceptable"
    assert res.comparison_eligible is False


def test_quality_service_corrupt_bytes():
    corrupt_bytes = b"CORRUPT_NON_IMAGE_DATA_BYTES_HERE"
    res = ImageQualityService.evaluate(corrupt_bytes)
    assert res.quality_status == "unacceptable"
    assert res.comparison_eligible is False
    assert "reason" in res.quality_details


# ── API Integration Tests ──────────────────────────────────────────────────────

def test_api_upload_quality_integration_acceptable(client):
    token = _register_and_login(client, "qual_pass@example.com")
    public_id = _create_twin(client, token)
    clear_bytes = _make_clear_jpeg_bytes()

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("clear.jpg", clear_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()
    assert data["quality_status"] == "acceptable"
    assert data["blur_status"] == "pass"
    assert data["lighting_status"] == "pass"
    assert data["resolution_status"] == "pass"
    assert data["framing_status"] == "unknown"
    assert data["comparison_eligible"] is True
    assert data["quality_details"] is not None
    assert "resolution" in data["quality_details"]


def test_api_upload_quality_integration_blurry(client):
    token = _register_and_login(client, "qual_blur@example.com")
    public_id = _create_twin(client, token)
    blurry_bytes = _make_blurry_jpeg_bytes()

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("blurry.jpg", blurry_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()
    assert data["quality_status"] == "unacceptable"
    assert data["blur_status"] == "fail"
    assert data["comparison_eligible"] is False
