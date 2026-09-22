# SkinTwin — Comparison Reliability & Uncertainty System

## 1. Executive Summary & Boundaries

The Comparison Reliability & Uncertainty System provides a transparent, deterministic engineering assessment of image quality, computer-vision alignment, lesion segmentation, and quantitative measurements across sequential skin captures.

### Crucial Medical Safety Distinction

> **Comparison Reliability is an Engineering Quality Metric.**
> It quantifies photographic consistency, OpenCV feature alignment, and MedSAM segmentation boundary stability.
> It is **NOT** a medical confidence score, pathology probability, cancer risk metric, or clinical validation.
> SkinTwin never displays single percentages such as "95% medically accurate" or "100% safe."

---

## 2. Multi-Dimensional Reliability Architecture

Reliability is evaluated across four distinct engineering dimensions:

### A. Image Quality
Evaluates individual image captures and pair differences:
- **Resolution Status**: Checks minimum dimensions (min 300x300px recommended).
- **Blur Status**: Evaluates focus sharpness using Laplacian variance (threshold: 50.0).
- **Lighting / Exposure Consistency**: Measures grayscale brightness delta between baseline and follow-up (threshold: 35.0 brightness delta).
- **Statuses**: `acceptable`, `limited`, `poor`, `unavailable`.

### B. Alignment Reliability
Evaluates geometric image space registration using ORB feature detection and RANSAC homography:
- **Keypoint Inlier Ratio**: Proportions of robust inlier matches (score >= 0.50 -> high).
- **Homography Matrix Quality**: Valid perspective transformation.
- **Statuses**: `high`, `moderate`, `low`, `unavailable`.

### C. Segmentation Reliability
Evaluates isolation of region of interest:
- **Model Architecture**: Real neural MedSAM ViT-B vs Fallback Computer Vision (thresholding/contour).
- **Fallback CV Disclosure**: Clearly indicates when fallback was used and explains that fallback results have higher contour variability.
- **Localization Confidence**: Embedding similarity and mask sharpness metrics.
- **Statuses**: `high`, `moderate`, `low`, `unavailable`.

### D. Measurement Reliability
Evaluates extraction and geometric overlap:
- **Area & Perimeter Consistency**.
- **Hu Moments Shape Match Score**.
- **Color Distance (BGR/LAB)**.
- **Centroid Relative Shift (dx, dy)**.
- **Mask IoU Overlap**: Boundary overlap (IoU < 0.20 -> low).
- **Statuses**: `high`, `moderate`, `low`, `unavailable`.

### E. Overall Comparison Reliability (Weakest-Link Principle)
The overall status reflects the weakest critical component:
- `high`: All components acceptable/high with robust alignment and neural MedSAM segmentation.
- `moderate`: Minor lighting shifts, partial alignment, or fallback segmentation applied.
- `low`: Low alignment inliers, poor image quality, or low mask IoU.
- `insufficient`: Failed segmentation, missing masks, or failed alignment.

---

## 3. Structured Uncertainty Model

Uncertainty is structured deterministically as follows:

```json
{
  "overall_reliability": "moderate",
  "reliability_score": 0.72,
  "uncertainty_present": true,
  "uncertainty_reasons": [
    {
      "category": "lighting",
      "severity": "moderate",
      "message": "Lighting shift between captures (brightness delta: 42.0) affects color consistency."
    }
  ],
  "affected_signals": [
    "color"
  ],
  "limitations": [
    "Different lighting conditions directly influence color and tone measurements.",
    "The comparison describes image differences, not medical significance."
  ]
}
```

### Supported Uncertainty Categories
1. `image_quality`: Resolution or overall photographic degradation.
2. `lighting`: Brightness shifts, over/underexposure.
3. `blur`: Motion blur or soft focus.
4. `framing`: Field of view and angle shifts.
5. `alignment`: Keypoint matching limitations.
6. `segmentation`: Edge ambiguity or fallback model usage.
7. `measurement`: IoU variance or geometric noise.
8. `missing_data`: Incomplete measurements.
9. `capture_conditions`: Distance and ambient variance.

---

## 4. Signal-Specific Reliability Rules

Each observable signal maintains its own reliability status:

| Signal | Primary Dependencies | Uncertainty Triggers | Status Output |
|---|---|---|---|
| **Area** | Segmentation success, mask quality, image resolution | Fallback CV used, blurry image | `high` / `moderate` / `low` / `unavailable` |
| **Shape** | Alignment homography, contour moments, framing | Partial alignment, perspective shifts | `high` / `moderate` / `low` / `unavailable` |
| **Color** | Lighting delta, white balance, exposure | Brightness delta > 35.0, dark/bright capture | `high` / `moderate` / `low` / `unavailable` |
| **Position** | Keypoint alignment, centroid tracking | Weak inlier ratio, framing displacement | `high` / `moderate` / `low` / `unavailable` |
| **Overlap (IoU)** | Valid masks, keypoint alignment | IoU < 0.60, fallback segmentation | `high` / `moderate` / `low` / `unavailable` |

---

## 5. Non-Diagnostic Safety Language Rules

All interfaces and responses strictly adhere to non-diagnostic boundaries:

1. **Mandatory Disclaimer**:
   > *"SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance."*
2. **Professional Care Guidance**:
   > *"If you notice concerning changes or have health concerns, consider consulting a qualified healthcare professional."*
3. **Prohibited Overclaims**:
   - Never say: "Everything is normal", "You are safe", "No doctor needed", "Rules out cancer".

---

## 6. Manual Testing Checklist

- [x] **High Quality Pair**: Baseline and follow-up with crisp focus, identical lighting, robust alignment -> Overall High, all signals High.
- [x] **Lighting Shift**: Baseline vs follow-up with intentional exposure variation (>35 delta) -> Overall Moderate, Color reliability Low/Moderate, Lighting uncertainty flag.
- [x] **Blurry Capture**: One blurry capture -> Overall Low/Moderate, Blur uncertainty flag, Shape/Area affected.
- [x] **Alignment Failure**: Featureless or mismatched images -> Alignment Failed, Position unavailable, Overall Insufficient.
- [x] **Fallback Segmentation**: When neural MedSAM weights are unavailable -> Fallback CV chip displayed, limitations disclosed.
- [x] **Insufficient Data State**: Error banner rendered with "Select Different Captures" retry button.
- [x] **Mobile Responsiveness**: Verified on Flutter mobile viewport layouts.
