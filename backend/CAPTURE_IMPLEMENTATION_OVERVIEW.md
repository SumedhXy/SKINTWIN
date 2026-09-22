# Milestone 3: Capture Upload System — Implementation Overview

**Date:** 2026-09-18  
**Status:** Completed ✅  
**Tests Passing:** 41 / 41 (14 new capture tests)  

---

## 1. Architecture & Design

The Capture Upload System provides secure image storage, metadata tracking, image validation (format & magic bytes), and database synchronization for SkinTwin digital skin tracking.

```
                  +-----------------------------------+
                  |           Client / App            |
                  +-----------------------------------+
                                    |
                    POST /skintwins/{id}/captures
                                    v
                  +-----------------------------------+
                  |          FastAPI Router           |
                  +-----------------------------------+
                                    |
                    JWT Validation & Ownership Check
                                    v
                  +-----------------------------------+
                  |       Image Validation Util       |
                  |  - Size check (max 10MB)          |
                  |  - Magic bytes (JPEG, PNG, WebP)  |
                  |  - SHA-256 calculation            |
                  +-----------------------------------+
                                    |
                                    +-----------------------------------+
                                    |                                   |
                                    v                                   v
                  +-----------------------------------+   +-----------------------------------+
                  |      BaseStorageAdapter           |   |           PostgreSQL DB           |
                  |  - LocalStorageAdapter (dev)      |   |  - Table: captures                |
                  |  - Object Key:                    |   |  - Update: skintwins              |
                  |    users/{uid}/skintwins/{sid}/   |   |    (last_capture_at,               |
                  |    captures/{uuid}.jpg            |   |     baseline_capture_id)          |
                  +-----------------------------------+   +-----------------------------------+
```

---

## 2. API Endpoints

### 1. Upload Capture
`POST /api/v1/skintwins/{public_id}/captures`

- **Headers**: `Authorization: Bearer <token>`
- **Form Data**:
  - `file`: `UploadFile` (Required) — JPEG, PNG, or WebP binary image
  - `notes`: `string` (Optional) — Custom symptom or observation notes
  - `device_metadata`: `string` (Optional) — Camera or device metadata JSON string
- **Status Codes**:
  - `201 Created` — Capture uploaded successfully
  - `400 Bad Request` — Invalid magic bytes or empty file (`EMPTY_FILE`, `UNSUPPORTED_IMAGE_FORMAT`)
  - `401 Unauthorized` — Token missing or invalid
  - `404 Not Found` — SkinTwin not found or owned by another user (`SKINTWIN_NOT_FOUND`)
  - `413 Request Entity Too Large` — File size exceeds limit (`FILE_TOO_LARGE`)

### 2. List Captures for a SkinTwin
`GET /api/v1/skintwins/{public_id}/captures`

- **Headers**: `Authorization: Bearer <token>`
- **Response**: `CaptureListResponse` (total count and array of captures, newest first)
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found`

### 3. Get Single Capture Detail
`GET /api/v1/captures/{capture_id}`

- **Headers**: `Authorization: Bearer <token>`
- **Response**: `CaptureResponse`
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found` (`CAPTURE_NOT_FOUND`)

### 4. Delete Capture
`DELETE /api/v1/captures/{capture_id}`

- **Headers**: `Authorization: Bearer <token>`
- **Status Codes**: `204 No Content`, `401 Unauthorized`, `404 Not Found` (`CAPTURE_NOT_FOUND`)
- **Side Effects**: Removes database record, safe storage file unlinking, and updates parent SkinTwin `baseline_capture_id` / `last_capture_at` if necessary.

---

## 3. Sample Requests & Responses

### Upload Request
```http
POST /api/v1/skintwins/st-18b9e16674/captures HTTP/1.1
Host: 127.0.0.1:8000
Authorization: Bearer eyJhbGciOiJIUzI1Ni...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="mole_photo.jpg"
Content-Type: image/jpeg

<binary data>
------WebKitFormBoundary
Content-Disposition: form-data; name="notes"

Baseline photo taken after dermatology check.
------WebKitFormBoundary--
```

### Upload Response (201 Created)
```json
{
  "id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
  "skintwin_public_id": "st-18b9e16674",
  "image_object_key": "users/3eb76dda-5aea-4d61-8a41-4b8db8ef0db9/skintwins/ac5c4651-ad46-40f1-b623-4cd6fe59409e/captures/e4f7a18b92484a92a54cd10e9e1122ab.jpg",
  "image_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "captured_at": "2026-09-18T13:05:00Z",
  "uploaded_at": "2026-09-18T13:05:00Z",
  "body_location": "shoulder",
  "quality_status": "acceptable",
  "quality_score": null,
  "reference_scale_available": false,
  "measurement_status": "unavailable",
  "device_metadata": null,
  "notes": "Baseline photo taken after dermatology check."
}
```

---

## 4. Storage Architecture & Privacy Controls

1. **Storage Adapter Pattern**:
   - `BaseStorageAdapter` (`app/services/storage/base.py`) defines `save_file()`, `delete_file()`, `get_file()`, `exists()`.
   - `LocalStorageAdapter` (`app/services/storage/local.py`) stores files securely in `LOCAL_STORAGE_DIR` (`backend/uploads/`).
2. **Private Storage Isolation**:
   - Images are **never** placed in publicly served web directories.
   - Object keys use structured paths: `users/{user_id}/skintwins/{skintwin_id}/captures/{uuid}.{ext}`.
   - Raw client filenames are discarded to prevent unsafe characters or path traversal.
3. **Path Traversal Protection**:
   - All object key lookups are resolved against the storage root path and validated to prevent directory traversal (`../`).

---

## 5. Database Schema & Models

No new database schema changes were required because `captures` table and `skintwins.baseline_capture_id` were established during initial Alembic migrations (`3707d49db3c9_initial_tables.py`).

### Capture Record Metadata Saved
- `id` (UUID)
- `skintwin_id` (FK → `skintwins.id` CASCADE)
- `user_id` (FK → `users.id` CASCADE)
- `image_object_key` (String 500)
- `image_hash` (SHA-256 String 64)
- `captured_at` & `uploaded_at` (TIMESTAMPTZ)
- `quality_status` (default: `"acceptable"`)
- `measurement_status` (default: `"unavailable"`)

### SkinTwin Automatic Updates
- `last_capture_at` is updated to the capture's timestamp.
- `baseline_capture_id` is automatically set to the first uploaded capture ID if currently `None`.
- On capture deletion, `baseline_capture_id` shifts to the oldest remaining capture (or `None`).

---

## 6. Security Model & Validation

1. **Strict Ownership Control**:
   - Every capture endpoint enforces ownership checks via `_get_owned_twin` or `capture.user_id == user.id`.
   - Requests for another user's capture return **404** (not 403) to prevent resource existence leaks.
2. **Multi-Layer Image Validation**:
   - **Empty check**: Rejects 0-byte files with `400 EMPTY_FILE`.
   - **Size limit**: Rejects files exceeding `MAX_UPLOAD_SIZE_BYTES` (default 10MB) with `413 FILE_TOO_LARGE`.
   - **Magic byte inspection**:
     - `\xff\xd8\xff` → JPEG
     - `\x89PNG\r\n\x1a\n` → PNG
     - `RIFF....WEBP` → WebP
     - Other signatures → `400 UNSUPPORTED_IMAGE_FORMAT`.
3. **SHA-256 Hashing**:
   - Calculates exact SHA-256 hash of image bytes for data integrity and duplicate checking without exposing image content.

---

## 7. Testing Summary

**41 / 41 Tests Passing**

### Capture Tests Breakdown (`tests/test_captures.py`)
- ✅ `test_upload_capture_unauthorized` — 401 without JWT
- ✅ `test_upload_capture_invalid_token` — 401 with bad JWT
- ✅ `test_upload_jpeg_success` — Valid JPEG upload & storage verification
- ✅ `test_upload_png_success` — Valid PNG format
- ✅ `test_upload_webp_success` — Valid WebP format
- ✅ `test_upload_invalid_magic_bytes` — 400 on fake image data
- ✅ `test_upload_empty_file` — 400 on 0-byte file
- ✅ `test_upload_oversized_file` — 413 on file exceeding size limit
- ✅ `test_upload_unsafe_filename` — Safe key generation preventing `../` traversal
- ✅ `test_cross_user_upload_returns_404` — 404 on uploading to another user's SkinTwin
- ✅ `test_cross_user_list_returns_404` — 404 on listing another user's captures
- ✅ `test_cross_user_get_capture_returns_404` — 404 on viewing another user's capture
- ✅ `test_cross_user_delete_capture_returns_404` — 404 on deleting another user's capture
- ✅ `test_capture_lifecycle_and_skintwin_updates` — Full upload, listing, baseline update, and cleanup test

---

## 8. Known Limitations & Cloud Storage Migration Plan

### Current Local Setup (Development)
- Images stored on local disk under `backend/uploads/`.
- Ideal for local testing and development.

### Cloud Storage Migration Plan (Future Production Deployment)
When moving to Cloud Run or Production:
1. Implement `S3StorageAdapter` or `GoogleCloudStorageAdapter` implementing `BaseStorageAdapter`.
2. Configure environment variable: `STORAGE_TYPE=gcs` or `STORAGE_TYPE=s3`.
3. Update `get_storage_adapter()` factory to instantiate the cloud storage adapter.
4. No changes required to API endpoints or DB schema.
