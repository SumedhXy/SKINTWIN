import os
import logging
from pathlib import Path
from typing import Dict, Any, Optional, Tuple, List
import numpy as np
import cv2

logger = logging.getLogger(__name__)


def compute_dice_coefficient(mask1: np.ndarray, mask2: np.ndarray) -> float:
    """
    Compute Dice Similarity Coefficient (DSC) between two binary segmentation masks.
    Formula: 2 * |A ∩ B| / (|A| + |B|)
    Returns float between 0.0 and 1.0.
    """
    if mask1 is None or mask2 is None:
        return 0.0

    m1_bool = mask1 > 0
    m2_bool = mask2 > 0

    intersection = np.sum(m1_bool & m2_bool)
    total_voxels = np.sum(m1_bool) + np.sum(m2_bool)

    if total_voxels == 0:
        return 1.0 if np.sum(m1_bool) == np.sum(m2_bool) else 0.0

    dice = (2.0 * intersection) / float(total_voxels)
    return float(round(dice, 4))


def compute_iou(mask1: np.ndarray, mask2: np.ndarray) -> float:
    """
    Compute Intersection over Union (IoU / Jaccard Index) between two binary masks.
    Formula: |A ∩ B| / |A ∪ B|
    Returns float between 0.0 and 1.0.
    """
    if mask1 is None or mask2 is None:
        return 0.0

    m1_bool = mask1 > 0
    m2_bool = mask2 > 0

    intersection = np.sum(m1_bool & m2_bool)
    union = np.sum(m1_bool | m2_bool)

    if union == 0:
        return 1.0 if np.sum(m1_bool) == np.sum(m2_bool) else 0.0

    iou = intersection / float(union)
    return float(round(iou, 4))


def compute_mask_contrast_and_sharpness(
    image: np.ndarray, mask: np.ndarray
) -> Dict[str, float]:
    """
    Dynamically calculate ROI contrast ratio and boundary edge sharpness.
    Used for computing genuine, non-hardcoded localization confidence.
    """
    if image is None or mask is None or np.count_nonzero(mask) == 0:
        return {"contrast_ratio": 0.0, "boundary_sharpness": 0.0}

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image
    mask_bool = mask > 0

    roi_mean = float(np.mean(gray[mask_bool]))
    background_mean = float(np.mean(gray[~mask_bool])) if np.count_nonzero(~mask_bool) > 0 else roi_mean

    # Contrast ratio between lesion ROI and surrounding skin
    denom = roi_mean + background_mean
    contrast_ratio = abs(roi_mean - background_mean) / denom if denom > 0 else 0.0

    # Boundary sharpness using Sobel gradient along mask border
    kernel = np.ones((3, 3), np.uint8)
    eroded = cv2.erode(mask.astype(np.uint8), kernel, iterations=1)
    boundary = (mask.astype(np.uint8) - eroded) > 0

    if np.count_nonzero(boundary) > 0:
        sobel_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
        sobel_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
        grad_mag = np.sqrt(sobel_x**2 + sobel_y**2)
        boundary_sharpness = float(np.mean(grad_mag[boundary])) / 255.0
    else:
        boundary_sharpness = 0.0

    return {
        "contrast_ratio": float(round(contrast_ratio, 4)),
        "boundary_sharpness": float(round(boundary_sharpness, 4)),
    }


def save_mask_visualization(
    image: np.ndarray,
    mask: np.ndarray,
    output_path: str,
    bbox: Optional[List[int]] = None,
) -> bool:
    """
    Generate and save a visual overlay of the segmentation mask and ROI prompt box
    for inspection and quality validation.
    """
    try:
        if image is None or mask is None:
            return False

        vis = image.copy()
        if len(vis.shape) == 2:
            vis = cv2.cvtColor(vis, cv2.COLOR_GRAY2BGR)

        # Green overlay on mask region
        color_mask = np.zeros_like(vis)
        color_mask[mask > 0] = [0, 255, 0]  # Green in BGR
        vis = cv2.addWeighted(vis, 0.7, color_mask, 0.3, 0)

        # Draw red contours
        contours, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cv2.drawContours(vis, contours, -1, (0, 0, 255), 2)

        # Draw ROI bounding box if provided
        if bbox and len(bbox) == 4:
            x1, y1, x2, y2 = bbox
            cv2.rectangle(vis, (int(x1), int(y1)), (int(x2), int(y2)), (255, 0, 0), 2)

        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(output_path, vis)
        return True
    except Exception as e:
        logger.error(f"Failed to save mask visualization to '{output_path}': {e}")
        return False


def log_segmentation_failure(image_id: str, reason: str, details: Dict[str, Any]) -> None:
    """Log segmentation pipeline failures for offline failure-case audit and retraining."""
    log_dir = Path("dataset/failures")
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "failure_cases.log"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"[{image_id}] REASON: {reason} | DETAILS: {details}\n")
    logger.warning(f"Segmentation Failure Logged [{image_id}]: {reason}")
