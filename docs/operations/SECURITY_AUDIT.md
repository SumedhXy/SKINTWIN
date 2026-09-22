# SkinTwin Security Audit

**Version:** 1.0 (Milestone 7.5)
**Audit type:** Self-review (developer)
**Date:** 2026-09-18
**Auditor:** Development team

> This is a developer self-review, not a formal third-party security audit.
> Findings are classified as: **Verified** | **Not Verified** | **Not Applicable** | **Requires Follow-up**

---

## 1. Authentication

| Check | Status | Notes |
|---|---|---|
| JWT signature validation | **Verified** | PyJWT validates signature on every request in `decode_access_token` |
| Token expiration enforced | **Verified** | `exp` claim checked by PyJWT; `ACCESS_TOKEN_EXPIRE_MINUTES=30` |
| Missing token handled | **Verified** | Returns 401 `TOKEN_MISSING` |
| Tampered/invalid token handled | **Verified** | Returns 401 `INVALID_TOKEN` |
| Expired token handled | **Verified** | PyJWT raises `ExpiredSignatureError`, caught and returns 401 |
| Secure password hashing | **Verified** | bcrypt with `gensalt()` on every registration |
| No plaintext password storage | **Verified** | Only `password_hash` field in DB |
| No password in API response | **Verified** | `UserResponse` schema excludes `password_hash`; verified in tests |
| No secrets in source control | **Verified** | `.env` is gitignored; JWT_SECRET_KEY loaded from environment |
| Stateless JWT — no server-side blacklist | **Requires Follow-up** | Logout does not invalidate tokens. Documented limitation. |
| Refresh tokens | **Not Applicable** | Not implemented. No refresh token rotation needed. |

---

## 2. Authorization

| Check | Status | Notes |
|---|---|---|
| User identity from JWT (not client-supplied ID) | **Verified** | `get_current_user` dependency resolves user from token `sub` claim |
| SkinTwin ownership check | **Verified** | `_get_owned_twin` returns 404 for both missing and other-user records |
| Capture ownership check | **Verified** | `user_id` field compared before returning or deleting capture |
| Image access ownership | **Verified** | `/captures/{id}/image` checks `capture.user_id == current_user.id` |
| Comparison ownership | **Verified** | Comparison endpoints verify skintwin ownership |
| Export ownership | **Verified** | `UserService.export_data` uses authenticated user — no client ID param |
| Account deletion ownership | **Verified** | `UserService.delete_account` uses authenticated user + password re-auth |
| SkinTwin deletion ownership | **Verified** | `_get_owned_twin` enforces ownership before delete |
| Capture deletion ownership | **Verified** | CaptureService checks `user_id` before deleting |
| No cross-user data leak via 403 | **Verified** | 404 returned instead of 403 for other-user resources (prevents enumeration) |

---

## 3. Data Protection

| Check | Status | Notes |
|---|---|---|
| No secrets in source control | **Verified** | `.env` gitignored; no hardcoded secrets found |
| No sensitive data in logs | **Verified** | `logger.warning/info` only logs object_key, user_id — no passwords or tokens |
| Secure local token storage (Flutter) | **Verified** | `FlutterSecureStorage` used for JWT; not SharedPreferences |
| Cache cleanup on logout | **Verified** | `AuthService.logout()` deletes `jwt_token` from secure storage |
| Private image handling | **Verified** | No public image URLs; always served through authenticated endpoint |
| Data retention documentation | **Verified** | Documented in `PRIVACY_REQUIREMENTS.md` |
| Export excludes password hashes | **Verified** | `UserExportResponse` schema does not include `password_hash`; tested |
| No sensitive data in error responses | **Verified** | Centralized error handler never exposes stack traces or DB errors |
| No stack traces to client | **Verified** | `general_exception_handler` returns generic 500 message |
| Rate limiting on sensitive endpoints | **Verified** | `/register` (5/min), `/login` (10/min), `/change-password` (5/min), `/me/delete` (3/min) |

---

## 4. AI and Medical Safety

| Check | Status | Notes |
|---|---|---|
| No diagnostic claims in UI | **Verified** | All AI output labeled as "contextual information" not diagnosis |
| No automatic provider sharing | **Verified** | Find Care requests contain no SkinTwin data |
| No fabricated medical conclusions | **Verified** | AI explanation shown with explicit safety disclaimer |
| AI limitations displayed | **Verified** | Disclaimer present on CompareScreen and PrivacySettingsScreen |
| User control over stored AI explanations | **Requires Follow-up** | Deleting a comparison removes the explanation, but no standalone "delete explanation" endpoint exists |
| No automatic third-party data transmission | **Verified** | OpenAI API call is explicit per-comparison; not background/automatic |

---

## 5. Network and Transport

| Check | Status | Notes |
|---|---|---|
| CORS configuration | **Verified** | Debug mode allows `*`; production restricts to configured `CORS_ORIGINS` |
| HTTPS enforcement | **Requires Follow-up** | Not enforced at the application level; depends on deployment proxy (nginx/Cloud Run) |
| Request ID tracking | **Verified** | `X-Request-ID` header added to all requests and responses |

---

## 6. Known Limitations and Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Stateless JWT cannot be invalidated after logout | Medium | Token expires in 30 min; client clears immediately; documented to users |
| Account deletion does not clear previously issued tokens | Medium | Client must clear token; documented in `/auth/logout` response |
| Image file orphan on storage deletion failure | Low | Failure is logged; DB record still removed; orphan cleanup is manual |
| OpenAI API receives structured comparison data | Medium | Raw images not sent; review OpenAI data handling policy |
| No formal third-party security audit | High | This document is a self-review only |
| Server backups may retain deleted data | Medium | Outside application control; documented in privacy requirements |

---

## 7. Conclusion

The application implements standard security practices for its architecture:
bcrypt hashing, stateless JWT, centralized error handling, ownership checks on all
private resources, and secure local token storage.

The primary known limitation is the inability to server-side invalidate JWT tokens
after logout or account deletion, which is inherent to stateless JWT architectures
without a blacklist. This is documented and communicated to users in the UI.

This system has **not** undergone a formal third-party security audit and should not be
deployed to production with real user medical data without one.
