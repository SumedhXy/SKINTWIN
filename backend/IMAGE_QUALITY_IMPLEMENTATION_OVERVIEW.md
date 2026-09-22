# Milestone 5: Image Quality Assessment System — Implementation Overview

**Date:** 2026-09-18  
**Status:** Completed ✅  
**Tests Passing:** 67 / 67 (8 new quality assessment tests)  
**Alembic Migration:** `ad4cb0027bd9_add_capture_quality_assessment_fields.py`  

---

## 1. Architecture & Design

The Image Quality Assessment System automatically evaluates whether uploaded skin photographs are technically suitable for future longitudinal comparison using deterministic OpenCV computer vision checks.

```
                    +-----------------------------------+
                    |   Capture Upload (POST /captures) |
                    +-----------------------------------+
                                      |
                                      v
                    +-----------------------------------+
                    |        Private Storage            |
                    |   (Saves image to disk/cloud)     |
                    +-----------------------------------+
                                      |
                                      v
                    +-----------------------------------+
                    |      ImageQualityService          |
                    |  - Resolution / Dimensions check  |
                    |  - Blur detection (Laplacian var) |
                    |  - Lighting / Brightness check    |
                    |  - Framing check (unknown state)  |
                    +-----------------------------------+
                                      |
                                      v
                    +-----------------------------------+
                    |           PostgreSQL DB           |
                    |   (Persists quality_status,       |
                    |    scores, and detailed JSON)     |
                    +-----------------------------------+
```

---

## 2. Deterministic Quality Checks & Thresholds

| Quality Check | Method / Metric | Thresholds | Status / Score |
|---|---|---|---|
| **Resolution** | Image width & height | `< 150px`: Fail<br>`150px – 299px`: Warning<br>`>= 300px`: Pass | `resolution_status`<br>(Score: 0.2 / 0.6 / 1.0) |
| **Blur** | Laplacian Variance ($\nabla^2$) | `< 50.0`: Fail (blurry)<br>`50.0 – 99.9`: Warning (slight blur)<br>`>= 100.0`: Pass (sharp focus) | `blur_status`<br>(Score: var/50 / 0.7 / 1.0) |
| **Lighting** | Mean grayscale brightness ($\mu$) & std ($\sigma$) | `< 40.0`: Fail (underexposed)<br>`> 220.0`: Fail (overexposed)<br>`40–60` or `200–220` or $\sigma < 15$: Warning<br>Else: Pass | `lighting_status`<br>(Score: calc / 0.7 / 1.0) |
| **Framing** | Non-segmenting structural check | `unknown` (explicit non-eval state; automated lesion segmentation requires ML) | `framing_status` = `"unknown"` |

### Overall Status & Comparison Eligibility
- **`quality_status`**:
  - `"unacceptable"` if any sub-check is `"fail"`
  - `"needs_review"` if any sub-check is `"warning"`
  - `"acceptable"` if all sub-checks are `"pass"`
- **`comparison_eligible`**:
  - `True` if `quality_status == "acceptable"` or (`quality_status == "needs_review"` and resolution/blur pass).
  - `False` if `quality_status == "unacceptable"`.

---

## 3. Database Migration & Schema Changes

**Alembic Revision:** `ad4cb0027bd9_add_capture_quality_assessment_fields.py`

### Columns Added to `captures` Table

| Column Name | Type | Description |
|---|---|---|
| `blur_status` | `VARCHAR(50)` | `"pass"`, `"warning"`, `"fail"`, or `"unknown"` |
| `lighting_status` | `VARCHAR(50)` | `"pass"`, `"warning"`, `"fail"`, or `"unknown"` |
| `resolution_status` | `VARCHAR(50)` | `"pass"`, `"warning"`, `"fail"`, or `"unknown"` |
| `framing_status` | `VARCHAR(50)` | `"unknown"`, `"pass"`, `"warning"`, `"fail"` |
| `comparison_eligible` | `BOOLEAN` | `True` if eligible for longitudinal comparison |
| `quality_details` | `TEXT` | JSON string containing detailed sub-scores and reasons |
| `quality_analyzed_at` | `TIMESTAMP` | Timestamp when quality analysis was executed |

---

## 4. API Response Schema Update

All capture responses (`POST /skintwins/{id}/captures`, `GET /captures/{id}`, `GET /skintwins/{id}/timeline`) now include the detailed quality assessment breakdown:

```json
{
  "id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
  "skintwin_public_id": "st-18b9e16674",
  "image_object_key": "users/3eb.../captures/e4f7a18b92484a92a54cd10e9e1122ab.jpg",
  "image_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "captured_at": "2026-09-18T13:30:00Z",
  "uploaded_at": "2026-09-18T13:30:00Z",
  "body_location": "arm",
  "quality_status": "acceptable",
  "quality_score": 1.0,
  "blur_status": "pass",
  "lighting_status": "pass",
  "resolution_status": "pass",
  "framing_status": "unknown",
  "comparison_eligible": true,
  "quality_details": {
    "resolution": {
      "status": "pass",
      "score": 1.0,
      "reason": "Sufficient image dimensions: 400x400px.",
      "width": 400,
      "height": 400
    },
    "blur": {
      "status": "pass",
      "score": 1.0,
      "reason": "Image focus is sharp (Laplacian variance: 142.5).",
      "laplacian_variance": 142.5
    },
    "lighting": {
      "status": "pass",
      "score": 1.0,
      "reason": "Optimal lighting (brightness: 120.0).",
      "mean_brightness": 120.0,
      "contrast_std": 45.2
    },
    "framing": {
      "status": "unknown",
      "reason": "Generic framing (automated lesion segmentation requires ML model)."
    }
  },
  "quality_analyzed_at": "2026-09-18T13:30:00Z",
  "reference_scale_available": false,
  "measurement_status": "unavailable",
  "device_metadata": null,
  "notes": "Follow-up photo."
}
```

---

## 5. Security & Safety Principles

1. **No Medical Diagnosis**:
   - Quality status and scores measure **technical photo quality** (sharpness, lighting, resolution) for comparison usability only.
   - No medical risk, disease detection, or clinical confidence is calculated or claimed.
2. **Uncertainty & Explicit Non-Evaluation**:
   - If framing cannot be determined deterministically, `framing_status` is explicitly set to `"unknown"`.
   - If image byte parsing fails, `quality_status` is set to `"unacceptable"` or `"not_evaluated"` without exposing stack traces or filesystem paths.
3. **Non-Blocking Upload Policy**:
   - Poor photo quality does not reject image upload storage. The photo is safely preserved, but flagged with `comparison_eligible=False` so the app can guide the user to retake a clearer photo.

---

## 6. Testing Summary

**67 / 67 Tests Passing**

### New Quality Assessment Tests (`tests/test_image_quality.py`)
- ✅ `test_quality_service_clear_image` — Sharp high-res photo yields `acceptable` and `comparison_eligible=True`
- ✅ `test_quality_service_blurry_image` — Blurred image yields `blur_status="fail"` and `comparison_eligible=False`
- ✅ `test_quality_service_dark_image` — Underexposed photo yields `lighting_status="fail"`
- ✅ `test_quality_service_overexposed_image` — Overexposed photo yields `lighting_status="fail"`
- ✅ `test_quality_service_lowres_image` — Low dimensions (<150px) yield `resolution_status="fail"`
- ✅ `test_quality_service_corrupt_bytes` — Unparseable byte buffer handles gracefully without crashing
- ✅ `test_api_upload_quality_integration_acceptable` — End-to-end POST capture upload returns full quality metadata
- ✅ `test_api_upload_quality_integration_blurry` — End-to-end POST capture upload reflects blurry quality status

---

## 7. Future ML Integration Points

The `ImageQualityService` uses a modular architecture (`ImageQualityResult` dataclass):
- When a validated ML model for skin lesion segmentation/centering is introduced, it can replace the `framing_status = "unknown"` step in `ImageQualityService.evaluate()`.
- **No custom ML model was trained or used in this milestone**, keeping processing 100% deterministic, fast, and testable.
