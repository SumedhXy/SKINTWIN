"""
Tests for Milestone 7.5 — User Account Management Endpoints.
Covers: profile update, password change, data export, account deletion, logout.
All tests use in-memory SQLite via conftest.py fixtures.
"""
import pytest
from fastapi.testclient import TestClient


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _register_and_login(client: TestClient, email: str, password: str, full_name: str = "Test User") -> str:
    """Register a user, log in, and return the Bearer token."""
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": full_name,
    })
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert res.status_code == 200, res.text
    return res.json()["access_token"]


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ─── Profile Retrieval ────────────────────────────────────────────────────────

class TestGetUserMe:
    def test_returns_profile_when_authenticated(self, client: TestClient):
        token = _register_and_login(client, "getme@test.com", "password123", "Get Me User")
        res = client.get("/api/v1/users/me", headers=_auth_headers(token))
        assert res.status_code == 200
        data = res.json()
        assert data["email"] == "getme@test.com"
        assert data["full_name"] == "Get Me User"
        assert "password_hash" not in data
        assert "id" in data

    def test_returns_401_without_token(self, client: TestClient):
        res = client.get("/api/v1/users/me")
        assert res.status_code == 401

    def test_returns_401_with_invalid_token(self, client: TestClient):
        res = client.get("/api/v1/users/me", headers={"Authorization": "Bearer not_a_real_token"})
        assert res.status_code == 401


# ─── Profile Update ───────────────────────────────────────────────────────────

class TestUpdateUserMe:
    def test_updates_full_name(self, client: TestClient):
        token = _register_and_login(client, "updateme@test.com", "password123", "Old Name")
        res = client.patch(
            "/api/v1/users/me",
            json={"full_name": "New Name"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 200
        assert res.json()["full_name"] == "New Name"

    def test_strips_whitespace_from_name(self, client: TestClient):
        token = _register_and_login(client, "stripname@test.com", "password123")
        res = client.patch(
            "/api/v1/users/me",
            json={"full_name": "  Padded Name  "},
            headers=_auth_headers(token),
        )
        assert res.status_code == 200
        assert res.json()["full_name"] == "Padded Name"

    def test_clears_name_with_empty_string(self, client: TestClient):
        token = _register_and_login(client, "clearname@test.com", "password123", "Has Name")
        res = client.patch(
            "/api/v1/users/me",
            json={"full_name": ""},
            headers=_auth_headers(token),
        )
        assert res.status_code == 200
        assert res.json()["full_name"] is None

    def test_returns_401_without_token(self, client: TestClient):
        res = client.patch("/api/v1/users/me", json={"full_name": "Hacker"})
        assert res.status_code == 401

    def test_rejects_name_exceeding_max_length(self, client: TestClient):
        token = _register_and_login(client, "longname@test.com", "password123")
        res = client.patch(
            "/api/v1/users/me",
            json={"full_name": "A" * 151},
            headers=_auth_headers(token),
        )
        assert res.status_code == 422


# ─── Change Password ──────────────────────────────────────────────────────────

class TestChangePassword:
    def test_successfully_changes_password(self, client: TestClient):
        token = _register_and_login(client, "changepw@test.com", "OldPass123")
        res = client.post(
            "/api/v1/users/change-password",
            json={"current_password": "OldPass123", "new_password": "NewPass456"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 204

        # Verify new password works for login
        login_res = client.post("/api/v1/auth/login", json={
            "email": "changepw@test.com", "password": "NewPass456"
        })
        assert login_res.status_code == 200

    def test_rejects_incorrect_current_password(self, client: TestClient):
        token = _register_and_login(client, "wrongpw@test.com", "RealPass123")
        res = client.post(
            "/api/v1/users/change-password",
            json={"current_password": "WrongPass!", "new_password": "NewPass456"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 401
        assert res.json()["error"]["code"] == "INVALID_CURRENT_PASSWORD"

    def test_rejects_same_password(self, client: TestClient):
        token = _register_and_login(client, "samepw@test.com", "SamePass123")
        res = client.post(
            "/api/v1/users/change-password",
            json={"current_password": "SamePass123", "new_password": "SamePass123"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "PASSWORD_UNCHANGED"

    def test_rejects_new_password_too_short(self, client: TestClient):
        token = _register_and_login(client, "shortpw@test.com", "ValidPass1")
        res = client.post(
            "/api/v1/users/change-password",
            json={"current_password": "ValidPass1", "new_password": "short"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 422

    def test_password_hash_not_returned_in_any_response(self, client: TestClient):
        token = _register_and_login(client, "nohash@test.com", "TestPass123")
        res = client.post(
            "/api/v1/users/change-password",
            json={"current_password": "TestPass123", "new_password": "NewPass456"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 204
        assert res.content == b""  # No body, no hash leak

    def test_returns_401_without_token(self, client: TestClient):
        res = client.post("/api/v1/users/change-password", json={
            "current_password": "any", "new_password": "newpass123"
        })
        assert res.status_code == 401


# ─── Data Export ──────────────────────────────────────────────────────────────

class TestExportUserData:
    def test_exports_profile_metadata(self, client: TestClient):
        token = _register_and_login(client, "export@test.com", "ExportPass1", "Export User")
        res = client.get("/api/v1/users/me/export", headers=_auth_headers(token))
        assert res.status_code == 200
        data = res.json()
        assert data["profile"]["email"] == "export@test.com"
        assert data["profile"]["full_name"] == "Export User"
        assert "password_hash" not in data["profile"]
        assert "password_hash" not in str(data)  # Sanity check full response

    def test_export_contains_no_secrets(self, client: TestClient):
        token = _register_and_login(client, "nosecrets@test.com", "NoSecrets1")
        res = client.get("/api/v1/users/me/export", headers=_auth_headers(token))
        assert res.status_code == 200
        response_text = res.text
        # None of these should appear in the export
        for forbidden in ["password_hash", "jwt_secret", "JWT_SECRET", "SECRET_KEY"]:
            assert forbidden not in response_text

    def test_export_includes_export_notes(self, client: TestClient):
        token = _register_and_login(client, "notes@test.com", "NotesPass1")
        res = client.get("/api/v1/users/me/export", headers=_auth_headers(token))
        assert res.status_code == 200
        assert len(res.json()["export_notes"]) > 0

    def test_export_initially_has_no_skintwins(self, client: TestClient):
        token = _register_and_login(client, "empty@test.com", "EmptyPass1")
        res = client.get("/api/v1/users/me/export", headers=_auth_headers(token))
        assert res.status_code == 200
        assert res.json()["total_skintwins"] == 0
        assert res.json()["total_captures"] == 0

    def test_returns_401_without_token(self, client: TestClient):
        res = client.get("/api/v1/users/me/export")
        assert res.status_code == 401


# ─── Logout ───────────────────────────────────────────────────────────────────

class TestLogout:
    def test_logout_returns_200_with_notice(self, client: TestClient):
        token = _register_and_login(client, "logout@test.com", "LogoutPass1")
        res = client.post("/api/v1/auth/logout", headers=_auth_headers(token))
        assert res.status_code == 200
        data = res.json()
        assert "message" in data
        assert "notice" in data

    def test_logout_requires_valid_token(self, client: TestClient):
        res = client.post("/api/v1/auth/logout")
        assert res.status_code == 401

    def test_jwt_limitation_documented_in_response(self, client: TestClient):
        token = _register_and_login(client, "jwtlimit@test.com", "JwtLimitPass1")
        res = client.post("/api/v1/auth/logout", headers=_auth_headers(token))
        assert res.status_code == 200
        # Verify the response acknowledges the stateless JWT limitation honestly
        assert "stateless" in res.json()["notice"].lower() or "token" in res.json()["notice"].lower()


# ─── Account Deletion ─────────────────────────────────────────────────────────

class TestDeleteAccount:
    def test_successfully_deletes_account(self, client: TestClient):
        token = _register_and_login(client, "deleteme@test.com", "DeletePass1")
        res = client.request(
            "DELETE",
            "/api/v1/users/me",
            json={"password": "DeletePass1"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 204

    def test_deleted_user_cannot_login(self, client: TestClient):
        token = _register_and_login(client, "deleted2@test.com", "DeletePass2")
        client.request(
            "DELETE",
            "/api/v1/users/me",
            json={"password": "DeletePass2"},
            headers=_auth_headers(token),
        )
        login_res = client.post("/api/v1/auth/login", json={
            "email": "deleted2@test.com", "password": "DeletePass2"
        })
        assert login_res.status_code == 401

    def test_rejects_wrong_password(self, client: TestClient):
        token = _register_and_login(client, "wrongdelete@test.com", "RealPass123")
        res = client.request(
            "DELETE",
            "/api/v1/users/me",
            json={"password": "WrongPassword!"},
            headers=_auth_headers(token),
        )
        assert res.status_code == 401
        assert res.json()["error"]["code"] == "INVALID_PASSWORD"

    def test_rejects_missing_password_body(self, client: TestClient):
        token = _register_and_login(client, "missingpw@test.com", "RealPass123")
        res = client.request(
            "DELETE",
            "/api/v1/users/me",
            json={},
            headers=_auth_headers(token),
        )
        assert res.status_code == 422

    def test_returns_401_without_token(self, client: TestClient):
        res = client.request(
            "DELETE",
            "/api/v1/users/me",
            json={"password": "AnyPassword"},
        )
        assert res.status_code == 401

    def test_cannot_delete_other_users_account(self, client: TestClient):
        """Account deletion uses the authenticated user from the JWT — not a client-supplied ID."""
        token_a = _register_and_login(client, "user_a@test.com", "PassUserA1")
        token_b = _register_and_login(client, "user_b@test.com", "PassUserB1")

        # user_b tries to delete their own account with user_a's token — uses user_a's identity
        res = client.request(
            "DELETE",
            "/api/v1/users/me",
            json={"password": "PassUserA1"},  # correct for user_a, not user_b
            headers=_auth_headers(token_a),  # uses user_a's identity
        )
        # This deletes user_a, not user_b — user_b should still be able to login
        assert res.status_code == 204
        login_b = client.post("/api/v1/auth/login", json={
            "email": "user_b@test.com", "password": "PassUserB1"
        })
        assert login_b.status_code == 200
