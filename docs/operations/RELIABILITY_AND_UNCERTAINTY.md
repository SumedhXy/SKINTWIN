# SkinTwin — Comparison Reliability & Uncertainty Architecture

## 1. Overview & Core Product Statement

SkinTwin compares observable visual and geometric characteristics across longitudinal skin-finding captures while communicating engineering reliability, uncertainty factors, and quality limitations.

> **CRITICAL BOUNDARY:**  
> Comparison reliability describes the engineering quality and consistency of image analysis. It is **never** a measure of medical confidence, diagnostic certainty, cancer risk, or biological prognosis.

---

## 2. Reliability Dimensions & Deterministic Rules

The reliability engine employs a strict **weakest-link principle**: an overall comparison score is capped by its most vulnerable critical component.

### A. Image Quality Evaluation
* **Acceptable**: Resolution adequate, sharpness high, lighting balanced.
* **Limited**: Minor blur or moderate lighting deviation present.
* **Poor**: Severe blur or unacceptable brightness/contrast.
* **Unavailable**: Capture image data or metadata is missing.

### B. Alignment Reliability
* **High**: Homography estimation succeeded with high inlier ratio ($\ge 0.60$).
* **Moderate**: Partial alignment or borderline inlier ratio ($0.30 \le \text{ratio} < 0.60$).
* **Low / Unavailable**: Homography failed, alignment error code triggered, or feature match count $< 4$.

### C. Segmentation Reliability
* **High**: MedSAM ViT-B neural segmentation succeeded with confidence $\ge 0.80$.
* **Moderate (Fallback CV)**: Classical Computer Vision (Otsu thresholding, contour extraction) used due to neural model fallback. Explicitly flagged as `is_fallback: true` with boundary uncertainty disclosure.
* **Low**: Low-confidence boundary delineation ($< 0.60$).
* **Unavailable**: Lesion localization failed or mask was empty.

### D. Measurement Reliability
* **High**: All 5 quantitative signals (Area, Shape, Color, Position, Overlap) successfully computed under robust alignment and segmentation.
* **Moderate**: Measured under fallback segmentation or moderate alignment variance.
* **Low**: Severe signal conflicts, very low IoU overlap ($< 0.20$), or extreme displacement.
* **Unavailable**: Measurements missing or uncomputable.

### E. Overall Comparison Reliability Rules
| Level | Rule / Condition | Actionable Guidance |
| :--- | :--- | :--- |
| **High** | All components High/Acceptable, no uncertainty flags | Safe for visual comparison inspection |
| **Moderate** | Any component Limited/Moderate or Fallback CV used | Differences present; interpret cautiously |
| **Low** | Any component Poor/Low or significant capture distortion | Qualitative reference only |
| **Insufficient** | Segmentation failed, alignment failed, or mask missing | Cannot compare reliably; recapture recommended |

---

## 3. Structured Uncertainty Categories

SkinTwin evaluates and discloses specific uncertainty categories without fabricating precision:

1. `image_quality`: Resolution or overall pixel fidelity limitations.
2. `lighting`: Brightness/exposure variations affecting color metrics ($\Delta \text{brightness} > 25$).
3. `blur`: Motion or focal blur reducing contour edge sharpness.
4. `framing`: Perspective, distance, or angle shifts between captures.
5. `alignment`: Feature matching limitations in uniform or low-texture skin.
6. `segmentation`: Fallback CV approximations or low boundary confidence.
7. `measurement`: Signal conflicts or near-zero IoU overlap.
8. `missing_data`: Missing captures, masks, or baseline references.
9. `capture_conditions`: Environmental factors (flash, shadows, glare).

---

## 4. Signal-Specific Limitations

| Signal | Primary Metric | Primary Vulnerability | Limitation Guidance |
| :--- | :--- | :--- | :--- |
| **Area** | Segmented pixel area ($\text{px}^2$, % change) | Boundary approximations, focal distance | Capped when Fallback CV is active |
| **Shape** | Hu Moments invariant distance | Edge blur, contour discretization | Evaluated in aligned coordinate space |
| **Color** | LAB Delta-E color distance, channel shifts | Lighting consistency, white balance | Marked uncertain when lighting $\Delta > 25$ |
| **Position** | Centroid shift ($\Delta x, \Delta y$, displacement px) | Alignment homography, framing angle | High reliability only under strict alignment |
| **Overlap** | Mask Intersection over Union (IoU) | Boundary stability, rigid transformations | Sensitive to non-rigid skin elasticity |

---

## 5. Non-Diagnostic Safety Language

* **Mandatory Safety Disclaimer**:
  > *"SkinTwin describes observable image differences only. It does not diagnose medical conditions or determine their clinical significance."*
* **Professional Care Guidance**:
  > *"If you notice concerning changes or have health concerns, consider consulting a qualified healthcare professional."*
* **Prohibited Terms in System Outputs**:
  * ❌ `harmless`, `safe`, `benign`, `malignant`, `cancerous`, `melanoma`, `normal`, `biological growth`, `95% medically accurate`.

---

## 6. Physical Device Testing Checklist

- [x] High-contrast lesions under direct daylight.
- [x] Low-light captures triggering `lighting` uncertainty flags.
- [x] Deliberate slight blur triggering `blur` uncertainty tags and `shape`/`area` caveats.
- [x] Rotated captures verifying OpenCV feature alignment and Homography recovery.
- [x] Fallback CV execution verifying `is_fallback: true` badge and limitation notes.
- [x] Insufficient data state rendering retry/recapture options cleanly.
