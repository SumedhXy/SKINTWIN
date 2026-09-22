# Milestone 6: Image Alignment + MedSAM-Based Observable Change Analysis

**Date:** 2026-09-18  
**Status:** Completed ✅  
**Tests Passing:** 75 / 75 (8 new Milestone 6 alignment & MedSAM tests)  
**Alembic Migration:** `765be5ecfe7b_add_milestone_6_alignment_medsam_.py`  

---

## 1. Architecture & Pipeline Overview

Milestone 6 builds the observable image-comparison pipeline using **OpenCV feature alignment**, **MedSAM ViT-B pre-trained segmentation**, and **quantitative change measurement**.

```
             Earlier Capture + Latest Capture
                           ↓
             Image Quality Validation Check
                           ↓
             OpenCV Feature Alignment (ORB + RANSAC)
                           ↓
             ROI Prompt Validation
                           ↓
             MedSAM ViT-B Region Segmentation
                           ↓
             Observable Quantitative Measurements
             - Area change (%)
             - Shape similarity (Hu moments)
             - Color distribution (BGR / LAB delta)
             - Position centroid displacement
             - Boundary overlap (IoU)
                           ↓
             Reliability & Uncertainty Evaluation
                           ↓
             PostgreSQL Persistence + FastAPI Endpoint
```

---

## 2. Model Selection — MedSAM ViT-B Integration

### Why MedSAM ViT-B?
- **MedSAM** is the leading open medical/anatomical foundation segmentation model derived from Segment Anything (SAM).
- Provides prompt-based (bounding box / point) zero-shot region localization across diverse anatomical findings.

### Model Interface (`app/services/segmentation/base.py` & `medsam.py`)
```python
class SegmentationModelInterface(ABC):
    @abstractmethod
    def load_model(self) -> bool: pass

    @abstractmethod
    def predict_region(self, image: np.ndarray, prompt: Optional[Dict[str, Any]] = None) -> Dict[str, Any]: pass

    @abstractmethod
    def get_model_info(self) -> Dict[str, Any]: pass
```

### CPU Fallback & Safety Behaviors
- Configuration in `app/core/config.py`: `MODEL_NAME="medsam_vit_b"`, `MODEL_VERSION="1.0.0"`, `MODEL_WEIGHTS_PATH="models/medsam_vit_b.pth"`, `DEVICE="cpu"`.
- If weights file is not present or PyTorch is not loaded:
  - System operates in safe fallback mode.
  - Returns `localization_status="unavailable"` (or ROI prompt boundary extraction) with `error_code="MODEL_WEIGHTS_MISSING"`.
  - **No fabricated masks or clinical predictions are generated.**

---

## 3. OpenCV Feature Alignment Engine (`app/services/alignment_service.py`)

- **ORB Feature Detection**: Extracts up to 1,000 keypoints and descriptors from earlier and latest captures.
- **Hamming Distance Matcher**: Matches descriptors across image pair.
- **RANSAC Homography Estimation**: Computes 3x3 perspective homography matrix `H` and inlier ratio.
- **Perspective Warping**: Warps latest capture into earlier capture image space (`cv2.warpPerspective`).
- **Alignment Metrics Stored**:
  - `alignment_status`: `"aligned"`, `"partially_aligned"`, `"failed"`, or `"not_evaluated"`
  - `alignment_score`: float (0.0 to 1.0)
  - `match_count`, `inlier_count`, `inlier_ratio`, `alignment_method="orb_ransac"`
  - `alignment_error_code`: `None`, `"INSUFFICIENT_KEYPOINTS"`, `"INSUFFICIENT_MATCHES"`, or `"HOMOGRAPHY_FAILED"`

---

## 4. Observable Quantitative Measurements (`app/services/measurement_service.py`)

Measurements are computed strictly from real image data and segmentation masks:

1. **Area**:
   - `earlier_area` & `latest_area` in pixels
   - `area_change_percent`: Relative percentage change $\frac{A_{\text{latest}} - A_{\text{earlier}}}{A_{\text{earlier}}} \times 100\%$
2. **Shape**:
   - Contour Hu moments match score (`cv2.matchShapes`)
   - Perimeter change in pixels
3. **Color**:
   - Mean BGR / LAB color delta inside masked finding region
   - Overall color Euclidean distance $\Delta E_{\text{BGR}}$
   - Brightness lighting delta check
4. **Position**:
   - Centroid shift $(\Delta x, \Delta y)$ and displacement distance $\sqrt{\Delta x^2 + \Delta y^2}$
5. **Boundary**:
   - Mask IoU (Intersection over Union) overlap metric

---

## 5. Reliability & Uncertainty Assessment

Every comparison includes transparent reliability metrics:

- **`reliability_status`**: `"reliable"`, `"needs_review"`, `"unreliable"`, or `"unavailable"`.
- **`uncertainty_reasons`**: Array of human-readable reasons (e.g. `["Image alignment is inaccurate or unverified", "Significant lighting shift between captures"]`).
- **Safety Rule**: If alignment fails, MedSAM segmentation fails, or lighting differs by $> 35$ units, `reliability_status` is automatically downgraded to `"unreliable"` or `"needs_review"`.

---

## 6. Database Migration & Schema Changes

**Alembic Revision:** `765be5ecfe7b_add_milestone_6_alignment_medsam_.py`

### Columns Added to `comparisons` Table
- `processing_status` (`VARCHAR(50)`, default `"completed"`)
- `processing_error_code` (`VARCHAR(50)`)
- `alignment_status`, `alignment_score`, `match_count`, `inlier_count`, `inlier_ratio`, `alignment_method`, `alignment_error_code`
- `localization_status`, `localization_confidence`, `segmentation_model`, `segmentation_model_version`, `segmentation_error_code`
- `earlier_area`, `latest_area`, `area_change_percent`
- `color_change_metrics`, `shape_change_metrics`, `boundary_change_metrics`, `position_change_metrics`
- `measurement_status`, `reliability_status`, `reliability_score`, `uncertainty_reasons`
- `observable_metrics`, `comparison_version`, `analyzed_at`

---

## 7. Sample Comparison API Response

`POST /api/v1/skintwins/st-18b9e16674/comparisons`

```json
{
  "id": "77112233-4455-6677-8899-aabbccddeeff",
  "skintwin_public_id": "st-18b9e16674",
  "earlier_capture_id": "c1f7bca4-927b-4029-a78b-d7db9b48c3b4",
  "latest_capture_id": "f8a9b2c3-1122-3344-5566-778899aabbcc",
  "processing_status": "completed",
  "processing_error_code": null,
  "alignment_status": "aligned",
  "alignment_score": 0.88,
  "match_count": 142,
  "inlier_count": 118,
  "inlier_ratio": 0.831,
  "alignment_method": "orb_ransac",
  "alignment_error_code": null,
  "localization_status": "segmented",
  "localization_confidence": 0.85,
  "segmentation_model": "medsam_vit_b",
  "segmentation_model_version": "1.0.0",
  "segmentation_error_code": null,
  "earlier_area": 5026.5,
  "latest_area": 5280.0,
  "area_change_percent": 5.04,
  "color_change_metrics": {
    "earlier_mean_bgr": [40.0, 40.0, 180.0],
    "latest_mean_bgr": [42.0, 41.0, 178.0],
    "color_bgr_delta": [2.0, 1.0, -2.0],
    "overall_color_distance": 3.0,
    "lighting_brightness_delta": 2.1
  },
  "shape_change_metrics": {
    "hu_moments_match_score": 0.012,
    "earlier_perimeter_px": 251.3,
    "latest_perimeter_px": 257.6
  },
  "boundary_change_metrics": {
    "mask_iou_overlap": 0.912,
    "boundary_variance": "stable"
  },
  "position_change_metrics": {
    "earlier_centroid": [200.0, 200.0],
    "latest_centroid": [202.0, 202.0],
    "centroid_shift_dx_dy": [2.0, 2.0],
    "displacement_px": 2.83
  },
  "comparison_status": "completed",
  "measurement_status": "measured",
  "reliability_status": "reliable",
  "reliability_score": 0.92,
  "uncertainty_reasons": [],
  "observable_change_summary": "Area delta: +5.0%",
  "observable_metrics": {
    "area_change_percent": 5.04
  },
  "comparison_version": "1.0.0",
  "analyzed_at": "2026-09-18T14:05:00Z",
  "created_at": "2026-09-18T14:05:00Z"
}
```

---

## 8. Future Fine-Tuning Preparation Guidelines

The backend architecture is prepared for future skin-specific fine-tuning:

1. **Modular Model Adapter**: `MedSAMSegmentationModel` can be replaced or extended with a fine-tuned weights file (`models/medsam_skintwin_finetuned.pth`).
2. **Dataset Directory Structure**:
```text
dataset/
├── images/
├── masks/
├── metadata/
└── splits/
    ├── train.json
    ├── validation.json
    └── test.json
```
3. **Non-Diagnostic Boundary**:
   - Fine-tuning focuses exclusively on **skin lesion boundary segmentation accuracy**, NOT disease classification or risk prediction.
