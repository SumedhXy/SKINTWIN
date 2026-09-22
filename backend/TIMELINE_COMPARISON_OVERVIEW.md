# Milestone 4: Timeline & Photo Comparison Engine — Implementation Overview

**Date:** 2026-09-18  
**Status:** Completed ✅  
**Tests Passing:** 59 / 59 (18 new timeline & comparison tests)  

---

## 1. Architecture & Design

Milestone 4 establishes the chronological tracking foundation and image comparison engine for SkinTwin digital skin tracking.

```
                           +-----------------------------------+
                           |            Client / App           |
                           +-----------------------------------+
                                     |            |
         GET /skintwins/{id}/timeline|            |POST /skintwins/{id}/comparisons
                                     v            v
                           +-----------------------------------+
                           |          FastAPI Router           |
                           +-----------------------------------+
                                     |            |
                    +----------------+            +----------------+
                    |                                              |
                    v                                              v
      +----------------------------+                +----------------------------+
      |      TimelineService       |                |     ComparisonService      |
      | - Chronological capture    |                | - Earlier/latest capture   |
      |   progression (asc/desc)   |                |   chronology validation    |
      | - Pagination support       |                | - Same-twin ownership check|
      | - Baseline capture info    |                | - Initial non-eval states  |
      +----------------------------+                |   (not_analyzed, etc.)     |
                                                    +----------------------------+
                    |                                              |
                    +-----------------------+----------------------+
                                            |
                                            v
                            +-------------------------------+
                            |         PostgreSQL DB         |
                            |  - captures table             |
                            |  - comparisons table          |
                            |  - skintwins table            |
                            +-------------------------------+
```

---

## 2. API Endpoints

### 1. SkinTwin Timeline
`GET /api/v1/skintwins/{public_id}/timeline`

- **Headers**: `Authorization: Bearer <token>`
- **Query Params**:
  - `order`: `"asc"` | `"desc"` (Default: `"desc"`, newest first)
  - `limit`: `int` (Default: `50`, min 1, max 100)
  - `offset`: `int` (Default: `0`)
- **Response**: `TimelineResponse`
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found` (`SKINTWIN_NOT_FOUND`)

### 2. Stream Authorized Capture Image
`GET /api/v1/captures/{capture_id}/image`

- **Headers**: `Authorization: Bearer <token>`
- **Response**: Binary image bytes (`image/jpeg`, `image/png`, or `image/webp`)
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found` (`CAPTURE_NOT_FOUND`)

### 3. Create Comparison Pair
`POST /api/v1/skintwins/{public_id}/comparisons`

- **Headers**: `Authorization: Bearer <token>`
- **JSON Body**:
  ```json
  {
    "earlier_capture_id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
    "latest_capture_id": "f8a9b2c3-1122-3344-5566-778899aabbcc"
  }
  ```
- **Validation Rules**:
  - Both captures must exist and belong to the authenticated user.
  - Both captures must belong to the specified SkinTwin.
  - `earlier_capture_id` and `latest_capture_id` cannot be identical (`SAME_CAPTURE_PAIR`).
  - `earlier_capture.captured_at` cannot be later than `latest_capture.captured_at` (`INVALID_CAPTURE_CHRONOLOGY`).
- **Status Codes**: `201 Created`, `400 Bad Request`, `401 Unauthorized`, `404 Not Found`

### 4. List Comparisons for a SkinTwin
`GET /api/v1/skintwins/{public_id}/comparisons`

- **Headers**: `Authorization: Bearer <token>`
- **Response**: `ComparisonListResponse`
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found`

### 5. Get Single Comparison Detail
`GET /api/v1/comparisons/{comparison_id}`

- **Headers**: `Authorization: Bearer <token>`
- **Response**: `ComparisonResponse`
- **Status Codes**: `200 OK`, `401 Unauthorized`, `404 Not Found` (`COMPARISON_NOT_FOUND`)

### 6. Delete Comparison
`DELETE /api/v1/comparisons/{comparison_id}`

- **Headers**: `Authorization: Bearer <token>`
- **Status Codes**: `204 No Content`, `401 Unauthorized`, `404 Not Found`

---

## 3. Sample Requests & Responses

### 1. GET Timeline Response (200 OK)
```json
{
  "skintwin_public_id": "st-18b9e16674",
  "skintwin_name": "Left Shoulder Mole",
  "baseline_capture_id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
  "total_captures": 2,
  "items": [
    {
      "id": "f8a9b2c3-1122-3344-5566-778899aabbcc",
      "skintwin_public_id": "st-18b9e16674",
      "image_object_key": "users/3eb.../captures/e4f7a18b92484a92a54cd10e9e1122ab.jpg",
      "image_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "captured_at": "2026-09-18T13:10:00Z",
      "uploaded_at": "2026-09-18T13:10:00Z",
      "body_location": "shoulder",
      "quality_status": "acceptable",
      "quality_score": null,
      "reference_scale_available": false,
      "measurement_status": "unavailable",
      "device_metadata": null,
      "notes": "Follow-up photo after 2 weeks."
    },
    {
      "id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
      "skintwin_public_id": "st-18b9e16674",
      "image_object_key": "users/3eb.../captures/a1b2c3d4e5f6.jpg",
      "image_hash": "d41d8cd98f00b204e9800998ecf8427e",
      "captured_at": "2026-09-01T10:00:00Z",
      "uploaded_at": "2026-09-01T10:00:00Z",
      "body_location": "shoulder",
      "quality_status": "acceptable",
      "quality_score": null,
      "reference_scale_available": false,
      "measurement_status": "unavailable",
      "device_metadata": null,
      "notes": "Baseline photo."
    }
  ]
}
```

### 2. POST Comparison Response (201 Created)
```json
{
  "id": "77112233-4455-6677-8899-aabbccddeeff",
  "skintwin_public_id": "st-18b9e16674",
  "earlier_capture_id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
  "latest_capture_id": "f8a9b2c3-1122-3344-5566-778899aabbcc",
  "comparison_status": "not_analyzed",
  "alignment_status": "not_evaluated",
  "reliability_status": "unavailable",
  "observable_change_summary": null,
  "created_at": "2026-09-18T13:20:00Z"
}
```

---

## 4. Initial Non-Evaluation States & Future ML Points

In accordance with strict safety directives:
- **No diagnosis or disease prediction is performed.**
- **No visual changes are fabricated or assumed.**

### Default Comparison States
- `comparison_status`: `"not_analyzed"`
- `alignment_status`: `"not_evaluated"`
- `reliability_status`: `"unavailable"`
- `observable_change_summary`: `null`

### Future Computer Vision / ML Integration Points
When CV/ML alignment models (e.g. OpenCV affine alignment, Siamese feature comparison) are ready:
1. An async worker task (Celery / BackgroundTask) can process `comparison_id`.
2. Compute image alignment score → update `alignment_status` (`"aligned"`, `"poor_alignment"`).
3. Compute image registration & feature delta → update `observable_change_summary` (e.g. `"Area change: +2.1%"`) and `comparison_status` (`"completed"`).

---

## 5. Security Model & Data Protection

1. **Strict Ownership Isolation**:
   - Every endpoint checks user ownership of SkinTwin and captures.
   - Cross-user attempts return **404 Not Found** (preventing record enumeration).
2. **Authorized Binary Image Streaming**:
   - `GET /api/v1/captures/{capture_id}/image` requires JWT and verifies ownership before streaming image bytes.
   - Filesystem paths are never exposed.

---

## 6. Testing Summary

**59 / 59 Tests Passing**

### Timeline & Comparison Tests (`tests/test_timeline_and_comparisons.py`)
- ✅ `test_timeline_empty` — Returns empty array & baseline info
- ✅ `test_timeline_ordering_and_baseline` — Chronological ordering (asc & desc)
- ✅ `test_timeline_pagination` — Offset & limit pagination
- ✅ `test_timeline_cross_user_returns_404` — Cross-user protection
- ✅ `test_timeline_unauthorized` — 401 without JWT
- ✅ `test_get_capture_image_success` — Authorized image stream
- ✅ `test_get_capture_image_cross_user_returns_404` — 404 on streaming another user's image
- ✅ `test_get_capture_image_unauthorized` — 401 without JWT
- ✅ `test_create_comparison_success` — Successful comparison pair creation
- ✅ `test_create_comparison_same_capture_error` — 422 on using same capture twice
- ✅ `test_create_comparison_invalid_chronology` — 400 on earlier > latest capture timestamp
- ✅ `test_create_comparison_missing_capture` — 404 on invalid capture ID
- ✅ `test_comparison_cross_user_returns_404` — Cross-user protection across all operations
- ✅ `test_comparison_lifecycle` — Create, list, retrieve, and delete comparison
