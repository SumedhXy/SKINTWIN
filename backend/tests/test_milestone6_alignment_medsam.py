import cv2
import numpy as np
import pytest
from app.services.segmentation import MedSAMSegmentationModel, get_segmentation_model
from app.services.alignment_service import AlignmentService
from app.services.measurement_service import MeasurementService


# ── Synthetic Test Image Generators ───────────────────────────────────────────

def _make_pattern_image(width=400, height=400, shift_x=0, shift_y=0, bg_val=120):
    """Generate a synthetic patterned BGR image for alignment & segmentation testing."""
    img = np.full((height, width, 3), bg_val, dtype=np.uint8)

    # Draw grid features for ORB alignment
    for i in range(0, max(width, height), 25):
        cv2.line(img, (i, 0), (i, height), (200, 200, 200), 2)
        cv2.line(img, (0, i), (width, i), (50, 50, 50), 2)

    # Draw a simulated lesion / finding circle
    cx = int(width / 2 + shift_x)
    cy = int(height / 2 + shift_y)
    cv2.circle(img, (cx, cy), 35, (40, 40, 180), -1)
    return img


# ── Model & Segmentation Tests ─────────────────────────────────────────────────

def test_medsam_model_info():
    model = get_segmentation_model()
    info = model.get_model_info()
    assert info["model_name"] in ["medsam_vit_b", "fallback_cv"]
    assert "model_version" in info
    assert info["model_version"] == "1.0.0"
    assert "device" in info


def test_medsam_predict_with_prompt():
    model = MedSAMSegmentationModel()
    img = _make_pattern_image()

    prompt = {"bbox": [150, 150, 250, 250]}
    res = model.predict_region(img, prompt=prompt)

    assert res["status"] == "segmented"
    assert res["mask"] is not None
    assert res["mask_area_px"] > 0
    assert res["centroid"] is not None
    assert res["confidence"] > 0.5


def test_medsam_predict_invalid_prompt_out_of_bounds():
    model = MedSAMSegmentationModel()
    img = _make_pattern_image(width=300, height=300)

    # Bounding box out of image bounds
    bad_prompt = {"bbox": [0, 0, 500, 500]}
    res = model.predict_region(img, prompt=bad_prompt)

    assert res["status"] == "failed"
    assert res["error_code"] == "PROMPT_OUT_OF_BOUNDS"


def test_medsam_predict_invalid_image():
    model = MedSAMSegmentationModel()
    res = model.predict_region(None)
    assert res["status"] == "failed"
    assert res["error_code"] == "INVALID_IMAGE"


# ── OpenCV Image Alignment Tests ───────────────────────────────────────────────

def test_opencv_alignment_success():
    img1 = _make_pattern_image(shift_x=0, shift_y=0)
    img2 = _make_pattern_image(shift_x=5, shift_y=5)

    res = AlignmentService.align_image_pair(img1, img2)
    assert res["alignment_status"] in ["aligned", "partially_aligned"]
    assert res["alignment_score"] > 0.0
    assert res["match_count"] >= 4
    assert res["inlier_count"] >= 4
    assert res["aligned_latest_image"] is not None
    assert res["aligned_latest_image"].shape == img1.shape


def test_opencv_alignment_insufficient_keypoints():
    # Solid black images have no texture/keypoints for ORB
    blank1 = np.zeros((200, 200, 3), dtype=np.uint8)
    blank2 = np.zeros((200, 200, 3), dtype=np.uint8)

    res = AlignmentService.align_image_pair(blank1, blank2)
    assert res["alignment_status"] == "failed"
    assert res["alignment_error_code"] == "INSUFFICIENT_KEYPOINTS"


# ── Observable Measurement & Reliability Tests ─────────────────────────────────

def test_measurement_calculation_and_reliability():
    img1 = _make_pattern_image()
    img2 = _make_pattern_image(shift_x=2, shift_y=2)

    model = MedSAMSegmentationModel()
    prompt1 = {"bbox": [160, 160, 240, 240]}
    prompt2 = {"bbox": [160, 160, 240, 240]}

    seg1 = model.predict_region(img1, prompt1)
    seg2 = model.predict_region(img2, prompt2)

    align_res = AlignmentService.align_image_pair(img1, img2)

    metrics = MeasurementService.calculate_metrics(
        earlier_img=img1,
        latest_img=img2,
        earlier_seg=seg1,
        latest_seg=seg2,
        alignment_res=align_res,
    )

    assert metrics["measurement_status"] == "measured"
    assert metrics["earlier_area"] > 0
    assert metrics["latest_area"] > 0
    assert metrics["area_change_percent"] is not None
    assert metrics["reliability_status"] in ["reliable", "needs_review"]
    assert metrics["color_change_metrics"] is not None
    assert metrics["shape_change_metrics"] is not None
    assert metrics["boundary_change_metrics"] is not None
    assert metrics["position_change_metrics"] is not None


# ── API End-to-End Integration Tests ──────────────────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Mole Track"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "shoulder", "body_side": "right"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]


def _upload_capture_bytes(client, token: str, public_id: str, file_bytes: bytes, filename: str):
    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": (filename, file_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    return res.json()


def test_api_comparison_pipeline_end_to_end(client):
    token = _register_and_login(client, "ms6_pipeline@example.com")
    public_id = _create_twin(client, token)

    img1_bytes = cv2.imencode(".jpg", _make_pattern_image(shift_x=0))[1].tobytes()
    img2_bytes = cv2.imencode(".jpg", _make_pattern_image(shift_x=3))[1].tobytes()

    cap1 = _upload_capture_bytes(client, token, public_id, img1_bytes, "img1.jpg")
    cap2 = _upload_capture_bytes(client, token, public_id, img2_bytes, "img2.jpg")

    payload = {
        "earlier_capture_id": cap1["id"],
        "latest_capture_id": cap2["id"],
        "earlier_prompt": {"bbox": [160, 160, 240, 240]},
        "latest_prompt": {"bbox": [160, 160, 240, 240]},
    }

    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json=payload,
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()

    assert data["skintwin_public_id"] == public_id
    assert data["processing_status"] == "completed"
    assert data["alignment_status"] in ["aligned", "partially_aligned", "failed"]
    assert data["localization_status"] in ["segmented", "unavailable"]
    assert data["segmentation_model"] in ["medsam_vit_b", "fallback_cv"]
    assert data["measurement_status"] in ["measured", "unavailable"]
    assert data["reliability_status"] in ["reliable", "needs_review", "unreliable", "unavailable"]
    assert data["comparison_version"] == "1.0.0"
    assert data["analyzed_at"] is not None

    # Retrieve comparison via GET
    get_res = client.get(f"/api/v1/comparisons/{data['id']}", headers=_auth_headers(token))
    assert get_res.status_code == 200
    assert get_res.json()["id"] == data["id"]
