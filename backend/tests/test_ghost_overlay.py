import numpy as np
import cv2
import pytest
from app.services.alignment_service import AlignmentService


def _make_sample_image(width=300, height=300, color=(140, 140, 140)):
    img = np.full((height, width, 3), color, dtype=np.uint8)
    for i in range(0, min(width, height), 25):
        cv2.line(img, (i, 0), (i, height), (240, 240, 240), 2)
        cv2.circle(img, (width // 2, height // 2), 30, (40, 40, 40), -1)
    return img


def _encode_jpeg(img):
    _, buf = cv2.imencode(".jpg", img)
    return buf.tobytes()


SAMPLE_JPEG_1 = _encode_jpeg(_make_sample_image(300, 300))
SAMPLE_JPEG_2 = _encode_jpeg(_make_sample_image(300, 300, color=(160, 160, 160)))


def _register_and_login(client, email: str, password: str = "SecurePass123!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Ghost User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Ghost SkinTwin"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "back", "body_side": "center"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


def _upload_capture(client, token: str, public_id: str, file_bytes=SAMPLE_JPEG_1, filename="ghost.jpg"):
    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": (filename, file_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    return res.json()


# -----------------------------------------------------------------------------
# 1. PURE ALIGNMENT ENGINE TESTS
# -----------------------------------------------------------------------------

def test_alignment_service_valid_pair():
    """Verify AlignmentService produces valid homography and score on structured image pair."""
    img1 = _make_sample_image(300, 300)
    # Slight shift for img2
    M = np.float32([[1, 0, 5], [0, 1, 5]])
    img2 = cv2.warpAffine(img1, M, (300, 300))

    res = AlignmentService.align_image_pair(img1, img2)
    assert res["alignment_status"] in ["aligned", "partially_aligned"]
    assert res["alignment_score"] > 0.0
    assert res["match_count"] >= 4
    assert res["aligned_latest_image"] is not None


def test_alignment_service_invalid_or_empty_inputs():
    """Verify AlignmentService handles empty/None images safely without unhandled crashes."""
    res_none = AlignmentService.align_image_pair(None, None)
    assert res_none["alignment_status"] == "failed"
    assert res_none["alignment_error_code"] == "INVALID_IMAGE_INPUT"

    empty_img = np.zeros((0, 0, 3), dtype=np.uint8)
    res_empty = AlignmentService.align_image_pair(empty_img, empty_img)
    assert res_empty["alignment_status"] == "failed"
    assert res_empty["alignment_error_code"] == "INVALID_IMAGE_INPUT"


def test_alignment_service_featureless_uniform_images():
    """Verify featureless images cleanly report INSUFFICIENT_KEYPOINTS."""
    flat1 = np.full((100, 100, 3), 128, dtype=np.uint8)
    flat2 = np.full((100, 100, 3), 128, dtype=np.uint8)

    res = AlignmentService.align_image_pair(flat1, flat2)
    assert res["alignment_status"] == "failed"
    assert res["alignment_error_code"] in ["INSUFFICIENT_KEYPOINTS", "INSUFFICIENT_MATCHES", "HOMOGRAPHY_FAILED"]


# -----------------------------------------------------------------------------
# 2. PRIVACY, AUTHORIZATION & SECURE IMAGE STREAMING
# -----------------------------------------------------------------------------

def test_secure_capture_image_streaming(client):
    """Verify authorized user can stream their private capture image bytes."""
    token = _register_and_login(client, "ghost_auth@example.com")
    twin_id = _create_twin(client, token)
    cap = _upload_capture(client, token, twin_id, SAMPLE_JPEG_1)

    res = client.get(f"/api/v1/captures/{cap['id']}/image", headers=_auth_headers(token))
    assert res.status_code == 200
    assert res.headers["content-type"] in ["image/jpeg", "image/png", "image/webp"]
    assert len(res.content) > 0


def test_unauthorized_user_cannot_access_capture_image(client):
    """Verify unauthenticated user cannot access capture images (401)."""
    token = _register_and_login(client, "ghost_owner@example.com")
    twin_id = _create_twin(client, token)
    cap = _upload_capture(client, token, twin_id, SAMPLE_JPEG_1)

    res = client.get(f"/api/v1/captures/{cap['id']}/image")
    assert res.status_code in [401, 403]


def test_cross_user_capture_image_access_rejected(client):
    """Verify user B cannot access user A's private capture images (404/403)."""
    token_a = _register_and_login(client, "user_a_ghost@example.com")
    token_b = _register_and_login(client, "user_b_ghost@example.com")

    twin_a = _create_twin(client, token_a)
    cap_a = _upload_capture(client, token_a, twin_a, SAMPLE_JPEG_1)

    res_b = client.get(f"/api/v1/captures/{cap_a['id']}/image", headers=_auth_headers(token_b))
    assert res_b.status_code == 404


def test_deleted_capture_image_returns_404(client):
    """Verify accessing a deleted capture image returns 404."""
    token = _register_and_login(client, "ghost_delete@example.com")
    twin_id = _create_twin(client, token)
    cap = _upload_capture(client, token, twin_id, SAMPLE_JPEG_1)

    # Delete capture
    del_res = client.delete(f"/api/v1/captures/{cap['id']}", headers=_auth_headers(token))
    assert del_res.status_code == 204

    # Try to access deleted image
    res = client.get(f"/api/v1/captures/{cap['id']}/image", headers=_auth_headers(token))
    assert res.status_code == 404
