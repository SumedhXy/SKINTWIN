# SkinTwin Deployment Guide

## 1. Current architecture

The project is structured around a FastAPI backend with a PostgreSQL-compatible SQLAlchemy layer, a private filesystem image store, OpenCV and MedSAM processing, and a Flutter frontend. The application already contains the core app logic and security model, but the production deployment path still must be hardened around cloud-managed database credentials, secure CORS settings, server-hosted storage, and environment variables.

## 2. Deployment blockers

- Local PostgreSQL defaults still exist in the backend config and in local development tooling.
- Flutter web still falls back to localhost-based API URLs unless a production `API_BASE_URL` is provided.
- Storage is currently `local` by default and is not yet backed by a private cloud object store.
- There is no provider-specific deployment manifest for a remote service, and no production environment has been created in this workspace.
- No external-device verification can be completed without a live frontend and backend URL.

## 3. Database migration plan

1. Provision a managed PostgreSQL instance with TLS enabled.
2. Store the connection URL in environment variables only; never commit it.
3. Run `alembic upgrade head` against the target cloud database before launch.
4. Validate schema and row counts after migration.
5. For a starter demo, prefer a clean cloud database rather than copying private local dev data.

## 4. Backend deployment plan

- Use the FastAPI app behind a production ASGI server such as Uvicorn.
- Bind to `0.0.0.0` and the container or platform port.
- Set `ENVIRONMENT=production` and `DEBUG=false` in platform secrets.
- Keep `DATABASE_URL`, `JWT_SECRET_KEY`, and `GEMINI_API_KEY` in cloud secrets or environment variables only.
- Use the existing `/health` and `/health/db` endpoints for uptime and database checks.

## 5. Storage plan

The existing code is compatible with a backend-managed private file store. For the simplest production-safe MVP, keep the backend as the gatekeeper for image retrieval and validation, and store files in a private root that is not public. A cloud object store such as S3-compatible storage should be used for real production, but the current code structure is ready for a storage adapter swap.

## 6. ML deployment plan

- OpenCV is intended to run in a headless server environment with CPU-compatible image processing.
- MedSAM is a heavy model and should be treated as a protected resource with request limits, timeouts, and graceful fallback behavior.
- The backend should clearly report when a fallback path replaces a failed MedSAM inference instead of pretending the model succeeded.

## 7. Flutter Web deployment plan

- Build with a production API URL via `--dart-define=API_BASE_URL=https://api.example.com/api/v1`.
- Do not hardcode production URLs in the source.
- Prefer `flutter_secure_storage` on web for session tokens, while documenting web-storage caveats honestly.
- Keep the app responsive and browser-friendly across common desktop and mobile viewport widths.

## 8. Security plan

- Use HTTPS only.
- Restrict CORS to known production origins.
- Ensure image retrieval is authenticated and owner-scoped.
- Never expose server secrets inside the Flutter bundle.
- Log operational metadata only; never log passwords, tokens, or image content.

## 9. Testing plan

- Run backend tests after configuration changes.
- Run Flutter analysis and web build for the frontend.
- Verify the backend health endpoints and database connectivity.
- Test image upload and private retrieval through authenticated endpoints.
- Test a full SkinTwin workflow from browser to comparison.
- Perform error-case testing for database loss, upload failure, expired JWT, and AI-provider fallback.

## 10. Deployment sequence

1. Audit repository
2. Choose deployment architecture
3. Create cloud PostgreSQL
4. Run Alembic migrations
5. Configure private image storage
6. Prepare FastAPI production config
7. Deploy FastAPI
8. Verify `/health`
9. Verify database connectivity
10. Verify image upload
11. Verify OpenCV
12. Verify MedSAM
13. Verify authentication
14. Configure Flutter production API URL
15. Build Flutter Web
16. Deploy Flutter Web
17. Open app from an external device
18. Run the full SkinTwin journey
19. Perform security audit
20. Final deployment verification

## 11. Current repo status

This repository is now closer to a production-ready deployment shape because it has:

- environment-based settings for database and JWT configuration,
- a database health endpoint,
- safer CORS logic tied to environment,
- a deployment Dockerfile and Render manifest template,
- deployment docs for architecture and limitations.

The remaining blocker is real deployment credentials and a live cloud environment; those require external platform access and cannot be created from this workspace alone.
