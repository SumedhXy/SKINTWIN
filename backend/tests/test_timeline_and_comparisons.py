import time
from datetime import datetime, timezone, timedelta
from app.services.storage import get_storage_adapter

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

SAMPLE_JPEG_BYTES = _make_test_jpeg()
SAMPLE_PNG_BYTES = _make_test_png()


# ── Helpers ────────────────────────────────────────────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Back Mole"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "back", "body_side": "center"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


def _upload_capture(client, token: str, public_id: str, file_bytes=SAMPLE_JPEG_BYTES, filename="test.jpg", notes=None):
    data = {}
    if notes:
        data["notes"] = notes
    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": (filename, file_bytes, "image/jpeg")},
        data=data,
        headers=_auth_headers(token),
    )
    return res.json()


# ── Timeline Tests ─────────────────────────────────────────────────────────────

def test_timeline_empty(client):
    token = _register_and_login(client, "empty_tl@example.com")
    public_id = _create_twin(client, token)

    res = client.get(f"/api/v1/skintwins/{public_id}/timeline", headers=_auth_headers(token))
    assert res.status_code == 200
    data = res.json()
    assert data["skintwin_public_id"] == public_id
    assert data["total_captures"] == 0
    assert data["items"] == []
    assert data["baseline_capture_id"] is None


def test_timeline_ordering_and_baseline(client):
    token = _register_and_login(client, "tl_order@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id, notes="First")
    time.sleep(0.01)
    cap2 = _upload_capture(client, token, public_id, notes="Second")

    # Default desc order (newest first)
    res_desc = client.get(f"/api/v1/skintwins/{public_id}/timeline?order=desc", headers=_auth_headers(token))
    assert res_desc.status_code == 200
    desc_data = res_desc.json()
    assert desc_data["total_captures"] == 2
    assert desc_data["baseline_capture_id"] == cap1["id"]
    assert desc_data["items"][0]["id"] == cap2["id"]
    assert desc_data["items"][1]["id"] == cap1["id"]

    # Asc order (oldest first)
    res_asc = client.get(f"/api/v1/skintwins/{public_id}/timeline?order=asc", headers=_auth_headers(token))
    assert res_asc.status_code == 200
    asc_data = res_asc.json()
    assert asc_data["items"][0]["id"] == cap1["id"]
    assert asc_data["items"][1]["id"] == cap2["id"]


def test_timeline_pagination(client):
    token = _register_and_login(client, "tl_page@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id)
    cap2 = _upload_capture(client, token, public_id)
    cap3 = _upload_capture(client, token, public_id)

    res = client.get(f"/api/v1/skintwins/{public_id}/timeline?limit=2&offset=1", headers=_auth_headers(token))
    assert res.status_code == 200
    data = res.json()
    assert data["total_captures"] == 3
    assert len(data["items"]) == 2


def test_timeline_cross_user_returns_404(client):
    token_a = _register_and_login(client, "tl_owner_a@example.com")
    token_b = _register_and_login(client, "tl_intruder_b@example.com")
    public_id_a = _create_twin(client, token_a)

    res = client.get(f"/api/v1/skintwins/{public_id_a}/timeline", headers=_auth_headers(token_b))
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


def test_segmentation_model_is_reused_for_speed():
    from app.services.segmentation import get_segmentation_model

    model_a = get_segmentation_model()
    model_b = get_segmentation_model()

    assert model_a is model_b


def test_timeline_unauthorized(client):
    token = _register_and_login(client, "tl_unauth@example.com")
    public_id = _create_twin(client, token)

    res = client.get(f"/api/v1/skintwins/{public_id}/timeline")
    assert res.status_code == 401


# ── Authorized Image Retrieval Tests ──────────────────────────────────────────

def test_get_capture_image_success(client):
    token = _register_and_login(client, "img_stream@example.com")
    public_id = _create_twin(client, token)

    cap = _upload_capture(client, token, public_id, file_bytes=SAMPLE_JPEG_BYTES)
    res = client.get(f"/api/v1/captures/{cap['id']}/image", headers=_auth_headers(token))
    assert res.status_code == 200
    assert res.content == SAMPLE_JPEG_BYTES
    assert "image/jpeg" in res.headers["content-type"]


def test_get_capture_image_cross_user_returns_404(client):
    token_a = _register_and_login(client, "img_owner@example.com")
    token_b = _register_and_login(client, "img_intruder@example.com")
    public_id = _create_twin(client, token_a)
    cap = _upload_capture(client, token_a, public_id)

    res = client.get(f"/api/v1/captures/{cap['id']}/image", headers=_auth_headers(token_b))
    assert res.status_code == 404


def test_get_capture_image_unauthorized(client):
    token = _register_and_login(client, "img_unauth@example.com")
    public_id = _create_twin(client, token)
    cap = _upload_capture(client, token, public_id)

    res = client.get(f"/api/v1/captures/{cap['id']}/image")
    assert res.status_code == 401


# ── Comparison Tests ───────────────────────────────────────────────────────────

def test_create_comparison_success(client):
    token = _register_and_login(client, "comp_create@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id, notes="Earlier capture")
    time.sleep(0.01)
    cap2 = _upload_capture(client, token, public_id, notes="Latest capture")

    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()
    assert data["skintwin_public_id"] == public_id
    assert data["earlier_capture_id"] == cap1["id"]
    assert data["latest_capture_id"] == cap2["id"]
    assert data["comparison_status"] in ["completed", "not_analyzed"]
    assert data["alignment_status"] in ["aligned", "partially_aligned", "failed", "not_evaluated"]
    assert data["reliability_status"] in ["reliable", "needs_review", "unreliable", "unavailable"]


def test_create_comparison_same_capture_error(client):
    token = _register_and_login(client, "comp_same@example.com")
    public_id = _create_twin(client, token)
    cap1 = _upload_capture(client, token, public_id)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap1["id"]},
        headers=_auth_headers(token),
    )
    assert res.status_code == 422  # Pydantic schema validator or 400


def test_create_comparison_invalid_chronology(client):
    token = _register_and_login(client, "comp_chrono@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id)
    time.sleep(0.01)
    cap2 = _upload_capture(client, token, public_id)

    # Reversing order: cap2 as earlier, cap1 as latest
    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap2["id"], "latest_capture_id": cap1["id"]},
        headers=_auth_headers(token),
    )
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "INVALID_CAPTURE_CHRONOLOGY"


def test_create_comparison_missing_capture(client):
    token = _register_and_login(client, "comp_missing@example.com")
    public_id = _create_twin(client, token)
    cap1 = _upload_capture(client, token, public_id)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": "non_existent_uuid"},
        headers=_auth_headers(token),
    )
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "CAPTURE_NOT_FOUND"


def test_comparison_cross_user_returns_404(client):
    token_a = _register_and_login(client, "comp_owner_a@example.com")
    token_b = _register_and_login(client, "comp_intruder_b@example.com")
    public_id_a = _create_twin(client, token_a)

    cap1 = _upload_capture(client, token_a, public_id_a)
    cap2 = _upload_capture(client, token_a, public_id_a)

    # Intruding user B tries to create comparison on User A's twin
    res_create = client.post(
        f"/api/v1/skintwins/{public_id_a}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token_b),
    )
    assert res_create.status_code == 404

    # Create legitimate comparison for User A
    comp_a = client.post(
        f"/api/v1/skintwins/{public_id_a}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token_a),
    ).json()

    # User B tries to view comparison
    res_get = client.get(f"/api/v1/comparisons/{comp_a['id']}", headers=_auth_headers(token_b))
    assert res_get.status_code == 404

    # User B tries to delete comparison
    res_del = client.delete(f"/api/v1/comparisons/{comp_a['id']}", headers=_auth_headers(token_b))
    assert res_del.status_code == 404


def test_comparison_lifecycle(client):
    token = _register_and_login(client, "comp_life@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id)
    time.sleep(0.01)
    cap2 = _upload_capture(client, token, public_id)

    # 1. Create comparison
    comp = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token),
    ).json()

    # 2. List comparisons for twin
    list_res = client.get(f"/api/v1/skintwins/{public_id}/comparisons", headers=_auth_headers(token))
    assert list_res.status_code == 200
    assert list_res.json()["total"] == 1

    # 3. Get comparison detail
    detail_res = client.get(f"/api/v1/comparisons/{comp['id']}", headers=_auth_headers(token))
    assert detail_res.status_code == 200
    assert detail_res.json()["id"] == comp["id"]

    # 4. Delete comparison
    del_res = client.delete(f"/api/v1/comparisons/{comp['id']}", headers=_auth_headers(token))
    assert del_res.status_code == 204

    # Confirm deleted
    get_after = client.get(f"/api/v1/comparisons/{comp['id']}", headers=_auth_headers(token))
    assert get_after.status_code == 404
