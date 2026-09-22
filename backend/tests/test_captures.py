import io
import pytest
from app.services.storage import get_storage_adapter


# ── Sample Binary Image Buffers ───────────────────────────────────────────────

import cv2
import numpy as np

def _make_test_jpeg():
    img = np.full((400, 400, 3), 120, dtype=np.uint8)
    for i in range(0, 400, 20):
        cv2.line(img, (i, 0), (i, 400), (255, 255, 255), 2)
    _, buf = cv2.imencode(".jpg", img)
    return buf.tobytes()

def _make_test_png():
    img = np.full((400, 400, 3), 120, dtype=np.uint8)
    _, buf = cv2.imencode(".png", img)
    return buf.tobytes()

def _make_test_webp():
    img = np.full((400, 400, 3), 120, dtype=np.uint8)
    _, buf = cv2.imencode(".webp", img)
    return buf.tobytes()

SAMPLE_JPEG_BYTES = _make_test_jpeg()
SAMPLE_PNG_BYTES = _make_test_png()
SAMPLE_WEBP_BYTES = _make_test_webp()

INVALID_MAGIC_BYTES = b"NOT_AN_IMAGE_FILE_DATA_HERE"


# ── Helpers ────────────────────────────────────────────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Forearm Mole"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "forearm", "body_side": "right"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


# ── Authentication Tests ───────────────────────────────────────────────────────

def test_upload_capture_unauthorized(client):
    token = _register_and_login(client, "auth_cap_1@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("test.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
    )
    assert res.status_code == 401


def test_upload_capture_invalid_token(client):
    token = _register_and_login(client, "auth_cap_2@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("test.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers={"Authorization": "Bearer invalid_token_xyz"},
    )
    assert res.status_code == 401


# ── Validation Tests ───────────────────────────────────────────────────────────

def test_upload_jpeg_success(client):
    token = _register_and_login(client, "jpeg_user@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("my_photo.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()
    assert data["skintwin_public_id"] == public_id
    assert data["quality_status"] == "acceptable"
    assert data["image_hash"] is not None
    assert len(data["image_hash"]) == 64  # SHA-256 length
    assert "users/" in data["image_object_key"]
    # Verify original filename is NOT used in object key
    assert "my_photo.jpg" not in data["image_object_key"]

    # Verify storage file actually exists
    storage = get_storage_adapter()
    assert storage.exists(data["image_object_key"])


def test_upload_png_success(client):
    token = _register_and_login(client, "png_user@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("sample.png", SAMPLE_PNG_BYTES, "image/png")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    assert res.json()["image_object_key"].endswith(".png")


def test_upload_webp_success(client):
    token = _register_and_login(client, "webp_user@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("photo.webp", SAMPLE_WEBP_BYTES, "image/webp")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    assert res.json()["image_object_key"].endswith(".webp")


def test_upload_invalid_magic_bytes(client):
    token = _register_and_login(client, "badbytes@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("fake.jpg", INVALID_MAGIC_BYTES, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "UNSUPPORTED_IMAGE_FORMAT"


def test_upload_empty_file(client):
    token = _register_and_login(client, "emptyfile@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("empty.jpg", b"", "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "EMPTY_FILE"


def test_upload_oversized_file(client, monkeypatch):
    token = _register_and_login(client, "oversized@example.com")
    public_id = _create_twin(client, token)

    # Temporarily set max size to 50 bytes for test
    from app.core import config
    monkeypatch.setattr(config.settings, "MAX_UPLOAD_SIZE_BYTES", 50)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("large.jpg", SAMPLE_JPEG_BYTES * 5, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 413
    assert res.json()["error"]["code"] == "FILE_TOO_LARGE"


def test_upload_unsafe_filename(client):
    token = _register_and_login(client, "unsafename@example.com")
    public_id = _create_twin(client, token)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("../../../etc/passwd.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    key = res.json()["image_object_key"]
    assert "passwd" not in key
    assert "../" not in key


# ── Ownership & Cross-User Protection Tests ────────────────────────────────────

def test_cross_user_upload_returns_404(client):
    token_a = _register_and_login(client, "owner_a@example.com")
    token_b = _register_and_login(client, "intruder_b@example.com")
    public_id_a = _create_twin(client, token_a)

    res = client.post(
        f"/api/v1/skintwins/{public_id_a}/captures",
        files={"file": ("photo.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers=_auth_headers(token_b),
    )
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


def test_cross_user_list_returns_404(client):
    token_a = _register_and_login(client, "owner_list_a@example.com")
    token_b = _register_and_login(client, "intruder_list_b@example.com")
    public_id_a = _create_twin(client, token_a)

    res = client.get(
        f"/api/v1/skintwins/{public_id_a}/captures",
        headers=_auth_headers(token_b),
    )
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


def test_cross_user_get_capture_returns_404(client):
    token_a = _register_and_login(client, "owner_cap_a@example.com")
    token_b = _register_and_login(client, "intruder_cap_b@example.com")
    public_id_a = _create_twin(client, token_a)

    upload_res = client.post(
        f"/api/v1/skintwins/{public_id_a}/captures",
        files={"file": ("photo.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers=_auth_headers(token_a),
    )
    capture_id = upload_res.json()["id"]

    res = client.get(f"/api/v1/captures/{capture_id}", headers=_auth_headers(token_b))
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "CAPTURE_NOT_FOUND"


def test_cross_user_delete_capture_returns_404(client):
    token_a = _register_and_login(client, "owner_del_a@example.com")
    token_b = _register_and_login(client, "intruder_del_b@example.com")
    public_id_a = _create_twin(client, token_a)

    upload_res = client.post(
        f"/api/v1/skintwins/{public_id_a}/captures",
        files={"file": ("photo.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        headers=_auth_headers(token_a),
    )
    capture_id = upload_res.json()["id"]

    res = client.delete(f"/api/v1/captures/{capture_id}", headers=_auth_headers(token_b))
    assert res.status_code == 404

    # Ensure capture is NOT deleted
    get_res = client.get(f"/api/v1/captures/{capture_id}", headers=_auth_headers(token_a))
    assert get_res.status_code == 200


# ── Database & Lifecycle Tests ─────────────────────────────────────────────────

def test_capture_lifecycle_and_skintwin_updates(client):
    token = _register_and_login(client, "lifecycle@example.com")
    public_id = _create_twin(client, token)

    # 1. Upload initial capture (should become baseline)
    res1 = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("photo1.jpg", SAMPLE_JPEG_BYTES, "image/jpeg")},
        data={"notes": "First baseline photo"},
        headers=_auth_headers(token),
    )
    assert res1.status_code == 201
    cap1 = res1.json()

    # Check SkinTwin updated
    twin_res1 = client.get(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token))
    assert twin_res1.json()["capture_count"] == 1
    assert twin_res1.json()["last_capture_at"] is not None

    # 2. Upload second capture
    res2 = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": ("photo2.png", SAMPLE_PNG_BYTES, "image/png")},
        headers=_auth_headers(token),
    )
    assert res2.status_code == 201
    cap2 = res2.json()

    # List captures
    list_res = client.get(f"/api/v1/skintwins/{public_id}/captures", headers=_auth_headers(token))
    assert list_res.status_code == 200
    assert list_res.json()["total"] == 2

    # 3. Get single capture detail
    detail_res = client.get(f"/api/v1/captures/{cap1['id']}", headers=_auth_headers(token))
    assert detail_res.status_code == 200
    assert detail_res.json()["notes"] == "First baseline photo"

    # 4. Delete first capture
    del_res = client.delete(f"/api/v1/captures/{cap1['id']}", headers=_auth_headers(token))
    assert del_res.status_code == 204

    # Verify storage cleanup
    storage = get_storage_adapter()
    assert not storage.exists(cap1["image_object_key"])

    # List captures should now show 1 item
    list_res_after = client.get(f"/api/v1/skintwins/{public_id}/captures", headers=_auth_headers(token))
    assert list_res_after.json()["total"] == 1
    assert list_res_after.json()["items"][0]["id"] == cap2["id"]
