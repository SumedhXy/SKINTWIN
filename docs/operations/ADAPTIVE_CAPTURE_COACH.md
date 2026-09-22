# Adaptive Capture Coach — Technical Documentation
## SkinTwin — Standardized Photo Capture Guidance

The **Adaptive Capture Coach** guides users toward capturing standardized, high-quality, and visually consistent photos of skin findings across longitudinal follow-ups.

---

## 1. Objectives & Non-Diagnostic Boundary

* **Purpose**: Optimize image sharpness, lighting, contrast, resolution, framing, and longitudinal capture consistency.
* **Core Product Statement**:
  > *"SkinTwin guides users toward more consistent photographs to support longitudinal visual comparison. It does not guarantee clinical accuracy and does not confirm biological change."*
* **Safety Mandate**: The Capture Coach evaluates photographic and image-processing consistency only. It does not diagnose dermatological conditions, evaluate cancer risk, or determine clinical severity.

---

## 2. Guidance Checks & Thresholds

| Check Category | Metric / Algorithm | Status Thresholds | Actionable Guidance / Message | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **Sharpness / Blur** | OpenCV Laplacian variance $\sigma^2_{\text{Laplacian}}$ | **Fail**: $\sigma^2 < 50$<br>**Warning**: $50 \le \sigma^2 < 100$<br>**Pass**: $\sigma^2 \ge 100$ | *"Image appears blurry. Hold the phone steady and tap to focus."* | **P1 (Fail)**<br>**P2 (Warning)** |
| **Lighting / Exposure** | Mean grayscale brightness $\mu_Y$, contrast $\sigma_Y$, glare ratio $S_{252}$ | **Fail**: $\mu_Y < 35$ or $\mu_Y > 225$<br>**Warning**: $S_{252} > 12\%$ or $\sigma_Y < 15$<br>**Pass**: Optimal ambient | *"Lighting is too dark / overexposed. Use soft, even ambient lighting without direct glare."* | **P1 (Fail)**<br>**P2 (Warning)** |
| **Resolution & Dimensions** | Image dimensions (px) | **Fail**: $\min(w, h) < 150\text{px}$<br>**Warning**: $150 \le \min(w, h) < 300\text{px}$<br>**Pass**: $\min(w, h) \ge 300\text{px}$ | *"Resolution is too low. Higher resolution (300px+) required for reliable analysis."* | **P1 (Fail)**<br>**P2 (Warning)** |
| **Finding Framing** | Border margin luminance vs central region | **Warning**: Severe edge vignette<br>**Pass**: Finding centered | *"Keep the skin finding centered inside the viewfinder."* | **P2 / P3** |
| **Baseline Consistency** | Luminance delta $\Delta\mu_Y$ and scale ratio vs baseline capture | **Warning**: $\Delta\mu_Y > 60$ or scale ratio $> 2.5$<br>**Pass**: Consistent conditions | *"Match the lighting and camera distance of your baseline photo."* | **P3** |

---

## 3. Feedback Priority & Blocking Rules

1. **Priority 1 — Blocking Issues (`status: "blocked"`, `can_continue: false`)**:
   - Corrupt / empty file
   - Severe blur ($\sigma^2 < 50$)
   - Extreme underexposure / overexposure ($\mu_Y < 35$ or $\mu_Y > 225$)
   - Critical low resolution ($< 150\text{px}$)
   - **Behavior**: The save button is disabled with an explanatory banner. The user is required to retake the photo.

2. **Priority 2 — Important Improvements (`status: "needs_adjustment"`, `can_continue: true`)**:
   - Moderate blur ($50 \le \sigma^2 < 100$)
   - Suboptimal lighting / flash glare
   - Moderate resolution ($150 - 299\text{px}$)
   - **Behavior**: User can proceed by confirming the non-blocking limitation disclaimer dialog (*"Proceed with Limitations"*).

3. **Priority 3 — Optional Suggestions (`status: "ready"`, `can_continue: true`)**:
   - Baseline framing match, minor angle recommendations.
   - **Behavior**: Direct save is enabled with green verification badge.

---

## 4. API Endpoints & Schemas

### `POST /api/v1/skintwins/{public_id}/captures/coach`
* **Authorization**: JWT Bearer token; enforces SkinTwin user ownership.
* **Payload**: `multipart/form-data` with `file: UploadFile`.
* **Behavior**: Evaluates image bytes against quality thresholds and baseline comparison without persisting files to storage.
* **Response**: `CaptureCoachResponse`
  ```json
  {
    "status": "needs_adjustment",
    "can_continue": true,
    "quality_score": 0.76,
    "primary_message": "Slight blur detected. Recapturing may improve comparison.",
    "suggestions": [
      "Hold the phone steady when capturing."
    ],
    "checks": [
      {
        "category": "sharpness",
        "status": "warning",
        "score": 0.7,
        "message": "Slight blur detected (sharpness score 72.0)."
      },
      {
        "category": "lighting",
        "status": "pass",
        "score": 1.0,
        "message": "Lighting and contrast appear optimal."
      }
    ],
    "limitations": [
      "Capture guidance evaluates photographic consistency only.",
      "It does not provide medical diagnosis or confirm biological change."
    ],
    "has_baseline_comparison": true
  }
  ```

---

## 5. Flutter UI Components

1. **`AdaptiveCaptureCoachPreCaptureCard`**:
   - Concise checklists for ambient lighting, steadiness, centering, and baseline matching.
2. **Viewfinder Ghost Guide**:
   - Overlay option allowing users to view a subtle translucent baseline reference in the camera viewfinder.
3. **`AdaptiveCaptureCoachReviewSheet`**:
   - Status header badge (`Ready`, `Needs Adjustment`, `Blocked`).
   - Primary prioritized guidance message.
   - Categorized technical checks accordion.
   - Action buttons with non-blocking override confirmation modal.
   - Non-diagnostic disclaimer footer.

---

## 6. Privacy & Security Protections

* **Authentication & Authorization**: Ownership of the SkinTwin is verified on every request; unauthorized users receive `401 Unauthorized` or `404 Not Found`.
* **Zero External AI Processing**: All OpenCV and quality checks run deterministically on the secure backend.
* **No Unnecessary Storage**: Pre-upload coach evaluations do not write temporary files to disk.

---

## 7. Physical-Device Testing Instructions

1. **Pre-Capture**: Open a SkinTwin finding $\to$ Tap **Capture** $\to$ Tap Info icon to review capture tips $\to$ If follow-up, toggle **Ghost Guide** in viewfinder.
2. **Intentional Blurry Photo**: Take a photo while shaking phone $\to$ Verify **Blocked** status banner appears and Save button is disabled.
3. **Suboptimal Lighting**: Take photo in a dark room $\to$ Verify **Needs Adjustment** status and tap **Use Anyway** to confirm warning dialog.
4. **Standard Photo**: Take a sharp, well-lit photo $\to$ Verify **Ready** status with green badge $\to$ Save capture.
