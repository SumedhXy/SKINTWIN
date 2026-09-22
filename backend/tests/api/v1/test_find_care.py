import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.v1.endpoints.auth import get_current_user

@pytest.fixture(autouse=True)
def override_auth():
    app.dependency_overrides[get_current_user] = lambda: {"sub": "user_1"}
    yield
    app.dependency_overrides.pop(get_current_user, None)

def test_get_providers_pagination(client: TestClient):
    # Test valid pagination limits
    response = client.get(
        "/api/v1/find-care/providers?page=1&limit=2"
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data["providers"]) == 2
    assert data["pagination"]["page"] == 1
    assert data["pagination"]["limit"] == 2
    assert data["pagination"]["total"] > 2
    
    # Check is_test_data is set
    assert data["providers"][0]["is_test_data"] is True
    assert data["providers"][0]["data_source"] == "mock_fixtures"

def test_get_providers_invalid_lat_lon(client: TestClient):
    # Latitude out of bounds
    response = client.get(
        "/api/v1/find-care/providers?latitude=100.0&longitude=50.0"
    )
    assert response.status_code == 422

    # Longitude out of bounds
    response = client.get(
        "/api/v1/find-care/providers?latitude=50.0&longitude=200.0"
    )
    assert response.status_code == 422

def test_get_providers_filter(client: TestClient):
    # Filter by specialty
    response = client.get(
        "/api/v1/find-care/providers?specialty=Surgeon"
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data["providers"]) == 1
    assert "Surgeon" in data["providers"][0]["specialty"]

def test_get_provider_details(client: TestClient):
    response = client.get(
        "/api/v1/find-care/providers/prov_1001"
    )
    assert response.status_code == 200
    assert response.json()["id"] == "prov_1001"

def test_get_specialties(client: TestClient):
    response = client.get(
        "/api/v1/find-care/specialties"
    )
    assert response.status_code == 200
    assert len(response.json()["specialties"]) > 0

def test_get_providers_search_and_recommendation_reason(client: TestClient):
    response = client.get("/api/v1/find-care/providers?search=Jenkins&specialty=Dermatologist")
    assert response.status_code == 200
    data = response.json()
    assert len(data["providers"]) == 1
    assert "matches your selected specialty" in data["providers"][0]["recommendation_reason"].lower()

def test_get_providers_consultation_mode_and_sort(client: TestClient):
    response = client.get("/api/v1/find-care/providers?consultation_mode=telehealth&sort=distance")
    assert response.status_code == 200
    providers = response.json()["providers"]
    assert providers
    assert all("telehealth" in item["consultation_types"] for item in providers)
    assert providers == sorted(providers, key=lambda item: item["distance_km"])

def test_get_providers_requires_coordinate_pair(client: TestClient):
    response = client.get("/api/v1/find-care/providers?latitude=37.7")
    assert response.status_code == 422

def test_get_providers_rejects_invalid_fee_range(client: TestClient):
    response = client.get("/api/v1/find-care/providers?min_fee=200&max_fee=100")
    assert response.status_code == 422

def test_unauthorized_access(client: TestClient):
    app.dependency_overrides.pop(get_current_user, None)
    response = client.get("/api/v1/find-care/providers")
    assert response.status_code == 401
