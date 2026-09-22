import json
import logging
import math
from typing import Dict, Any, List, Optional, Tuple
import numpy as np
import cv2

from app.utils.segmentation_metrics import compute_mask_contrast_and_sharpness
from app.services.reliability_evaluator import (
    ReliabilityEvaluator,
    NON_DIAGNOSTIC_DISCLAIMER,
)

logger = logging.getLogger(__name__)


class MeasurementService:
    """
    Computes observable image-level quantitative metrics (Area, Shape, Color, Position, Boundary)
    and evaluates comparison reliability dynamically without medical diagnosis or clinical claims.
    """

    @staticmethod
    def calculate_metrics(
        earlier_img: np.ndarray,
        latest_img: np.ndarray,
        earlier_seg: Dict[str, Any],
        latest_seg: Dict[str, Any],
        alignment_res: Dict[str, Any],
        earlier_quality: Optional[Dict[str, Any]] = None,
        latest_quality: Optional[Dict[str, Any]] = None,
        segmentation_model_info: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:

        earlier_mask = earlier_seg.get("mask")
        latest_mask = latest_seg.get("mask")

        earlier_status = earlier_seg.get("status", "unavailable")
        latest_status = latest_seg.get("status", "unavailable")

        # Handle missing masks / unsegmented cases
        if (
            earlier_status != "segmented"
            or latest_status != "segmented"
            or earlier_mask is None
            or latest_mask is None
            or np.count_nonzero(earlier_mask) == 0
            or np.count_nonzero(latest_mask) == 0
        ):
            dummy_measurements = {
                "earlier_area": None,
                "latest_area": None,
                "area_change_percent": None,
                "color_metrics": None,
                "shape_metrics": None,
                "boundary_metrics": None,
                "position_metrics": None,
            }
            rel_res = ReliabilityEvaluator.evaluate(
                earlier_quality=earlier_quality,
                latest_quality=latest_quality,
                alignment_res=alignment_res,
                earlier_seg=earlier_seg,
                latest_seg=latest_seg,
                measurements=dummy_measurements,
                segmentation_model_info=segmentation_model_info,
            )
            return {
                "measurement_status": "unavailable",
                "reliability_status": rel_res.overall_reliability,
                "reliability_score": rel_res.reliability_score,
                "uncertainty_reasons": [u.message for u in rel_res.uncertainty_reasons],
                "uncertainty_reasons_structured": [u.to_dict() for u in rel_res.uncertainty_reasons],
                "affected_signals": rel_res.affected_signals,
                "limitations": rel_res.limitations,
                "reliability_details": rel_res.to_dict(),
                "earlier_area": None,
                "latest_area": None,
                "area_change_percent": None,
                "color_change_metrics": None,
                "shape_change_metrics": None,
                "boundary_change_metrics": None,
                "position_change_metrics": None,
                "observable_change_summary": None,
                "observable_metrics": json.dumps({
                    "reliability_details": rel_res.to_dict(),
                }),
                "non_diagnostic_disclaimer": NON_DIAGNOSTIC_DISCLAIMER,
            }

        # 1. Area Measurements (Pixels)
        earlier_area = float(np.count_nonzero(earlier_mask))
        latest_area = float(np.count_nonzero(latest_mask))

        if earlier_area > 0:
            area_change_pct = round(((latest_area - earlier_area) / earlier_area) * 100.0, 2)
        else:
            area_change_pct = None

        # 2. Position Measurements (Centroid Shift)
        c_earlier = earlier_seg.get("centroid") or (0.0, 0.0)
        c_latest = latest_seg.get("centroid") or (0.0, 0.0)

        dx = round(c_latest[0] - c_earlier[0], 2)
        dy = round(c_latest[1] - c_earlier[1], 2)
        dist_shift = round(math.sqrt(dx * dx + dy * dy), 2)

        position_metrics = {
            "earlier_centroid": [round(c_earlier[0], 1), round(c_earlier[1], 1)],
            "latest_centroid": [round(c_latest[0], 1), round(c_latest[1], 1)],
            "centroid_shift_dx_dy": [dx, dy],
            "displacement_px": dist_shift,
        }

        # 3. Shape & Boundary Measurements
        cnt_e, _ = cv2.findContours(earlier_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cnt_l, _ = cv2.findContours(latest_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        shape_diff = None
        perim_e = round(float(earlier_seg.get("perimeter") or 0.0), 1)
        perim_l = round(float(latest_seg.get("perimeter") or 0.0), 1)

        if cnt_e and cnt_l:
            try:
                shape_diff = round(float(cv2.matchShapes(cnt_e[0], cnt_l[0], cv2.CONTOURS_MATCH_I1, 0)), 3)
            except Exception:
                shape_diff = None

        # Calculate IoU (Intersection over Union) boundary overlap
        intersection = np.logical_and(earlier_mask > 0, latest_mask > 0)
        union = np.logical_or(earlier_mask > 0, latest_mask > 0)
        iou_score = round(float(np.sum(intersection)) / float(np.sum(union)), 3) if np.sum(union) > 0 else 0.0

        shape_metrics = {
            "hu_moments_match_score": shape_diff,
            "earlier_perimeter_px": perim_e,
            "latest_perimeter_px": perim_l,
        }

        boundary_metrics = {
            "mask_iou_overlap": iou_score,
            "boundary_variance": "detected" if iou_score < 0.85 else "stable",
        }

        # 4. Color Distribution Measurements (BGR / LAB Means)
        color_e = cv2.mean(earlier_img, mask=earlier_mask)[:3]
        color_l = cv2.mean(latest_img, mask=latest_mask)[:3]

        b_diff = round(color_l[0] - color_e[0], 1)
        g_diff = round(color_l[1] - color_e[1], 1)
        r_diff = round(color_l[2] - color_e[2], 1)
        color_dist = round(math.sqrt(b_diff**2 + g_diff**2 + r_diff**2), 1)

        # Check for lighting / overall exposure shift
        mean_bright_e = float(cv2.cvtColor(earlier_img, cv2.COLOR_BGR2GRAY).mean())
        mean_bright_l = float(cv2.cvtColor(latest_img, cv2.COLOR_BGR2GRAY).mean())
        bright_diff = abs(mean_bright_l - mean_bright_e)

        color_metrics = {
            "earlier_mean_bgr": [round(c, 1) for c in color_e],
            "latest_mean_bgr": [round(c, 1) for c in color_l],
            "color_bgr_delta": [b_diff, g_diff, r_diff],
            "overall_color_distance": color_dist,
            "lighting_brightness_delta": round(bright_diff, 1),
        }

        # 5. Deterministic Reliability and Uncertainty Evaluation
        measurements_bundle = {
            "earlier_area": earlier_area,
            "latest_area": latest_area,
            "area_change_percent": area_change_pct,
            "color_metrics": color_metrics,
            "shape_metrics": shape_metrics,
            "boundary_metrics": boundary_metrics,
            "position_metrics": position_metrics,
        }

        rel_result = ReliabilityEvaluator.evaluate(
            earlier_quality=earlier_quality,
            latest_quality=latest_quality,
            alignment_res=alignment_res,
            earlier_seg=earlier_seg,
            latest_seg=latest_seg,
            measurements=measurements_bundle,
            segmentation_model_info=segmentation_model_info,
        )

        # Neutral non-clinical summary
        change_desc = []
        if area_change_pct is not None:
            change_desc.append(f"Area delta: {area_change_pct:+.1f}%")
        if color_dist > 15.0:
            change_desc.append("Color variation detected")
        if iou_score < 0.80:
            change_desc.append("Boundary shape difference observed")

        summary_text = "; ".join(change_desc) if change_desc else "No major observable change detected."

        observable_all = {
            "area_change_percent": area_change_pct,
            "position": position_metrics,
            "shape": shape_metrics,
            "boundary": boundary_metrics,
            "color": color_metrics,
            "reliability_details": rel_result.to_dict(),
        }

        # Map legacy reliability status strings for backward compatibility if needed:
        # high -> reliable, moderate -> needs_review, low/insufficient -> unreliable/unavailable
        legacy_status_map = {
            "high": "reliable",
            "moderate": "needs_review",
            "low": "unreliable",
            "insufficient": "unavailable",
        }
        legacy_rel_status = legacy_status_map.get(rel_result.overall_reliability, rel_result.overall_reliability)

        return {
            "measurement_status": "measured",
            "reliability_status": legacy_rel_status,
            "overall_reliability": rel_result.overall_reliability,
            "reliability_score": rel_result.reliability_score,
            "uncertainty_reasons": [u.message for u in rel_result.uncertainty_reasons],
            "uncertainty_reasons_structured": [u.to_dict() for u in rel_result.uncertainty_reasons],
            "affected_signals": rel_result.affected_signals,
            "limitations": rel_result.limitations,
            "reliability_details": rel_result.to_dict(),
            "earlier_area": earlier_area,
            "latest_area": latest_area,
            "area_change_percent": area_change_pct,
            "color_change_metrics": json.dumps(color_metrics),
            "shape_change_metrics": json.dumps(shape_metrics),
            "boundary_change_metrics": json.dumps(boundary_metrics),
            "position_change_metrics": json.dumps(position_metrics),
            "observable_change_summary": summary_text,
            "observable_metrics": json.dumps(observable_all),
            "non_diagnostic_disclaimer": NON_DIAGNOSTIC_DISCLAIMER,
        }
