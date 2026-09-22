import logging
from typing import Dict, Any, Tuple, Optional
import numpy as np
import cv2

logger = logging.getLogger(__name__)


class AlignmentService:
    """
    OpenCV feature-based image alignment engine using ORB keypoint detection
    and RANSAC homography estimation.
    Aligns a later capture image to an earlier baseline capture image space.
    """

    @staticmethod
    def align_image_pair(
        earlier_img: np.ndarray, latest_img: np.ndarray
    ) -> Dict[str, Any]:
        base_result = {
            "alignment_status": "failed",
            "alignment_score": 0.0,
            "match_count": 0,
            "inlier_count": 0,
            "inlier_ratio": 0.0,
            "alignment_method": "orb_ransac",
            "aligned_latest_image": None,
            "homography_matrix": None,
            "alignment_error_code": None,
        }

        if earlier_img is None or latest_img is None or earlier_img.size == 0 or latest_img.size == 0:
            return {**base_result, "alignment_error_code": "INVALID_IMAGE_INPUT"}

        try:
            h_earlier, w_earlier = earlier_img.shape[:2]
            h_latest, w_latest = latest_img.shape[:2]

            gray_earlier = cv2.cvtColor(earlier_img, cv2.COLOR_BGR2GRAY)
            gray_latest = cv2.cvtColor(latest_img, cv2.COLOR_BGR2GRAY)

            # Multi-scale ORB Feature Detector with 8 pyramid octaves
            orb = cv2.ORB_create(nfeatures=2000, scaleFactor=1.2, nlevels=8, edgeThreshold=15)
            kp_earlier, des_earlier = orb.detectAndCompute(gray_earlier, None)
            kp_latest, des_latest = orb.detectAndCompute(gray_latest, None)

            if des_earlier is None or des_latest is None or len(kp_earlier) < 4 or len(kp_latest) < 4:
                return {**base_result, "alignment_error_code": "INSUFFICIENT_KEYPOINTS"}

            # Feature Matching with Hamming Distance
            matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
            matches = matcher.match(des_earlier, des_latest)

            if not matches or len(matches) < 4:
                return {**base_result, "match_count": len(matches) if matches else 0, "alignment_error_code": "INSUFFICIENT_MATCHES"}

            # Sort matches by distance
            matches = sorted(matches, key=lambda x: x.distance)
            match_count = len(matches)

            # Extract location of good matches
            src_pts = np.float32([kp_earlier[m.queryIdx].pt for m in matches]).reshape(-1, 1, 2)
            dst_pts = np.float32([kp_latest[m.trainIdx].pt for m in matches]).reshape(-1, 1, 2)

            # 1. Primary: Estimate Planar Homography matrix with RANSAC
            H, mask = cv2.findHomography(dst_pts, src_pts, cv2.RANSAC, 5.0)
            inlier_count = int(np.sum(mask)) if mask is not None else 0
            inlier_ratio = float(inlier_count) / float(match_count) if match_count > 0 else 0.0
            alignment_method = "orb_homography_ransac"

            # 2. Secondary Fallback: Robust Affine Partial 2D (Rotation + Translation + Scale)
            if H is None or inlier_count < 4:
                M_affine, affine_mask = cv2.estimateAffinePartial2D(dst_pts, src_pts, method=cv2.RANSAC, ransacReprojThreshold=5.0)
                if M_affine is not None and affine_mask is not None and np.sum(affine_mask) >= 3:
                    inlier_count = int(np.sum(affine_mask))
                    inlier_ratio = float(inlier_count) / float(match_count)
                    alignment_method = "orb_affine_ransac"
                    # Convert 2x3 affine to 3x3 homography matrix for warping
                    H = np.vstack([M_affine, [0, 0, 1]])

            if H is None or inlier_count < 3:
                return {
                    **base_result,
                    "match_count": match_count,
                    "inlier_count": inlier_count,
                    "inlier_ratio": round(inlier_ratio, 3),
                    "alignment_error_code": "HOMOGRAPHY_INSUFFICIENT_INLIERS",
                }

            # Warp latest image to earlier image perspective
            aligned_latest = cv2.warpPerspective(latest_img, H, (w_earlier, h_earlier))

            # Calculate alignment score
            score = round(float(min(1.0, inlier_ratio * (min(inlier_count, 50) / 50.0))), 2)

            if score >= 0.40:
                align_status = "aligned"
            elif score >= 0.15:
                align_status = "partially_aligned"
            else:
                align_status = "failed"

            return {
                "alignment_status": align_status,
                "alignment_score": score,
                "match_count": match_count,
                "inlier_count": inlier_count,
                "inlier_ratio": round(inlier_ratio, 3),
                "alignment_method": alignment_method,
                "aligned_latest_image": aligned_latest,
                "homography_matrix": H,
                "alignment_error_code": None,
            }

        except Exception as e:
            logger.warning(f"Image alignment error: {e}")
            return {**base_result, "alignment_error_code": f"ALIGNMENT_EXCEPTION: {str(e)}"}
