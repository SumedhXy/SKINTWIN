import json
import time
import pytest
import numpy as np
import cv2
from datetime import datetime, timezone

from app.models.user import User
from app.models.skintwin import SkinTwin
from app.models.capture import Capture
from app.models.comparison import Comparison
from app.services.reliability_evaluator import (
    ReliabilityEvaluator,
    UncertaintyReason,
    ComponentStatus,
    SignalReliability,
    NON_DIAGNOSTIC_DISCLAIMER,
)
from app.services.measurement_service import MeasurementService
from app.schemas.comparison import ComparisonResponse, ComparisonCreateRequest


def _make_image(width=400, height=400, color=(120, 120, 120)):
    img = np.full((height, width, 3), color, dtype=np.uint8)
    for i in range(0, min(width, height), 20):
        cv2.line(img, (i, 0), (i, height), (255, 255, 255), 2)
    return img

def _encode_jpeg(img):
    _, buf = cv2.imencode(".jpg", img)
    return buf.tobytes()

SAMPLE_JPEG = _encode_jpeg(_make_image())


# -----------------------------------------------------------------------------
# 1. PURE RELIABILITY EVALUATOR UNIT TESTS
# -----------------------------------------------------------------------------

def test_reliability_evaluator_high_quality_pair():
    """Test 1: High quality captures with good alignment and segmentation yield High reliability."""
    earlier_q = {"quality_status": "acceptable", "quality_score": 0.95, "blur_status": "pass", "lighting_status": "pass"}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.92, "blur_status": "pass", "lighting_status": "pass"}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.88, "inlier_ratio": 0.85, "match_count": 120}
    
    mask = np.ones((100, 100), dtype=np.uint8)
    earlier_seg = {"status": "segmented", "confidence": 0.92, "mask": mask, "centroid": (50.0, 50.0), "perimeter": 400.0}
    latest_seg = {"status": "segmented", "confidence": 0.90, "mask": mask, "centroid": (51.0, 50.5), "perimeter": 405.0}

    measurements = {
        "earlier_area": 10000.0,
        "latest_area": 10200.0,
        "area_change_percent": 2.0,
        "color_metrics": {"lighting_brightness_delta": 4.0, "overall_color_distance": 5.0},
        "shape_metrics": {"hu_moments_match_score": 0.02},
        "boundary_metrics": {"mask_iou_overlap": 0.92},
        "position_metrics": {"displacement_px": 1.2},
    }

    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        measurements=measurements,
        segmentation_model_info={"model_name": "medsam_vit_b", "fallback_used": False},
    )

    assert result.overall_reliability == "high"
    assert result.reliability_score >= 0.80
    assert result.component_statuses["image_quality"].status == "acceptable"
    assert result.component_statuses["alignment"].status == "high"
    assert result.component_statuses["segmentation"].status == "high"
    assert result.component_statuses["segmentation"].is_fallback is False
    assert result.component_statuses["measurement"].status == "high"
    assert result.signal_reliabilities["area"].reliability == "high"
    assert result.signal_reliabilities["color"].reliability == "high"
    assert not result.uncertainty_reasons


def test_reliability_evaluator_poor_image_quality():
    """Test 2: Poor image quality lowers overall reliability to low."""
    earlier_q = {"quality_status": "unacceptable", "quality_score": 0.2, "blur_status": "fail", "lighting_status": "fail"}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.9, "blur_status": "pass", "lighting_status": "pass"}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.85, "inlier_ratio": 0.80}
    
    mask = np.ones((50, 50), dtype=np.uint8)
    earlier_seg = {"status": "segmented", "confidence": 0.85, "mask": mask}
    latest_seg = {"status": "segmented", "confidence": 0.85, "mask": mask}
    measurements = {
        "earlier_area": 2500.0,
        "latest_area": 2550.0,
        "area_change_percent": 2.0,
        "color_metrics": {"lighting_brightness_delta": 40.0, "overall_color_distance": 25.0},
        "shape_metrics": {"hu_moments_match_score": 0.05},
        "boundary_metrics": {"mask_iou_overlap": 0.85},
        "position_metrics": {"displacement_px": 2.0},
    }

    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        measurements=measurements,
    )

    assert result.overall_reliability in ["low", "moderate"]
    assert result.uncertainty_present is True
    assert result.component_statuses["image_quality"].status == "poor"
    assert any(u.category == "blur" for u in result.uncertainty_reasons)


def test_reliability_evaluator_lighting_shift_and_color_uncertainty():
    """Test 3: Major lighting delta (>35) specifically reduces Color reliability while preserving other signals."""
    earlier_q = {"quality_status": "acceptable", "quality_score": 0.9, "blur_status": "pass", "lighting_status": "pass"}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.9, "blur_status": "pass", "lighting_status": "pass"}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.9, "inlier_ratio": 0.85}
    
    mask = np.ones((50, 50), dtype=np.uint8)
    earlier_seg = {"status": "segmented", "confidence": 0.9, "mask": mask}
    latest_seg = {"status": "segmented", "confidence": 0.9, "mask": mask}
    
    # 48.0 brightness difference
    measurements = {
        "earlier_area": 2500.0,
        "latest_area": 2500.0,
        "area_change_percent": 0.0,
        "color_metrics": {"lighting_brightness_delta": 48.0, "overall_color_distance": 32.0},
        "shape_metrics": {"hu_moments_match_score": 0.01},
        "boundary_metrics": {"mask_iou_overlap": 0.90},
        "position_metrics": {"displacement_px": 0.5},
    }

    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        measurements=measurements,
    )

    assert result.signal_reliabilities["color"].reliability == "low"
    assert result.signal_reliabilities["color"].uncertainty is True
    assert "lighting" in result.signal_reliabilities["color"].limitation.lower()
    # Area remains moderate/high
    assert result.signal_reliabilities["area"].reliability in ["high", "moderate"]
    assert "color" in result.affected_signals
    assert any(u.category == "lighting" for u in result.uncertainty_reasons)


def test_reliability_evaluator_blur_uncertainty():
    """Test 4: Blurry images flag blur uncertainty and affect shape, area, and overlap."""
    earlier_q = {"quality_status": "needs_review", "quality_score": 0.6, "blur_status": "fail"}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.9, "blur_status": "pass"}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.8, "inlier_ratio": 0.7}
    mask = np.ones((50, 50), dtype=np.uint8)
    
    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg={"status": "segmented", "confidence": 0.8, "mask": mask},
        latest_seg={"status": "segmented", "confidence": 0.8, "mask": mask},
        measurements={
            "earlier_area": 2500.0,
            "latest_area": 2500.0,
            "area_change_percent": 0.0,
            "color_metrics": {"lighting_brightness_delta": 5.0, "overall_color_distance": 4.0},
            "shape_metrics": {"hu_moments_match_score": 0.02},
            "boundary_metrics": {"mask_iou_overlap": 0.85},
            "position_metrics": {"displacement_px": 1.0},
        },
    )

    assert any(u.category == "blur" and u.severity == "high" for u in result.uncertainty_reasons)
    assert "shape" in result.affected_signals
    assert "area" in result.affected_signals


def test_reliability_evaluator_alignment_failure():
    """Test 5: Alignment failure flags position & shape as uncertain and causes overall insufficient/low."""
    align_res = {"alignment_status": "failed", "alignment_score": 0.1, "inlier_ratio": 0.05, "alignment_error_code": "HOMOGRAPHY_FAILED"}
    mask = np.ones((50, 50), dtype=np.uint8)
    
    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res=align_res,
        earlier_seg={"status": "segmented", "confidence": 0.85, "mask": mask},
        latest_seg={"status": "segmented", "confidence": 0.85, "mask": mask},
        measurements={
            "earlier_area": 2500.0,
            "latest_area": 2500.0,
            "area_change_percent": 0.0,
            "color_metrics": {"lighting_brightness_delta": 2.0, "overall_color_distance": 3.0},
            "shape_metrics": {"hu_moments_match_score": 0.02},
            "boundary_metrics": {"mask_iou_overlap": 0.3},
            "position_metrics": {"displacement_px": 25.0},
        },
    )

    assert result.component_statuses["alignment"].status in ["low", "unavailable"]
    assert result.signal_reliabilities["position"].reliability in ["low", "unavailable"]
    assert any(u.category == "alignment" for u in result.uncertainty_reasons)


def test_reliability_evaluator_low_alignment_partial():
    """Test 6: Partial alignment results in moderate alignment status and uncertainty."""
    align_res = {"alignment_status": "partially_aligned", "alignment_score": 0.38, "inlier_ratio": 0.35}
    mask = np.ones((50, 50), dtype=np.uint8)
    
    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res=align_res,
        earlier_seg={"status": "segmented", "confidence": 0.9, "mask": mask},
        latest_seg={"status": "segmented", "confidence": 0.9, "mask": mask},
        measurements={
            "earlier_area": 2500.0,
            "latest_area": 2500.0,
            "area_change_percent": 0.0,
            "color_metrics": {"lighting_brightness_delta": 2.0, "overall_color_distance": 3.0},
            "shape_metrics": {"hu_moments_match_score": 0.02},
            "boundary_metrics": {"mask_iou_overlap": 0.75},
            "position_metrics": {"displacement_px": 5.0},
        },
    )

    assert result.component_statuses["alignment"].status == "moderate"
    assert result.overall_reliability == "moderate"


def test_reliability_evaluator_segmentation_failure():
    """Test 7: Complete segmentation failure triggers overall insufficient."""
    align_res = {"alignment_status": "aligned", "alignment_score": 0.9, "inlier_ratio": 0.8}
    earlier_seg = {"status": "failed", "confidence": 0.0, "mask": None, "error_code": "NO_LESION_FOUND"}
    latest_seg = {"status": "segmented", "confidence": 0.85, "mask": np.ones((50, 50), dtype=np.uint8)}
    
    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res=align_res,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        measurements={"earlier_area": None, "latest_area": 2500.0},
    )

    assert result.overall_reliability == "insufficient"
    assert result.component_statuses["segmentation"].status == "unavailable"
    assert result.signal_reliabilities["area"].reliability == "unavailable"


def test_reliability_evaluator_fallback_segmentation():
    """Test 8: Fallback segmentation explicitly flags is_fallback, discloses limitations, and caps reliability at moderate."""
    align_res = {"alignment_status": "aligned", "alignment_score": 0.85, "inlier_ratio": 0.8}
    mask = np.ones((50, 50), dtype=np.uint8)
    earlier_seg = {"status": "segmented", "confidence": 0.75, "mask": mask}
    latest_seg = {"status": "segmented", "confidence": 0.75, "mask": mask}
    
    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res=align_res,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        measurements={
            "earlier_area": 2500.0,
            "latest_area": 2600.0,
            "area_change_percent": 4.0,
            "color_metrics": {"lighting_brightness_delta": 5.0, "overall_color_distance": 6.0},
            "shape_metrics": {"hu_moments_match_score": 0.03},
            "boundary_metrics": {"mask_iou_overlap": 0.80},
            "position_metrics": {"displacement_px": 2.0},
        },
        segmentation_model_info={"model_name": "fallback_cv", "fallback_used": True},
    )

    assert result.component_statuses["segmentation"].is_fallback is True
    assert result.component_statuses["segmentation"].status == "moderate"
    assert "fallback" in result.component_statuses["segmentation"].explanation.lower()
    assert result.overall_reliability in ["moderate", "low"]
    assert any("fallback" in u.message.lower() for u in result.uncertainty_reasons)


def test_reliability_evaluator_missing_measurements():
    """Test 9: Missing measurement data gracefully degrades without exceptions."""
    result = ReliabilityEvaluator.evaluate(
        earlier_quality=None,
        latest_quality=None,
        alignment_res={"alignment_status": "unavailable"},
        earlier_seg={"status": "unavailable", "mask": None},
        latest_seg={"status": "unavailable", "mask": None},
        measurements={},
    )

    assert result.overall_reliability == "insufficient"
    assert result.reliability_score == 0.0
    assert result.component_statuses["image_quality"].status == "unavailable"
    assert result.component_statuses["measurement"].status == "unavailable"


def test_reliability_evaluator_low_iou():
    """Test 10: Very low IoU overlap (<0.20) triggers measurement uncertainty."""
    mask_e = np.zeros((100, 100), dtype=np.uint8)
    mask_e[10:30, 10:30] = 1
    mask_l = np.zeros((100, 100), dtype=np.uint8)
    mask_l[70:90, 70:90] = 1  # non-overlapping

    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res={"alignment_status": "aligned", "alignment_score": 0.7},
        earlier_seg={"status": "segmented", "confidence": 0.8, "mask": mask_e},
        latest_seg={"status": "segmented", "confidence": 0.8, "mask": mask_l},
        measurements={
            "earlier_area": 400.0,
            "latest_area": 400.0,
            "area_change_percent": 0.0,
            "color_metrics": {"lighting_brightness_delta": 3.0, "overall_color_distance": 4.0},
            "shape_metrics": {"hu_moments_match_score": 0.01},
            "boundary_metrics": {"mask_iou_overlap": 0.0},
            "position_metrics": {"displacement_px": 60.0},
        },
    )

    assert result.component_statuses["measurement"].status == "low"
    assert result.overall_reliability == "low"
    assert any(u.category == "measurement" for u in result.uncertainty_reasons)


def test_reliability_evaluator_no_medical_claims_in_disclaimer():
    """Test 11: Asserts non-diagnostic disclaimer is present and contains no medical accuracy claims."""
    result = ReliabilityEvaluator.evaluate(
        earlier_quality={"quality_status": "acceptable"},
        latest_quality={"quality_status": "acceptable"},
        alignment_res={"alignment_status": "aligned", "alignment_score": 0.9},
        earlier_seg={"status": "segmented", "confidence": 0.9, "mask": np.ones((10, 10), dtype=np.uint8)},
        latest_seg={"status": "segmented", "confidence": 0.9, "mask": np.ones((10, 10), dtype=np.uint8)},
        measurements={
            "earlier_area": 100.0,
            "latest_area": 100.0,
            "area_change_percent": 0.0,
            "color_metrics": {"lighting_brightness_delta": 2.0},
            "shape_metrics": {},
            "boundary_metrics": {"mask_iou_overlap": 0.9},
            "position_metrics": {"displacement_px": 0.0},
        },
    )

    assert result.disclaimer == NON_DIAGNOSTIC_DISCLAIMER
    assert "safe" not in result.disclaimer.lower()
    assert "cancer" not in result.disclaimer.lower()
    assert "diagnose" in result.disclaimer.lower()


# -----------------------------------------------------------------------------
# 2. ENDPOINT & BACKEND INTEGRATION TESTS
# -----------------------------------------------------------------------------

def _register_and_login(client, email: str, password: str = "ValidPass999!"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": "Test User"})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]

def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}

def _create_twin(client, token: str, name="Reliability Twin"):
    res = client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": "arm", "body_side": "left"},
        headers=_auth_headers(token),
    )
    return res.json()["public_id"]

def _upload_capture(client, token: str, public_id: str, file_bytes=SAMPLE_JPEG, filename="test.jpg"):
    res = client.post(
        f"/api/v1/skintwins/{public_id}/captures",
        files={"file": (filename, file_bytes, "image/jpeg")},
        headers=_auth_headers(token),
    )
    return res.json()


def test_comparison_endpoint_returns_structured_reliability(client):
    """Test 12: Comparison creation endpoint returns structured reliability and uncertainty details."""
    token = _register_and_login(client, "rel_struct@example.com")
    public_id = _create_twin(client, token)

    cap1 = _upload_capture(client, token, public_id)
    time.sleep(0.01)
    cap2 = _upload_capture(client, token, public_id)

    res = client.post(
        f"/api/v1/skintwins/{public_id}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token),
    )
    assert res.status_code == 201
    data = res.json()

    # Verify root fields
    assert "overall_reliability" in data
    assert data["overall_reliability"] in ["high", "moderate", "low", "insufficient"]
    assert "reliability_status" in data
    assert "uncertainty_reasons" in data
    assert "non_diagnostic_disclaimer" in data
    assert "reliability_details" in data

    if data["reliability_details"]:
        rel = data["reliability_details"]
        assert "overall_reliability" in rel
        assert "component_statuses" in rel
        assert "signal_reliabilities" in rel
        assert "uncertainty_present" in rel
        assert "uncertainty_reasons" in rel
        assert "affected_signals" in rel
        assert "limitations" in rel


def test_comparison_endpoint_ownership_enforced(client):
    """Test 13: Users cannot view or create comparisons for another user's SkinTwin."""
    token_a = _register_and_login(client, "user_a_rel@example.com")
    token_b = _register_and_login(client, "user_b_rel@example.com")
    twin_a = _create_twin(client, token_a)

    cap1 = _upload_capture(client, token_a, twin_a)
    cap2 = _upload_capture(client, token_a, twin_a)

    # Intruder B cannot create comparison on Twin A
    res_b = client.post(
        f"/api/v1/skintwins/{twin_a}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token_b),
    )
    assert res_b.status_code == 404

    # Legitimate user A creates comparison
    res_a = client.post(
        f"/api/v1/skintwins/{twin_a}/comparisons",
        json={"earlier_capture_id": cap1["id"], "latest_capture_id": cap2["id"]},
        headers=_auth_headers(token_a),
    )
    assert res_a.status_code == 201
    comp_id = res_a.json()["id"]

    # Intruder B cannot fetch comparison details
    res_get_b = client.get(f"/api/v1/comparisons/{comp_id}", headers=_auth_headers(token_b))
    assert res_get_b.status_code == 404


def test_reliability_evaluator_conflicting_signals():
    """Test 14: Conflicting signals (e.g. area growth reported while shape IoU is extremely low or displaced) flags uncertainty."""
    earlier_q = {"quality_status": "acceptable", "quality_score": 0.88}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.88}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.85, "inlier_ratio": 0.8}
    mask = np.ones((50, 50), dtype=np.uint8)

    # Conflicting: large area change (+60%) but high Hu moments similarity and low IoU
    measurements = {
        "earlier_area": 2500.0,
        "latest_area": 4000.0,
        "area_change_percent": 60.0,
        "color_metrics": {"lighting_brightness_delta": 30.0, "overall_color_distance": 22.0},
        "shape_metrics": {"hu_moments_match_score": 0.25},
        "boundary_metrics": {"mask_iou_overlap": 0.35},
        "position_metrics": {"displacement_px": 15.0},
    }

    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg={"status": "segmented", "confidence": 0.85, "mask": mask},
        latest_seg={"status": "segmented", "confidence": 0.85, "mask": mask},
        measurements=measurements,
    )

    assert result.uncertainty_present is True
    assert result.overall_reliability in ["moderate", "low"]
    assert len(result.affected_signals) >= 1
    assert any(u.category in ["lighting", "measurement", "alignment"] for u in result.uncertainty_reasons)


def test_reliability_evaluator_affected_signals_reporting():
    """Test 15: Correctly maps specific uncertainty categories to their exact affected signals."""
    earlier_q = {"quality_status": "acceptable", "lighting_status": "fail", "blur_status": "pass"}
    latest_q = {"quality_status": "acceptable", "lighting_status": "pass", "blur_status": "pass"}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.9}
    mask = np.ones((50, 50), dtype=np.uint8)

    measurements = {
        "earlier_area": 2500.0,
        "latest_area": 2500.0,
        "area_change_percent": 0.0,
        "color_metrics": {"lighting_brightness_delta": 45.0, "overall_color_distance": 30.0},
        "shape_metrics": {"hu_moments_match_score": 0.01},
        "boundary_metrics": {"mask_iou_overlap": 0.90},
        "position_metrics": {"displacement_px": 0.5},
    }

    result = ReliabilityEvaluator.evaluate(
        earlier_quality=earlier_q,
        latest_quality=latest_q,
        alignment_res=align_res,
        earlier_seg={"status": "segmented", "confidence": 0.9, "mask": mask},
        latest_seg={"status": "segmented", "confidence": 0.9, "mask": mask},
        measurements=measurements,
    )

    # Lighting delta affects color signal
    assert "color" in result.affected_signals
    assert result.signal_reliabilities["color"].uncertainty is True


def test_reliability_evaluator_deterministic_scores_no_fabrication():
    """Test 16: Verification of strictly deterministic, bounded engineering scores (no random scores, no medical precision)."""
    earlier_q = {"quality_status": "acceptable", "quality_score": 0.90}
    latest_q = {"quality_status": "acceptable", "quality_score": 0.90}
    align_res = {"alignment_status": "aligned", "alignment_score": 0.85, "inlier_ratio": 0.80}
    mask = np.ones((40, 40), dtype=np.uint8)
    measurements = {
        "earlier_area": 1600.0,
        "latest_area": 1600.0,
        "area_change_percent": 0.0,
        "color_metrics": {"lighting_brightness_delta": 2.0, "overall_color_distance": 2.0},
        "shape_metrics": {"hu_moments_match_score": 0.01},
        "boundary_metrics": {"mask_iou_overlap": 0.95},
        "position_metrics": {"displacement_px": 0.2},
    }

    # Run evaluation multiple times to ensure identical output (deterministic, no random variance)
    res1 = ReliabilityEvaluator.evaluate(earlier_q, latest_q, align_res, {"status": "segmented", "mask": mask}, {"status": "segmented", "mask": mask}, measurements)
    res2 = ReliabilityEvaluator.evaluate(earlier_q, latest_q, align_res, {"status": "segmented", "mask": mask}, {"status": "segmented", "mask": mask}, measurements)

    assert res1.reliability_score == res2.reliability_score
    assert res1.overall_reliability == res2.overall_reliability
    assert 0.0 <= res1.reliability_score <= 1.0
    # Make sure score is purely engineering
    assert isinstance(res1.reliability_score, float)


def test_comparison_response_backward_compatibility():
    """Test 17: ComparisonResponse schema maintains backward compatibility with legacy string lists and older formats."""
    legacy_payload = {
        "id": "comp-123",
        "skintwin_public_id": "st-456",
        "earlier_capture_id": "cap-1",
        "latest_capture_id": "cap-2",
        "processing_status": "completed",
        "alignment_status": "aligned",
        "localization_status": "segmented",
        "segmentation_model": "fallback_cv",
        "reliability_status": "needs_review",
        "uncertainty_reasons": ["Lighting conditions differed between captures", "Fallback algorithmic segmentation used"],
        "created_at": datetime.now(timezone.utc),
    }

    resp = ComparisonResponse(**legacy_payload)
    assert resp.overall_reliability == "moderate"  # derived from needs_review
    assert resp.inference_mode == "fallback_cv"
    assert resp.fallback_used is True
    assert len(resp.uncertainty_reasons) == 2
    assert resp.non_diagnostic_disclaimer is not None

