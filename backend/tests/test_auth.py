def test_register_user_success(client):
    payload = {
        "email": "doctor.jane@example.com",
        "password": "SecurePassword123!",
        "full_name": "Dr. Jane Doe",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "doctor.jane@example.com"
    assert data["full_name"] == "Dr. Jane Doe"
    assert "id" in data
    assert "password" not in data
    assert "password_hash" not in data


def test_register_user_duplicate_email(client):
    payload = {
        "email": "duplicate@example.com",
        "password": "SecurePassword123!",
        "full_name": "Original User",
    }
    res1 = client.post("/api/v1/auth/register", json=payload)
    assert res1.status_code == 201

    # Attempt duplicate registration
    res2 = client.post("/api/v1/auth/register", json=payload)
    assert res2.status_code == 409
    data = res2.json()
    assert "error" in data
    assert data["error"]["code"] == "EMAIL_ALREADY_REGISTERED"
    assert "already exists" in data["error"]["message"]


def test_register_user_short_password(client):
    payload = {
        "email": "shortpw@example.com",
        "password": "short",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "VALIDATION_ERROR"


def test_login_success(client):
    # Register user first
    reg_payload = {
        "email": "testlogin@example.com",
        "password": "ValidPassword999!",
        "full_name": "Alex Smith",
    }
    client.post("/api/v1/auth/register", json=reg_payload)

    # Login
    login_payload = {
        "email": "testlogin@example.com",
        "password": "ValidPassword999!",
    }
    response = client.post("/api/v1/auth/login", json=login_payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "testlogin@example.com"


def test_login_invalid_password(client):
    reg_payload = {
        "email": "wrongpw@example.com",
        "password": "ValidPassword999!",
    }
    client.post("/api/v1/auth/register", json=reg_payload)

    login_payload = {
        "email": "wrongpw@example.com",
        "password": "IncorrectPassword!",
    }
    response = client.post("/api/v1/auth/login", json=login_payload)
    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "INVALID_CREDENTIALS"


def test_get_current_user_profile(client):
    reg_payload = {
        "email": "profile@example.com",
        "password": "ValidPassword999!",
        "full_name": "Profile User",
    }
    client.post("/api/v1/auth/register", json=reg_payload)

    # Login to get token
    login_res = client.post("/api/v1/auth/login", json={
        "email": "profile@example.com",
        "password": "ValidPassword999!",
    })
    token = login_res.json()["access_token"]

    # Access /api/v1/users/me
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "profile@example.com"
    assert data["full_name"] == "Profile User"


def test_unauthorized_without_token(client):
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "TOKEN_MISSING"


def test_unauthorized_with_invalid_token(client):
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer totally_invalid_token_string"},
    )
    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "INVALID_TOKEN"
