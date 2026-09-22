"""Tests for SkinTwin CRUD endpoints."""


# ── Helpers ────────────────────────────────────────────────────────────────────

def _register_and_login(client, email: str, password: str = "ValidPass999!", full_name: str = "Test User"):
    client.post("/api/v1/auth/register", json={"email": email, "password": password, "full_name": full_name})
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_twin(client, token: str, name="Shoulder Mole", location="shoulder", side="left"):
    return client.post(
        "/api/v1/skintwins",
        json={"name": name, "body_location": location, "body_side": side, "description": "Test twin"},
        headers=_auth_headers(token),
    )


# ── Create ─────────────────────────────────────────────────────────────────────

def test_create_skintwin_success(client):
    token = _register_and_login(client, "create@example.com")
    res = _create_twin(client, token)
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Shoulder Mole"
    assert data["body_location"] == "shoulder"
    assert data["body_side"] == "left"
    assert data["status"] == "active"
    assert data["capture_count"] == 0
    assert data["public_id"].startswith("st-")
    # Confirm internal DB id is NOT exposed
    assert "id" not in data
    assert "user_id" not in data


def test_create_skintwin_missing_required_fields(client):
    token = _register_and_login(client, "missingfields@example.com")
    res = client.post(
        "/api/v1/skintwins",
        json={"body_location": "back"},  # name is missing
        headers=_auth_headers(token),
    )
    assert res.status_code == 422
    assert res.json()["error"]["code"] == "VALIDATION_ERROR"


def test_create_skintwin_unauthorized(client):
    res = client.post("/api/v1/skintwins", json={"name": "Test", "body_location": "arm"})
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "TOKEN_MISSING"


# ── List ───────────────────────────────────────────────────────────────────────

def test_list_skintwins_empty(client):
    token = _register_and_login(client, "listempty@example.com")
    res = client.get("/api/v1/skintwins", headers=_auth_headers(token))
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 0
    assert data["items"] == []


def test_list_skintwins_returns_own_only(client):
    token_a = _register_and_login(client, "user_a@example.com")
    token_b = _register_and_login(client, "user_b@example.com")

    _create_twin(client, token_a, name="User A Twin 1")
    _create_twin(client, token_a, name="User A Twin 2")
    _create_twin(client, token_b, name="User B Twin 1")

    res_a = client.get("/api/v1/skintwins", headers=_auth_headers(token_a))
    res_b = client.get("/api/v1/skintwins", headers=_auth_headers(token_b))

    assert res_a.json()["total"] == 2
    assert res_b.json()["total"] == 1
    names_a = [t["name"] for t in res_a.json()["items"]]
    assert "User B Twin 1" not in names_a


def test_list_skintwins_unauthorized(client):
    res = client.get("/api/v1/skintwins")
    assert res.status_code == 401


# ── Retrieve ───────────────────────────────────────────────────────────────────

def test_get_skintwin_success(client):
    token = _register_and_login(client, "get@example.com")
    create_res = _create_twin(client, token)
    public_id = create_res.json()["public_id"]

    res = client.get(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token))
    assert res.status_code == 200
    assert res.json()["public_id"] == public_id
    assert res.json()["name"] == "Shoulder Mole"


def test_get_skintwin_invalid_id(client):
    token = _register_and_login(client, "invalidid@example.com")
    res = client.get("/api/v1/skintwins/st-doesnotexist", headers=_auth_headers(token))
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


def test_get_skintwin_cross_user_returns_404(client):
    """Other user's SkinTwin must return 404, NOT 403 — prevents record enumeration."""
    token_a = _register_and_login(client, "owner@example.com")
    token_b = _register_and_login(client, "intruder@example.com")

    public_id = _create_twin(client, token_a).json()["public_id"]
    res = client.get(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token_b))
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


# ── Update ─────────────────────────────────────────────────────────────────────

def test_update_skintwin_success(client):
    token = _register_and_login(client, "update@example.com")
    public_id = _create_twin(client, token).json()["public_id"]

    res = client.patch(
        f"/api/v1/skintwins/{public_id}",
        json={"name": "Updated Name", "status": "needs_review"},
        headers=_auth_headers(token),
    )
    assert res.status_code == 200
    data = res.json()
    assert data["name"] == "Updated Name"
    assert data["status"] == "needs_review"
    # Unchanged fields preserved
    assert data["body_location"] == "shoulder"


def test_update_skintwin_invalid_status(client):
    token = _register_and_login(client, "badstatus@example.com")
    public_id = _create_twin(client, token).json()["public_id"]

    res = client.patch(
        f"/api/v1/skintwins/{public_id}",
        json={"status": "unknown_status_xyz"},
        headers=_auth_headers(token),
    )
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "INVALID_STATUS"


def test_update_skintwin_cross_user_returns_404(client):
    token_a = _register_and_login(client, "owner2@example.com")
    token_b = _register_and_login(client, "intruder2@example.com")
    public_id = _create_twin(client, token_a).json()["public_id"]

    res = client.patch(
        f"/api/v1/skintwins/{public_id}",
        json={"name": "Hijacked"},
        headers=_auth_headers(token_b),
    )
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "SKINTWIN_NOT_FOUND"


def test_update_skintwin_unauthorized(client):
    token = _register_and_login(client, "authupdate@example.com")
    public_id = _create_twin(client, token).json()["public_id"]
    res = client.patch(f"/api/v1/skintwins/{public_id}", json={"name": "No Auth"})
    assert res.status_code == 401


# ── Delete ─────────────────────────────────────────────────────────────────────

def test_delete_skintwin_success(client):
    token = _register_and_login(client, "delete@example.com")
    public_id = _create_twin(client, token).json()["public_id"]

    del_res = client.delete(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token))
    assert del_res.status_code == 204

    # Confirm it's gone
    get_res = client.get(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token))
    assert get_res.status_code == 404


def test_delete_skintwin_cross_user_returns_404(client):
    token_a = _register_and_login(client, "owner3@example.com")
    token_b = _register_and_login(client, "intruder3@example.com")
    public_id = _create_twin(client, token_a).json()["public_id"]

    res = client.delete(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token_b))
    assert res.status_code == 404
    # Confirm original twin still exists for owner
    get_res = client.get(f"/api/v1/skintwins/{public_id}", headers=_auth_headers(token_a))
    assert get_res.status_code == 200


def test_delete_skintwin_unauthorized(client):
    token = _register_and_login(client, "authdelete@example.com")
    public_id = _create_twin(client, token).json()["public_id"]
    res = client.delete(f"/api/v1/skintwins/{public_id}")
    assert res.status_code == 401
