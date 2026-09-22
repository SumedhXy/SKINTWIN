# Multi-Signal Change Narrative: Architecture & Specification

## 1. Feature Objective & Core Product Statement

The **Multi-Signal Change Narrative** translates raw computer-vision measurements and image quality metrics across longitudinal captures into a transparent, observable narrative.

> **Core Product Statement**:
> SkinTwin compares observable image features across captures while communicating quality limitations, reliability, and uncertainty.
>
> SkinTwin is an engineering image comparison tool. It **never claims biological progression, diagnoses conditions, or determines lesion malignancy**.

---

## 2. API Endpoints & Structured Narrative Schema

### Endpoints
* `GET /api/v1/comparisons/{comparison_id}/explanation`
* `POST /api/v1/comparisons/{comparison_id}/explanation` (Force Regenerate)

### Response Schema (`AIExplanationResponse`)
```json
{
  "narrative_summary": {
    "title": "Observable differences detected",
    "description": "Observable differences were measured in Area, Color across captures with moderate reliability.",
    "status": "observable_difference"
  },
  "signals": [
    {
      "name": "Area",
      "baseline_value": 120.4,
      "followup_value": 135.8,
      "change_value": 12.8,
      "change_unit": "percent",
      "direction": "increased",
      "status": "observable_difference",
      "reliability": "moderate",
      "explanation": "The measured segmented area appears larger in the follow-up image, from 120.4 to 135.8 px (+12.8%)."
    },
    {
      "name": "Shape",
      "baseline_value": 140.5,
      "followup_value": 148.2,
      "change_value": 0.042,
      "change_unit": "score",
      "direction": "stable",
      "status": "stable",
      "reliability": "high",
      "explanation": "Contour shape is consistent between captures (variation score 0.042)."
    },
    {
      "name": "Color",
      "baseline_value": [120.0, 130.0, 140.0],
      "followup_value": [125.0, 135.0, 145.0],
      "change_value": 8.6,
      "change_unit": "delta_e",
      "direction": "differed",
      "status": "observable_difference",
      "reliability": "moderate",
      "explanation": "A difference in measured color features was detected across the segmented area (color distance 8.6)."
    },
    {
      "name": "Position",
      "baseline_value": [150.0, 150.0],
      "followup_value": [152.0, 151.0],
      "change_value": 2.2,
      "change_unit": "px",
      "direction": "stable",
      "status": "stable",
      "reliability": "high",
      "explanation": "The detected region position is well-aligned between captures (2.2 px relative displacement)."
    },
    {
      "name": "Segmentation Overlap",
      "baseline_value": null,
      "followup_value": null,
      "change_value": 0.88,
      "change_unit": "iou",
      "direction": "stable",
      "status": "stable",
      "reliability": "high",
      "explanation": "High mask overlap (88.0% IoU), indicating strong boundary alignment between captures."
    }
  ],
  "narrative_reliability": {
    "overall": "moderate",
    "quality_status": "acceptable",
    "alignment_status": "acceptable",
    "segmentation_status": "completed",
    "limitations": [
      "Lighting conditions may affect color comparison."
    ]
  },
  "narrative_uncertainty": {
    "present": true,
    "explanation": "Some differences may be influenced by capture conditions such as lighting angle or camera distance."
  },
  "safety_message": "This is an analysis of observable image differences and is not a medical diagnosis.",
  "recommended_next_step": "Continue standardized tracking. If you notice concerning changes or have health concerns, consider consulting a qualified healthcare professional."
}
```

---

## 3. Deterministic Signal Interpretation Rules

| Signal | Evaluated Metrics | Direction Categories | Engineering Reliability Logic |
| :--- | :--- | :--- | :--- |
| **Area** | Baseline px, Follow-up px, % Delta | `increased` (>5%), `decreased` (<-5%), `stable` (±5%), `unavailable` | `high` if alignment & MedSAM verified; `moderate` on lighting/angle variance; `insufficient` if unsegmented. |
| **Shape** | Hu Moments match score, perimeter px | `differed` (Hu > 0.15), `stable`, `unavailable` | `high` if ORB alignment verified; `moderate`/`low` if feature matching is sparse. |
| **Color** | Mean BGR / LAB, Delta E, Lighting Brightness Delta | `differed` (Delta > 15), `stable`, `unavailable` | Degrades to `low` if ambient lighting shift > 35 brightness units. |
| **Position** | Centroid Shift $dx, dy$, Displacement px | `shifted` (>10 px), `stable`, `unavailable` | `high` if aligned; flags framing/pose shift if $>10$ px. |
| **Overlap** | Mask IoU Overlap % | `stable` ($\ge 80\%$), `differed` ($<80\%$), `unavailable` | Evaluates physical coordinate overlap between aligned masks. |

---

## 4. Engineering Reliability Levels

1. **`high`**: Verified image quality, ORB-RANSAC alignment score $\ge 0.80$, MedSAM segmentation completed, mask IoU $\ge 0.80$, no major lighting shift.
2. **`moderate`**: Measurements computed, but minor capture variations exist (e.g. lighting delta $>35$ or mask IoU between $50\% - 80\%$).
3. **`low`**: Weak alignment score $<0.50$, mask IoU $<50\%$, or 3+ uncertainty indicators flagged.
4. **`insufficient`**: Alignment failed, region segmentation failed, or image files unreadable.

---

## 5. Non-Diagnostic Safety & AI Fallback Protocol

* **Safety Filters**: Prohibits terms like `harmless`, `safe`, `benign`, `malignant`, `cancerous`, `melanoma`, `normal`, `biological growth`.
* **Numerical Preservation**: Verifies that LLM-generated explanations strictly preserve exact numeric values and percentage directions.
* **Deterministic Fallback**: Whenever an API key is missing, API call times out, schema fails, or safety violations occur, the system immediately falls back to `DeterministicAIProvider`.

---

## 6. Verification & Test Results

* **Backend Test Suite**: `122 passed` (Full regression) + `12 passed` (`test_multi_signal_narrative.py` & `test_milestone6_9_ai_explanation.py`).
* **Frontend Test Suite**: `36 passed` (All widget, model, provider, and narrative tests).
* **Analyzer**: `0 errors, 0 warnings` on new and modified components.
