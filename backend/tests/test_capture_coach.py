import cv2
import numpy as np
import pytest
from app.services.capture_coach_service import CaptureCoachService


# ── Synthetic Image Helpers ───────────────────────────────────────────────────

def _make_clear_jpeg_bytes(width: int = 400, height: int = 400, brightness: int = 120) -> bytes:
    """Generate a sharp, well-lit, high-contrast image."""
    img = np.full((height, width, 3), brightness, dtype=np.uint8)
    for i in range(0, max(width, height), 25):
        if i < width:
            cv2.line(img, (i, 0), (i, height), (210, 210, 210), 2)
        if i < height:
            cv2.line(img, (0, i), (width, i), (40, 40, 40), 2)
    cv2.circle(img, (width // 2, height // 2), min(width, height) // 8, (50, 180, 50), -1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_blurry_jpeg_bytes() -> bytes:
    """Generate a heavily blurred image (< 50 var)."""
    clear_bytes = _make_clear_jpeg_bytes()
    np_arr = np.frombuffer(clear_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    blurred = cv2.GaussianBlur(img, (55, 55), 0)
    _, encoded = cv2.imencode(".jpg", blurred)
    return encoded.tobytes()


def _make_slightly_blurry_jpeg_bytes() -> bytes:
    """Generate a moderately blurred image with Laplacian variance between 50 and 99."""
    img = np.full((400, 400, 3), 120, dtype=np.uint8)
    for i in range(0, 400, 20):
        cv2.line(img, (i, 0), (i, 400), (210, 210, 210), 2)
        cv2.line(img, (0, i), (400, i), (40, 40, 40), 2)
    blurred = cv2.GaussianBlur(img, (9, 9), 1.6)
    _, encoded = cv2.imencode(".jpg", blurred)
    return encoded.tobytes()


def _make_dark_jpeg_bytes() -> bytes:
    """Generate an underexposed dark image (< 35 mean)."""
    img = np.full((400, 400, 3), 15, dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_overexposed_jpeg_bytes() -> bytes:
    """Generate an overexposed bright image (> 225 mean)."""
    img = np.full((400, 400, 3), 245, dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_lowres_jpeg_bytes() -> bytes:
    """Generate a low-resolution image (< 150px)."""
    img = np.full((100, 100, 3), 120, dtype=np.uint8)
    cv2.line(img, (0, 0), (100, 100), (255, 255, 255), 1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_modres_jpeg_bytes() -> bytes:
    """Generate a moderate-resolution image (200x200)."""
    img = np.full((200, 200, 3), 120, dtype=np.uint8)
    for i in range(0, 200, 20):
        cv2.line(img, (i, 0), (i, 200), (255, 255, 255), 2)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


# ── Auth & Helper Functions ───────────────────────────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Coach Mole"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "arm", "body_side": "left"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


# ── Unit Tests: CaptureCoachService ───────────────────────────────────────────

def test_coach_service_clear_image():
    file_bytes = _make_clear_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "ready"
    assert res.can_continue is True
    assert res.quality_score is not None and res.quality_score >= 0.8
    assert "ready for comparison" in res.primary_message.lower() or "clear" in res.primary_message.lower()
    assert len(res.checks) >= 4
    categories = [c.category for c in res.checks]
    assert "sharpness" in categories
    assert "lighting" in categories
    assert "resolution" in categories
    assert "framing" in categories
    assert len(res.limitations) > 0


def test_coach_service_severe_blur_is_blocked():
    file_bytes = _make_blurry_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "blocked"
    assert res.can_continue is False
    blur_check = next(c for c in res.checks if c.category == "sharpness")
    assert blur_check.status == "fail"
    assert "blurry" in res.primary_message.lower()


def test_coach_service_moderate_blur_needs_adjustment_override_allowed():
    file_bytes = _make_slightly_blurry_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    # Moderate blur allows override
    assert res.status == "needs_adjustment"
    assert res.can_continue is True
    blur_check = next(c for c in res.checks if c.category == "sharpness")
    assert blur_check.status == "warning"


def test_coach_service_dark_image_is_blocked():
    file_bytes = _make_dark_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "blocked"
    assert res.can_continue is False
    light_check = next(c for c in res.checks if c.category == "lighting")
    assert light_check.status == "fail"


def test_coach_service_overexposed_image_is_blocked():
    file_bytes = _make_overexposed_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "blocked"
    assert res.can_continue is False
    light_check = next(c for c in res.checks if c.category == "lighting")
    assert light_check.status == "fail"


def test_coach_service_lowres_is_blocked():
    file_bytes = _make_lowres_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "blocked"
    assert res.can_continue is False
    res_check = next(c for c in res.checks if c.category == "resolution")
    assert res_check.status == "fail"


def test_coach_service_modres_needs_adjustment_allowed():
    file_bytes = _make_modres_jpeg_bytes()
    res = CaptureCoachService.evaluate_capture(file_bytes)
    assert res.status == "needs_adjustment"
    assert res.can_continue is True
    res_check = next(c for c in res.checks if c.category == "resolution")
    assert res_check.status == "warning"


def test_coach_service_corrupt_bytes():
    res = CaptureCoachService.evaluate_capture(b"NOT_A_VALID_IMAGE")
    assert res.status == "blocked"
    assert res.can_continue is False


def test_coach_service_baseline_consistency_match():
    base_bytes = _make_clear_jpeg_bytes(400, 400, 120)
    curr_bytes = _make_clear_jpeg_bytes(400, 400, 125)
    res = CaptureCoachService.evaluate_capture(curr_bytes, baseline_bytes=base_bytes)
    assert res.has_baseline_comparison is True
    base_check = next((c for c in res.checks if c.category == "baseline_consistency"), None)
    assert base_check is not None
    assert base_check.status == "pass"


def test_coach_service_baseline_consistency_lighting_difference():
    base_bytes = _make_clear_jpeg_bytes(400, 400, 80)
    curr_bytes = _make_clear_jpeg_bytes(400, 400, 190)
    res = CaptureCoachService.evaluate_capture(curr_bytes, baseline_bytes=base_bytes)
    assert res.has_baseline_comparison is True
    base_check = next((c for c in res.checks if c.category == "baseline_consistency"), None)
    assert base_check is not None
    assert base_check.status == "warning"


# ── Integration Tests: Endpoints ───────────────────────────────────────────────

def test_api_coach_endpoint_success(client):
    token = _register_and_login(client, "coach_user1@example.com")
    twin_id = _create_twin(client, token)
    clear_bytes = _make_clear_jpeg_bytes()

    res = client.post(
        f"/api/v1/skintwins/{twin_id}/captures/coach",
        files={"file": ("photo.jpg", clear_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] in ["ready", "needs_adjustment"]
    assert data["can_continue"] is True
    assert len(data["checks"]) >= 4
    assert len(data["suggestions"]) > 0


def test_api_coach_endpoint_blurry_blocked(client):
    token = _register_and_login(client, "coach_user2@example.com")
    twin_id = _create_twin(client, token)
    blurry_bytes = _make_blurry_jpeg_bytes()

    res = client.post(
        f"/api/v1/skintwins/{twin_id}/captures/coach",
        files={"file": ("blur.jpg", blurry_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "blocked"
    assert data["can_continue"] is False


def test_api_coach_endpoint_unauthorized(client):
    clear_bytes = _make_clear_jpeg_bytes()
    res = client.post(
        "/api/v1/skintwins/any-id/captures/coach",
        files={"file": ("photo.jpg", clear_bytes, "image/jpeg")},
    )
    assert res.status_code == 401


def test_api_coach_endpoint_other_user_forbidden(client):
    token_a = _register_and_login(client, "user_a@example.com")
    token_b = _register_and_login(client, "user_b@example.com")
    twin_a = _create_twin(client, token_a, "Twin A")
    clear_bytes = _make_clear_jpeg_bytes()

    # User B tries to coach User A's twin
    res = client.post(
        f"/api/v1/skintwins/{twin_a}/captures/coach",
        files={"file": ("photo.jpg", clear_bytes, "image/jpeg")},
        headers=_auth_headers(token_b),
    )
    assert res.status_code == 404


def test_api_upload_captures_includes_coach_details(client):
    token = _register_and_login(client, "coach_upload@example.com")
    twin_id = _create_twin(client, token)
    clear_bytes = _make_clear_jpeg_bytes()

    res = client.post(
        f"/api/v1/skintwins/{twin_id}/captures",
        files={"file": ("clear.jpg", clear_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()
    assert data["quality_details"] is not None
    assert "coach" in data["quality_details"]
    assert data["quality_details"]["coach"]["status"] in ["ready", "needs_adjustment"]
