import pytest
from app.models.user import User
from app.models.skintwin import SkinTwin
from app.models.capture import Capture
from app.models.comparison import Comparison
from app.services.explanation.deterministic_provider import MEDICAL_DISCLAIMER

def _register_and_login(client, email: str, password: str = "ValidPass999!", full_name: str = "Test User"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": full_name})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]

def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture(scope="function")
def setup_comparison(client, db_session):
    # 1. Register user
    email = "testai@example.com"
    token = _register_and_login(client, email)
    user = db_session.query(User).filter(User.email == email).first()

    # 2. Create SkinTwin via API
    res = client.post(
        "/api/v1/skintwins",
        json={"name": "Test Twin", "body_location": "arm", "body_side": "left", "description": "Desc"},
        headers=_auth_headers(token),
    )
    twin_public_id = res.json()["public_id"]
    twin = db_session.query(SkinTwin).filter(SkinTwin.public_id == twin_public_id).first()

    # 3. Create two captures manually
    earlier = Capture(
        skintwin_id=twin.id,
        user_id=user.id,
        image_object_key="test_earlier.jpg",
    )
    latest = Capture(
        skintwin_id=twin.id,
        user_id=user.id,
        image_object_key="test_latest.jpg",
    )
    db_session.add(earlier)
    db_session.add(latest)
    db_session.commit()
    db_session.refresh(earlier)
    db_session.refresh(latest)

    # 4. Create comparison manually
    comp = Comparison(
        skintwin_id=twin.id,
        user_id=user.id,
        earlier_capture_id=earlier.id,
        latest_capture_id=latest.id,
        alignment_status="aligned",
        alignment_score=0.95,
        localization_status="segmented",
        segmentation_model="medsam_vit_b",
        area_change_percent=12.5,
        earlier_area=100.0,
        latest_area=112.5,
        reliability_status="reliable",
    )
    db_session.add(comp)
    db_session.commit()
    db_session.refresh(comp)

    return {"token": token, "comparison_id": comp.id, "user_id": user.id}

def test_get_comparison_explanation_success(client, setup_comparison):
    comp_id = setup_comparison["comparison_id"]
    headers = _auth_headers(setup_comparison["token"])

    response = client.get(f"/api/v1/comparisons/{comp_id}/explanation", headers=headers)
    assert response.status_code == 200
    data = response.json()
    
    assert data["medical_disclaimer"] == MEDICAL_DISCLAIMER
    assert data["reliability"]["status"] == "reliable"
    assert data["model_metadata"]["model_name"] == "medsam_vit_b"
    assert data["model_metadata"]["inference_mode"] == "real_medsam"
    
    area_obs = next((obs for obs in data["observations"] if obs["metric"] == "area"), None)
    assert area_obs is not None
    assert area_obs["status"] == "changed"
    assert "12.5" in area_obs["value"]

def test_force_generate_explanation(client, setup_comparison):
    comp_id = setup_comparison["comparison_id"]
    headers = _auth_headers(setup_comparison["token"])

    # First generate normally
    res1 = client.get(f"/api/v1/comparisons/{comp_id}/explanation", headers=headers)
    assert res1.status_code == 200
    
    # Force regenerate
    res2 = client.post(f"/api/v1/comparisons/{comp_id}/explanation", headers=headers)
    assert res2.status_code == 200
    assert res2.json()["medical_disclaimer"] == MEDICAL_DISCLAIMER

def test_unauthorized_explanation_access(client, setup_comparison):
    comp_id = setup_comparison["comparison_id"]
    response = client.get(f"/api/v1/comparisons/{comp_id}/explanation")
    assert response.status_code == 401

def test_get_explanation_not_found(client, setup_comparison):
    headers = _auth_headers(setup_comparison["token"])
    response = client.get("/api/v1/comparisons/invalid-id-123/explanation", headers=headers)
    assert response.status_code == 404
