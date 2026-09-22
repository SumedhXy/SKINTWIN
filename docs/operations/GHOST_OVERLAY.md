# SkinTwin — Ghost Overlay System Documentation

## 1. Feature Objective & Core Product Statement

Ghost Overlay enables users to visually compare two standardized captures (a baseline capture and a follow-up capture) taken over time for the same SkinTwin.

> **CRITICAL BOUNDARY & MANDATORY DISCLAIMER:**  
> *"Ghost Overlay supports visual comparison of photographs. It does not diagnose medical conditions or determine the medical significance of observed differences."*

Ghost Overlay helps users assess observable visual characteristics:
* Finding position and apparent movement
* Image framing and capture perspective
* Contour shape and estimated boundary region
* Relative size
* Alignment quality and capture consistency

---

## 2. Viewing Modes

### Mode A: Side-by-Side (`sideBySide`)
* Displays baseline and follow-up images side by side in equal proportions with aspect ratio preserved.
* Displays distinct capture dates and labels: `Baseline: YYYY-MM-DD` and `Follow-up: YYYY-MM-DD`.
* Supports synchronized interactive zoom and pan via `InteractiveViewer`.

### Mode B: Opacity Overlay (`opacity`)
* Superimposes the baseline and follow-up images in the same visual area.
* Provides an interactive continuous Opacity Slider:
  * `0%`: 100% Follow-up visible
  * `50%`: 50/50 Blended overlay
  * `100%`: 100% Baseline visible
* Features one-tap quick action buttons: `Solo Follow-up`, `50% Blend`, and `Solo Baseline`.
* Includes a Reset View control that returns opacity to 50% and clears zoom transformations.

### Mode C: Blink Comparison (`blink`)
* Rapidly alternates between the baseline and follow-up images on a configurable timer.
* Controls: `Start Blink` / `Pause Blink` and manual `Step Swap`.
* Adjustable Blink Speed: `Fast (400ms)`, `Normal (800ms)`, `Slow (1400ms)`.
* Visual active-image indicator displaying `[● Active: Baseline]` vs `[● Active: Follow-up]`.

### Mode D: Split Swipe (`splitSwipe`)
* Interactive horizontal reveal divider comparing the two images across a single viewport.

---

## 3. Alignment Integration & Limitation Handling

Ghost Overlay utilizes existing OpenCV ORB feature detection and RANSAC homography estimation from the backend alignment pipeline.

### Alignment Status Indicators:
1. **Alignment Verified (`aligned`)**:
   * Succeeded with verified homography matrix and sufficient inliers ($\ge 0.60$ ratio).
   * Green status badge: *"Alignment Verified: Feature registration succeeded with verified homography (ORB + RANSAC)."*
2. **Alignment Limited (`partially_aligned`)**:
   * Partial feature matches with marginal inliers.
   * Amber warning banner: *"Alignment Limited: Differences in position may be influenced by framing or camera perspective. Interpret overlay cautiously."*
3. **Alignment Unavailable / Failed (`failed` / `not_evaluated`)**:
   * Insufficient matching keypoints or homography failure.
   * Red notice banner: *"Alignment Unavailable: Images could not be geometrically registered. Use Side-by-Side view for visual reference."*

---

## 4. Privacy & Security

* **Owner-Only Image Access**: Captures can only be streamed by the authenticated owner via JWT authorization (`GET /api/v1/captures/{id}/image`).
* **Tenant Isolation**: Cross-user capture access is rejected with `404 Not Found`.
* **No Public Image URLs**: Images are streamed as binary memory buffers with authenticated headers and never stored on public CDNs.
* **No External AI Image Sharing**: Visual alignment and overlay blending occur purely on-device and in private local pipelines without transmitting raw photos to third-party generative models.

---

## 5. Non-Diagnostic Language Boundaries

* **Prohibited Words**:
  * ❌ `confirmed growth`, `confirmed spreading`, `cancer progression`, `safe`, `harmless`, `disease confirmed`, `disease ruled out`, `95% medically accurate`.
* **Approved Observational Vocabulary**:
  * ✅ `visual difference`, `apparent difference`, `alignment limitation`, `capture-condition variation`, `estimated image-analysis region`.

---

## 6. Verification & Test Results

* **Backend Tests (`tests/test_ghost_overlay.py`)**: `7 passed, 0 failed`.
* **Frontend Tests (`test/ghost_overlay_test.dart`)**: `6 passed, 0 failed`.
* **Full Frontend Suite (`flutter test`)**: `52 passed, 0 failed`.
* **Flutter Analyzer (`flutter analyze`)**: `0 errors, 0 warnings`.

---

## 7. Physical Device Testing Checklist

- [x] Test responsive layout on narrow mobile viewports (<380px) and wide desktop viewports.
- [x] Test Opacity Slider smoothly blending baseline and follow-up captures.
- [x] Test Blink Comparison start/pause and speed selector under 60fps refresh.
- [x] Verify alignment warning appears when comparing captures from different angles.
- [x] Verify Non-Diagnostic Disclaimer is prominent and readable across all modes.
