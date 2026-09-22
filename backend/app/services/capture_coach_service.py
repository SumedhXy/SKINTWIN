import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any, Tuple
import numpy as np
import cv2

from app.schemas.capture import CaptureCoachCheckItem, CaptureCoachResponse

logger = logging.getLogger(__name__)


class CaptureCoachService:
    """
    Deterministic Image Quality & Adaptive Capture Coach Guidance Engine.
    Evaluates sharpness, lighting/contrast, resolution, framing, and baseline consistency.
    Enforces prioritized guidance with blocking vs non-blocking rules.
    """

    @classmethod
    def evaluate_capture(
        cls,
        file_bytes: bytes,
        baseline_bytes: Optional[bytes] = None,
    ) -> CaptureCoachResponse:
        """
        Evaluate a capture image against technical quality thresholds and optional baseline.
        Returns prioritized feedback, individual check categories, and blocking/non-blocking readiness.
        """
        # 1. Handle unreadable or empty bytes
        if not file_bytes:
            return cls._build_corrupt_response("Empty image file provided.")

        try:
            np_arr = np.frombuffer(file_bytes, np.uint8)
            img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

            if img is None:
                return cls._build_corrupt_response("Image file is corrupt or unreadable.")

            height, width = img.shape[:2]
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            checks: List[CaptureCoachCheckItem] = []
            priority1_issues: List[Tuple[str, List[str]]] = []
            priority2_issues: List[Tuple[str, List[str]]] = []
            priority3_suggestions: List[Tuple[str, List[str]]] = []

            # -------------------------------------------------------------
            # Check 1: Resolution & Dimensions
            # -------------------------------------------------------------
            res_item, res_p1, res_p2 = cls._check_resolution(width, height)
            checks.append(res_item)
            if res_p1:
                priority1_issues.append(res_p1)
            if res_p2:
                priority2_issues.append(res_p2)

            # -------------------------------------------------------------
            # Check 2: Sharpness / Blur (Laplacian Variance)
            # -------------------------------------------------------------
            blur_item, blur_p1, blur_p2 = cls._check_sharpness(gray)
            checks.append(blur_item)
            if blur_p1:
                priority1_issues.append(blur_p1)
            if blur_p2:
                priority2_issues.append(blur_p2)

            # -------------------------------------------------------------
            # Check 3: Lighting, Brightness & Contrast
            # -------------------------------------------------------------
            light_item, light_p1, light_p2 = cls._check_lighting(gray)
            checks.append(light_item)
            if light_p1:
                priority1_issues.append(light_p1)
            if light_p2:
                priority2_issues.append(light_p2)

            # -------------------------------------------------------------
            # Check 4: Finding Framing & Centering
            # -------------------------------------------------------------
            frame_item, frame_p2, frame_p3 = cls._check_framing(gray, width, height)
            checks.append(frame_item)
            if frame_p2:
                priority2_issues.append(frame_p2)
            if frame_p3:
                priority3_suggestions.append(frame_p3)

            # -------------------------------------------------------------
            # Check 5: Baseline Consistency (if baseline exists)
            # -------------------------------------------------------------
            has_baseline = False
            if baseline_bytes:
                base_item, base_p2, base_p3 = cls._check_baseline_consistency(
                    img, gray, baseline_bytes
                )
                if base_item:
                    has_baseline = True
                    checks.append(base_item)
                    if base_p2:
                        priority2_issues.append(base_p2)
                    if base_p3:
                        priority3_suggestions.append(base_p3)

            # -------------------------------------------------------------
            # Quality Score Calculation
            # -------------------------------------------------------------
            # Base score from valid checks with weights
            valid_scores = [c.score for c in checks if c.score is not None]
            quality_score = (
                round(float(sum(valid_scores) / len(valid_scores)), 2)
                if valid_scores
                else None
            )

            # -------------------------------------------------------------
            # Prioritized Feedback & Readiness Status
            # -------------------------------------------------------------
            suggestions: List[str] = []

            if priority1_issues:
                # Priority 1: Blocking
                status = "blocked"
                can_continue = False
                primary_message = priority1_issues[0][0]
                for msg, sugg_list in priority1_issues + priority2_issues:
                    for s in sugg_list:
                        if s not in suggestions:
                            suggestions.append(s)
            elif priority2_issues:
                # Priority 2: Important Improvements (Non-blocking override allowed)
                status = "needs_adjustment"
                can_continue = True
                primary_message = priority2_issues[0][0]
                for msg, sugg_list in priority2_issues + priority3_suggestions:
                    for s in sugg_list:
                        if s not in suggestions:
                            suggestions.append(s)
            elif priority3_suggestions:
                # Priority 3: Minor suggestions
                status = "ready"
                can_continue = True
                primary_message = "Capture is ready for comparison. Minor consistency tips available."
                for msg, sugg_list in priority3_suggestions:
                    for s in sugg_list:
                        if s not in suggestions:
                            suggestions.append(s)
            else:
                # Fully optimal
                status = "ready"
                can_continue = True
                primary_message = "Capture is clear, well-framed, and ready for comparison."
                suggestions.append("Proceed with saving this capture.")

            limitations = [
                "Capture guidance evaluates photographic and image-processing consistency.",
                "It does not provide medical diagnosis, clinical risk evaluation, or confirm biological change.",
                "Variations in lighting, camera distance, and skin stretch may affect visual comparison.",
            ]

            return CaptureCoachResponse(
                status=status,
                can_continue=can_continue,
                quality_score=quality_score,
                primary_message=primary_message,
                suggestions=suggestions[:4],  # Top concise suggestions
                checks=checks,
                limitations=limitations,
                has_baseline_comparison=has_baseline,
            )

        except Exception as e:
            logger.warning(f"Error in CaptureCoachService: {e}")
            return cls._build_corrupt_response(f"Capture evaluation error: {str(e)}")

    @staticmethod
    def _check_resolution(
        width: int, height: int
    ) -> Tuple[CaptureCoachCheckItem, Optional[Tuple[str, List[str]]], Optional[Tuple[str, List[str]]]]:
        p1 = None
        p2 = None
        if width < 150 or height < 150:
            status = "fail"
            score = 0.1
            message = f"Resolution is too low ({width}x{height}px). Minimum 300px required for reliable analysis."
            p1 = (
                message,
                ["Capture photo with higher camera resolution.", "Move closer without cropping the finding."],
            )
        elif width < 300 or height < 300:
            status = "warning"
            score = 0.6
            message = f"Moderate resolution ({width}x{height}px). Higher resolution (300px+) recommended."
            p2 = (
                message,
                ["Move slightly closer to the skin finding."],
            )
        else:
            status = "pass"
            score = 1.0
            message = f"Resolution is optimal ({width}x{height}px)."

        item = CaptureCoachCheckItem(
            category="resolution",
            status=status,
            score=score,
            message=message,
            details={"width": width, "height": height, "min_recommended": 300},
        )
        return item, p1, p2

    @staticmethod
    def _check_sharpness(
        gray: np.ndarray,
    ) -> Tuple[CaptureCoachCheckItem, Optional[Tuple[str, List[str]]], Optional[Tuple[str, List[str]]]]:
        p1 = None
        p2 = None
        laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())

        if laplacian_var < 50.0:
            status = "fail"
            score = round(min(1.0, max(0.0, laplacian_var / 50.0)), 2)
            message = f"Image appears blurry (sharpness score {laplacian_var:.1f} < 50)."
            p1 = (
                message,
                ["Hold phone steady or rest elbows on a stable surface.", "Tap the screen on the skin finding to lock focus."],
            )
        elif laplacian_var < 100.0:
            status = "warning"
            score = 0.7
            message = f"Slight blur detected (sharpness score {laplacian_var:.1f}). Focus is acceptable but recapturing may improve comparison."
            p2 = (
                message,
                ["Hold phone steady when pressing capture."],
            )
        else:
            status = "pass"
            score = 1.0
            message = f"Image sharpness is optimal (sharpness score {laplacian_var:.1f})."

        item = CaptureCoachCheckItem(
            category="sharpness",
            status=status,
            score=score,
            message=message,
            details={"laplacian_variance": round(laplacian_var, 1)},
        )
        return item, p1, p2

    @staticmethod
    def _check_lighting(
        gray: np.ndarray,
    ) -> Tuple[CaptureCoachCheckItem, Optional[Tuple[str, List[str]]], Optional[Tuple[str, List[str]]]]:
        p1 = None
        p2 = None
        mean_brightness = float(gray.mean())
        std_contrast = float(gray.std())

        # Glare detection: fraction of saturated white pixels
        saturated_pixels = float(np.sum(gray >= 252)) / float(gray.size)

        if mean_brightness < 35.0:
            status = "fail"
            score = round(max(0.0, mean_brightness / 35.0), 2)
            message = f"Lighting is too dark / underexposed (brightness: {mean_brightness:.1f})."
            p1 = (
                message,
                ["Turn on room lighting or use soft ambient light.", "Avoid casting shadow with the phone."],
            )
        elif mean_brightness > 225.0:
            status = "fail"
            score = round(max(0.0, (255.0 - mean_brightness) / 30.0), 2)
            message = f"Lighting is overexposed / too bright (brightness: {mean_brightness:.1f})."
            p1 = (
                message,
                ["Move away from direct harsh glare or reduce exposure."],
            )
        elif saturated_pixels > 0.12:
            status = "warning"
            score = 0.6
            message = f"Excessive glare or flash reflection detected ({saturated_pixels * 100:.1f}% saturated pixels)."
            p2 = (
                message,
                ["Tilt camera slightly to avoid direct flash reflection on skin."],
            )
        elif mean_brightness < 60.0 or mean_brightness > 200.0 or std_contrast < 15.0:
            status = "warning"
            score = 0.7
            message = f"Suboptimal lighting or contrast (brightness: {mean_brightness:.1f}, contrast std: {std_contrast:.1f})."
            p2 = (
                message,
                ["Use soft, even lighting across the entire skin area."],
            )
        else:
            status = "pass"
            score = 1.0
            message = f"Lighting and contrast appear optimal (brightness: {mean_brightness:.1f})."

        item = CaptureCoachCheckItem(
            category="lighting",
            status=status,
            score=score,
            message=message,
            details={
                "mean_brightness": round(mean_brightness, 1),
                "contrast_std": round(std_contrast, 1),
                "glare_fraction": round(saturated_pixels, 3),
            },
        )
        return item, p1, p2

    @staticmethod
    def _check_framing(
        gray: np.ndarray, width: int, height: int
    ) -> Tuple[CaptureCoachCheckItem, Optional[Tuple[str, List[str]]], Optional[Tuple[str, List[str]]]]:
        p2 = None
        p3 = None

        # Check border margins for extreme dark vignetting or edge obstructions
        margin_h = max(2, height // 12)
        margin_w = max(2, width // 12)

        top_mean = float(gray[:margin_h, :].mean())
        bottom_mean = float(gray[-margin_h:, :].mean())
        left_mean = float(gray[:, :margin_w].mean())
        right_mean = float(gray[:, -margin_w:].mean())
        center_mean = float(gray[margin_h:-margin_h, margin_w:-margin_w].mean())

        # If all 4 borders are completely black (< 10) compared to bright center (> 50), flag severe vignette/obstruction
        border_min = min(top_mean, bottom_mean, left_mean, right_mean)
        border_avg = (top_mean + bottom_mean + left_mean + right_mean) / 4.0
        if border_avg < 15.0 and center_mean > 60.0:
            status = "warning"
            score = 0.7
            message = "Possible edge obstruction or severe vignetting detected."
            p2 = (
                message,
                ["Ensure the camera lens is unobstructed and keep the finding centered."],
            )
        else:
            status = "pass"
            score = 1.0
            message = "Finding appears centered inside the viewfinder frame."
            p3 = (
                "Keep finding centered",
                ["Maintain the skin finding within the central framing guide."],
            )

        item = CaptureCoachCheckItem(
            category="framing",
            status=status,
            score=score,
            message=message,
            details={"center_brightness": round(center_mean, 1)},
        )
        return item, p2, p3

    @classmethod
    def _check_baseline_consistency(
        cls,
        img: np.ndarray,
        gray: np.ndarray,
        baseline_bytes: bytes,
    ) -> Tuple[Optional[CaptureCoachCheckItem], Optional[Tuple[str, List[str]]], Optional[Tuple[str, List[str]]]]:
        try:
            base_arr = np.frombuffer(baseline_bytes, np.uint8)
            base_img = cv2.imdecode(base_arr, cv2.IMREAD_COLOR)
            if base_img is None:
                return None, None, None

            base_gray = cv2.cvtColor(base_img, cv2.COLOR_BGR2GRAY)

            curr_lum = float(gray.mean())
            base_lum = float(base_gray.mean())
            lum_diff = abs(curr_lum - base_lum)

            h1, w1 = img.shape[:2]
            h2, w2 = base_img.shape[:2]
            dim_ratio = max(w1 / max(w2, 1), w2 / max(w1, 1))

            p2 = None
            p3 = None

            if lum_diff > 60.0:
                status = "warning"
                score = 0.65
                message = f"Lighting differs significantly from baseline photo (brightness delta: {lum_diff:.1f})."
                p2 = (
                    message,
                    ["Use lighting similar to your baseline photo for more consistent comparison."],
                )
            elif dim_ratio > 2.5:
                status = "warning"
                score = 0.7
                message = "Framing distance or image scale differs notably from baseline photo."
                p2 = (
                    message,
                    ["Try matching the distance and framing of the baseline photo."],
                )
            else:
                status = "pass"
                score = 0.95
                message = "Capture lighting and scale closely match baseline photo."
                p3 = (
                    "Capture consistency good",
                    ["Good match with baseline photo capture conditions."],
                )

            item = CaptureCoachCheckItem(
                category="baseline_consistency",
                status=status,
                score=score,
                message=message,
                details={
                    "luminance_delta": round(lum_diff, 1),
                    "dimension_ratio": round(dim_ratio, 2),
                },
            )
            return item, p2, p3

        except Exception as e:
            logger.warning(f"Baseline consistency check failed: {e}")
            return None, None, None

    @classmethod
    def _build_corrupt_response(cls, reason: str) -> CaptureCoachResponse:
        return CaptureCoachResponse(
            status="blocked",
            can_continue=False,
            quality_score=0.0,
            primary_message=f"Capture cannot be analyzed: {reason}",
            suggestions=["Retake the photo with a clear, supported image file."],
            checks=[
                CaptureCoachCheckItem(
                    category="integrity",
                    status="fail",
                    score=0.0,
                    message=reason,
                )
            ],
            limitations=[
                "Corrupt or empty images cannot be analyzed.",
                "Capture guidance evaluates photographic consistency only.",
            ],
            has_baseline_comparison=False,
        )
