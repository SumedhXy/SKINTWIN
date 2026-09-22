import json
import logging
from datetime import datetime, timezone
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any
import numpy as np
import cv2

logger = logging.getLogger(__name__)


@dataclass
class ImageQualityResult:
    quality_status: str           # "acceptable", "needs_review", "unacceptable", "not_evaluated"
    quality_score: Optional[float] # 0.0 to 1.0
    blur_status: Optional[str]     # "pass", "warning", "fail", "unknown"
    lighting_status: Optional[str] # "pass", "warning", "fail", "unknown"
    resolution_status: Optional[str] # "pass", "warning", "fail", "unknown"
    framing_status: Optional[str]  # "unknown", "pass", "warning", "fail"
    comparison_eligible: bool
    quality_details: Dict[str, Any]
    quality_analyzed_at: datetime


class ImageQualityService:
    """
    Deterministic OpenCV image quality assessment system.
    Evaluates image dimensions, blur (Laplacian variance), and brightness/lighting.
    Does NOT attempt disease diagnosis, risk prediction, or clinical confidence scoring.
    """

    @staticmethod
    def evaluate(file_bytes: bytes) -> ImageQualityResult:
        now = datetime.now(timezone.utc)

        try:
            np_arr = np.frombuffer(file_bytes, np.uint8)
            img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

            if img is None:
                return ImageQualityResult(
                    quality_status="unacceptable",
                    quality_score=0.0,
                    blur_status="unknown",
                    lighting_status="unknown",
                    resolution_status="unknown",
                    framing_status="unknown",
                    comparison_eligible=False,
                    quality_details={"reason": "Corrupt or unreadable image bytes."},
                    quality_analyzed_at=now,
                )

            height, width = img.shape[:2]
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            # 1. Resolution Check
            if width < 150 or height < 150:
                res_status = "fail"
                res_score = 0.2
                res_reason = f"Low image dimensions: {width}x{height}px (min 300px recommended)."
            elif width < 300 or height < 300:
                res_status = "warning"
                res_score = 0.6
                res_reason = f"Moderate image dimensions: {width}x{height}px."
            else:
                res_status = "pass"
                res_score = 1.0
                res_reason = f"Sufficient image dimensions: {width}x{height}px."

            # 2. Blur Check (Laplacian Variance)
            laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
            if laplacian_var < 50.0:
                blur_status = "fail"
                blur_score = min(1.0, laplacian_var / 50.0)
                blur_reason = f"Image focus is blurry (Laplacian variance: {laplacian_var:.1f})."
            elif laplacian_var < 100.0:
                blur_status = "warning"
                blur_score = 0.7
                blur_reason = f"Slight blur detected (Laplacian variance: {laplacian_var:.1f})."
            else:
                blur_status = "pass"
                blur_score = 1.0
                blur_reason = f"Image focus is sharp (Laplacian variance: {laplacian_var:.1f})."

            # 3. Brightness / Lighting Check
            mean_brightness = float(gray.mean())
            std_contrast = float(gray.std())

            if mean_brightness < 40.0:
                light_status = "fail"
                light_score = max(0.0, mean_brightness / 40.0)
                light_reason = f"Underexposed / too dark (brightness: {mean_brightness:.1f})."
            elif mean_brightness > 220.0:
                light_status = "fail"
                light_score = max(0.0, (255.0 - mean_brightness) / 35.0)
                light_reason = f"Overexposed / too bright (brightness: {mean_brightness:.1f})."
            elif mean_brightness < 60.0 or mean_brightness > 200.0 or std_contrast < 15.0:
                light_status = "warning"
                light_score = 0.7
                light_reason = f"Suboptimal lighting or contrast (brightness: {mean_brightness:.1f}, contrast std: {std_contrast:.1f})."
            else:
                light_status = "pass"
                light_score = 1.0
                light_reason = f"Optimal lighting (brightness: {mean_brightness:.1f})."

            # 4. Framing / Visibility Check
            framing_status = "unknown"
            frame_reason = "Generic framing (automated lesion segmentation requires ML model)."

            # Calculate overall score and status
            overall_score = round(float((res_score * 0.3) + (blur_score * 0.4) + (light_score * 0.3)), 2)

            if res_status == "fail" or blur_status == "fail" or light_status == "fail":
                quality_status = "unacceptable"
                comparison_eligible = False
            elif res_status == "warning" or blur_status == "warning" or light_status == "warning":
                quality_status = "needs_review"
                comparison_eligible = (blur_status == "pass" and res_status == "pass")
            else:
                quality_status = "acceptable"
                comparison_eligible = True

            details = {
                "resolution": {
                    "status": res_status,
                    "score": round(res_score, 2),
                    "reason": res_reason,
                    "width": width,
                    "height": height,
                },
                "blur": {
                    "status": blur_status,
                    "score": round(blur_score, 2),
                    "reason": blur_reason,
                    "laplacian_variance": round(laplacian_var, 2),
                },
                "lighting": {
                    "status": light_status,
                    "score": round(light_score, 2),
                    "reason": light_reason,
                    "mean_brightness": round(mean_brightness, 2),
                    "contrast_std": round(std_contrast, 2),
                },
                "framing": {
                    "status": framing_status,
                    "reason": frame_reason,
                },
            }

            return ImageQualityResult(
                quality_status=quality_status,
                quality_score=overall_score,
                blur_status=blur_status,
                lighting_status=light_status,
                resolution_status=res_status,
                framing_status=framing_status,
                comparison_eligible=comparison_eligible,
                quality_details=details,
                quality_analyzed_at=now,
            )

        except Exception as e:
            logger.warning(f"Image quality evaluation error: {e}")
            return ImageQualityResult(
                quality_status="not_evaluated",
                quality_score=None,
                blur_status="unknown",
                lighting_status="unknown",
                resolution_status="unknown",
                framing_status="unknown",
                comparison_eligible=False,
                quality_details={"reason": f"Quality evaluation error: {str(e)}"},
                quality_analyzed_at=now,
            )
