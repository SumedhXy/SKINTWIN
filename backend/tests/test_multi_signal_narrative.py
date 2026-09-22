import json
import pytest
from app.models.user import User
from app.models.skintwin import SkinTwin
from app.models.capture import Capture
from app.models.comparison import Comparison
from app.schemas.ai_explanation import ComparisonExplanationInput, AIExplanationResponse
from app.services.explanation.deterministic_provider import (
    DeterministicAIProvider,
    MEDICAL_DISCLAIMER,
    SAFETY_MESSAGE,
    RECOMMENDED_NEXT_STEP,
)
from app.services.explanation.llm_provider import LLMProvider


def _register_and_login(client, email: str, password: str = "ValidPass999!", full_name: str = "Test User"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": full_name})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="function")
def comparison_fixture(client, db_session):
    email = "narrativetest@example.com"
    token = _register_and_login(client, email)
    user = db_session.query(User).filter(User.email == email).first()

    res = client.post(
        "/api/v1/skintwins",
        json={"name": "Narrative Twin", "body_location": "back", "body_side": "right", "description": "Tracking spot"},
        headers=_auth_headers(token),
    )
    twin_public_id = res.json()["public_id"]
    twin = db_session.query(SkinTwin).filter(SkinTwin.public_id == twin_public_id).first()

    earlier = Capture(skintwin_id=twin.id, user_id=user.id, image_object_key="narrative_e.jpg")
    latest = Capture(skintwin_id=twin.id, user_id=user.id, image_object_key="narrative_l.jpg")
    db_session.add(earlier)
    db_session.add(latest)
    db_session.commit()
    db_session.refresh(earlier)
    db_session.refresh(latest)

    color_metrics = {
        "earlier_mean_bgr": [120.0, 130.0, 140.0],
        "latest_mean_bgr": [125.0, 135.0, 145.0],
        "overall_color_distance": 8.6,
        "lighting_brightness_delta": 4.2,
    }
    shape_metrics = {
        "hu_moments_match_score": 0.042,
        "earlier_perimeter_px": 140.5,
        "latest_perimeter_px": 148.2,
    }
    boundary_metrics = {
        "mask_iou_overlap": 0.88,
        "boundary_variance": "stable",
    }
    position_metrics = {
        "earlier_centroid": [150.0, 150.0],
        "latest_centroid": [152.0, 151.0],
        "displacement_px": 2.2,
    }

    comp = Comparison(
        skintwin_id=twin.id,
        user_id=user.id,
        earlier_capture_id=earlier.id,
        latest_capture_id=latest.id,
        alignment_status="aligned",
        alignment_score=0.92,
        localization_status="segmented",
        localization_confidence=0.95,
        segmentation_model="medsam_vit_b",
        segmentation_model_version="1.0.0",
        earlier_area=120.4,
        latest_area=135.8,
        area_change_percent=12.8,
        color_change_metrics=json.dumps(color_metrics),
        shape_change_metrics=json.dumps(shape_metrics),
        boundary_change_metrics=json.dumps(boundary_metrics),
        position_change_metrics=json.dumps(position_metrics),
        reliability_status="reliable",
        reliability_score=0.91,
        uncertainty_reasons=json.dumps([]),
    )
    db_session.add(comp)
    db_session.commit()
    db_session.refresh(comp)

    return {"token": token, "user": user, "twin": twin, "comparison": comp}


# =========================================================================
# 1. MULTI-SIGNAL DETERMINISTIC ENGINE TESTS
# =========================================================================

def test_deterministic_all_signals_available():
    provider = DeterministicAIProvider()
    input_data = ComparisonExplanationInput(
        comparison_id="comp-1",
        skintwin_id="twin-1",
        alignment_status="aligned",
        alignment_score=0.95,
        segmentation_status="segmented",
        localization_confidence=0.94,
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="real_medsam",
        fallback_used=False,
        earlier_area=100.0,
        latest_area=115.0,
        area_change_percent=15.0,
        color_change_metrics={"overall_color_distance": 5.0, "lighting_brightness_delta": 2.0},
        shape_change_metrics={"hu_moments_match_score": 0.02, "earlier_perimeter_px": 100.0, "latest_perimeter_px": 108.0},
        boundary_change_metrics={"mask_iou_overlap": 0.90},
        position_change_metrics={"displacement_px": 3.0},
        reliability_status="reliable",
        reliability_score=0.92,
        uncertainty_indicators=[],
    )

    response = provider.generate_explanation(input_data)

    assert response.safety_message == SAFETY_MESSAGE
    assert response.medical_disclaimer == MEDICAL_DISCLAIMER
    assert response.narrative_summary.status == "observable_difference"
    assert response.narrative_reliability.overall == "high"
    assert not response.narrative_uncertainty.present

    signals_by_name = {s.name: s for s in response.signals}
    assert "Area" in signals_by_name
    assert "Shape" in signals_by_name
    assert "Color" in signals_by_name
    assert "Position" in signals_by_name
    assert "Segmentation Overlap" in signals_by_name

    assert signals_by_name["Area"].direction == "increased"
    assert signals_by_name["Area"].change_value == 15.0
    assert signals_by_name["Shape"].direction == "stable"
    assert signals_by_name["Color"].direction == "stable"
    assert signals_by_name["Position"].direction == "stable"
    assert signals_by_name["Segmentation Overlap"].direction == "stable"


def test_deterministic_negative_area_change():
    provider = DeterministicAIProvider()
    input_data = ComparisonExplanationInput(
        comparison_id="comp-2",
        skintwin_id="twin-2",
        alignment_status="aligned",
        alignment_score=0.90,
        segmentation_status="segmented",
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="real_medsam",
        fallback_used=False,
        earlier_area=100.0,
        latest_area=85.0,
        area_change_percent=-15.0,
        color_change_metrics={"overall_color_distance": 4.0},
        shape_change_metrics={"hu_moments_match_score": 0.03},
        boundary_change_metrics={"mask_iou_overlap": 0.85},
        position_change_metrics={"displacement_px": 2.0},
        reliability_status="reliable",
    )

    response = provider.generate_explanation(input_data)
    area_signal = next(s for s in response.signals if s.name == "Area")
    assert area_signal.direction == "decreased"
    assert area_signal.change_value == -15.0
    assert "smaller" in area_signal.explanation


def test_deterministic_missing_area():
    provider = DeterministicAIProvider()
    input_data = ComparisonExplanationInput(
        comparison_id="comp-3",
        skintwin_id="twin-3",
        alignment_status="aligned",
        segmentation_status="failed",
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="real_medsam",
        fallback_used=False,
        earlier_area=None,
        latest_area=None,
        area_change_percent=None,
        reliability_status="unavailable",
    )

    response = provider.generate_explanation(input_data)
    area_signal = next(s for s in response.signals if s.name == "Area")
    assert area_signal.status == "unavailable"
    assert area_signal.reliability == "insufficient"
    assert response.narrative_reliability.overall == "insufficient"


def test_deterministic_lighting_shift_uncertainty():
    provider = DeterministicAIProvider()
    input_data = ComparisonExplanationInput(
        comparison_id="comp-4",
        skintwin_id="twin-4",
        alignment_status="aligned",
        alignment_score=0.88,
        segmentation_status="segmented",
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="real_medsam",
        fallback_used=False,
        earlier_area=100.0,
        latest_area=102.0,
        area_change_percent=2.0,
        color_change_metrics={"overall_color_distance": 22.0, "lighting_brightness_delta": 45.0},
        shape_change_metrics={"hu_moments_match_score": 0.02},
        boundary_change_metrics={"mask_iou_overlap": 0.86},
        position_change_metrics={"displacement_px": 2.0},
        reliability_status="needs_review",
        uncertainty_indicators=["Significant lighting shift between captures"],
    )

    response = provider.generate_explanation(input_data)
    color_signal = next(s for s in response.signals if s.name == "Color")
    assert color_signal.reliability == "low"
    assert "lighting" in color_signal.explanation.lower()
    assert response.narrative_uncertainty.present
    assert response.narrative_reliability.overall == "moderate"


def test_deterministic_low_iou_and_weak_alignment():
    provider = DeterministicAIProvider()
    input_data = ComparisonExplanationInput(
        comparison_id="comp-5",
        skintwin_id="twin-5",
        alignment_status="failed",
        alignment_score=0.25,
        segmentation_status="segmented",
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="fallback_cv",
        fallback_used=True,
        earlier_area=100.0,
        latest_area=130.0,
        area_change_percent=30.0,
        boundary_change_metrics={"mask_iou_overlap": 0.35},
        reliability_status="unreliable",
    )

    response = provider.generate_explanation(input_data)
    assert response.narrative_reliability.overall in ["low", "insufficient"]
    assert response.narrative_uncertainty.present
    overlap_signal = next(s for s in response.signals if s.name == "Segmentation Overlap")
    assert overlap_signal.reliability in ["low", "insufficient"]


# =========================================================================
# 2. LLM PROVIDER & SAFETY FILTER TESTS
# =========================================================================

def test_llm_fallback_without_api_key():
    provider = LLMProvider(api_key="")
    input_data = ComparisonExplanationInput(
        comparison_id="comp-6",
        skintwin_id="twin-6",
        alignment_status="aligned",
        segmentation_status="segmented",
        model_name="medsam_vit_b",
        model_version="1.0.0",
        inference_mode="real_medsam",
        fallback_used=False,
        earlier_area=100.0,
        latest_area=112.0,
        area_change_percent=12.0,
        reliability_status="reliable",
    )

    response = provider.generate_explanation(input_data)
    assert isinstance(response, AIExplanationResponse)
    assert response.safety_message == SAFETY_MESSAGE
    assert len(response.signals) == 5


# =========================================================================
# 3. ENDPOINT INTEGRATION TESTS
# =========================================================================

def test_get_comparison_explanation_endpoint(client, comparison_fixture):
    comp_id = comparison_fixture["comparison"].id
    headers = _auth_headers(comparison_fixture["token"])

    response = client.get(f"/api/v1/comparisons/{comp_id}/explanation", headers=headers)
    assert response.status_code == 200
    data = response.json()

    # Check multi-signal structure
    assert "narrative_summary" in data
    assert "signals" in data
    assert len(data["signals"]) == 5
    assert "narrative_reliability" in data
    assert "narrative_uncertainty" in data
    assert data["safety_message"] == SAFETY_MESSAGE
    assert "healthcare professional" in data["recommended_next_step"].lower()

    # Check Area Signal values
    area_signal = next(s for s in data["signals"] if s["name"] == "Area")
    assert area_signal["direction"] == "increased"
    assert area_signal["change_value"] == 12.8
    assert area_signal["change_unit"] == "percent"

    # Check legacy fields preservation
    assert "summary" in data
    assert "observations" in data
    assert "reliability" in data
    assert data["medical_disclaimer"] == MEDICAL_DISCLAIMER


def test_force_regenerate_narrative_endpoint(client, comparison_fixture):
    comp_id = comparison_fixture["comparison"].id
    headers = _auth_headers(comparison_fixture["token"])

    response = client.post(f"/api/v1/comparisons/{comp_id}/explanation", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["narrative_summary"]["status"] == "observable_difference"
    assert data["safety_message"] == SAFETY_MESSAGE
