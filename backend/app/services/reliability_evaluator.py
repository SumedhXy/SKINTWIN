"""
SkinTwin - Comparison Reliability & Uncertainty Evaluation System
=================================================================
Pure deterministic engineering assessment of image comparison quality,
feature alignment, segmentation boundary stability, and measurement confidence.

CRITICAL BOUNDARY:
This module evaluates Computer Vision engineering characteristics ONLY.
It NEVER generates medical diagnostic confidence, cancer risk scores,
pathology certainty, or clinical conclusions.
"""

from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field, asdict


NON_DIAGNOSTIC_DISCLAIMER = (
    "SkinTwin describes observable image differences only. "
    "It does not diagnose medical conditions or determine their clinical significance."
)
NON_DIAGNOSTIC_SAFETY_DISCLAIMER = NON_DIAGNOSTIC_DISCLAIMER

PROFESSIONAL_CARE_GUIDANCE = (
    "If you notice concerning changes or have health concerns, "
    "consider consulting a qualified healthcare professional."
)


@dataclass
class UncertaintyReason:
    category: str  # image_quality, lighting, blur, framing, alignment, segmentation, measurement, missing_data, capture_conditions
    severity: str  # low, moderate, high
    message: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "category": self.category,
            "severity": self.severity,
            "message": self.message,
        }


@dataclass
class ComponentStatus:
    name: str
    status: str  # image_quality: acceptable/limited/poor/unavailable; alignment/seg/meas: high/moderate/low/unavailable
    score: Optional[float]
    explanation: str
    limitation: Optional[str] = None
    is_fallback: bool = False

    def to_dict(self) -> Dict[str, Any]:
        res = {
            "name": self.name,
            "status": self.status,
            "score": self.score,
            "explanation": self.explanation,
            "limitation": self.limitation,
        }
        if self.is_fallback:
            res["is_fallback"] = True
        return res


@dataclass
class SignalReliability:
    name: str  # Area, Shape, Color, Position, Segmentation Overlap
    reliability: str  # high, moderate, low, unavailable, insufficient
    uncertainty: bool
    limitation: Optional[str]
    interpretation: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "reliability": self.reliability,
            "uncertainty": self.uncertainty,
            "limitation": self.limitation,
            "interpretation": self.interpretation,
        }


@dataclass
class ReliabilityEvaluationResult:
    overall_reliability: str  # high, moderate, low, insufficient
    reliability_score: float  # 0.0 to 1.0 (engineering score only)
    uncertainty_present: bool
    uncertainty_reasons: List[UncertaintyReason]
    affected_signals: List[str]
    limitations: List[str]
    component_statuses: Dict[str, ComponentStatus]
    signal_reliabilities: Dict[str, SignalReliability]
    disclaimer: str = NON_DIAGNOSTIC_DISCLAIMER

    def to_dict(self) -> Dict[str, Any]:
        return {
            "overall_reliability": self.overall_reliability,
            "reliability_score": self.reliability_score,
            "uncertainty_present": self.uncertainty_present,
            "uncertainty_reasons": [u.to_dict() for u in self.uncertainty_reasons],
            "affected_signals": self.affected_signals,
            "limitations": self.limitations,
            "component_statuses": {k: v.to_dict() for k, v in self.component_statuses.items()},
            "signal_reliabilities": {k: v.to_dict() for k, v in self.signal_reliabilities.items()},
            "disclaimer": self.disclaimer,
        }


class ReliabilityEvaluator:
    """
    Deterministic rule-based evaluator for comparison engineering reliability and uncertainty.
    """

    @staticmethod
    def evaluate(
        earlier_quality: Optional[Dict[str, Any]],
        latest_quality: Optional[Dict[str, Any]],
        alignment_res: Dict[str, Any],
        earlier_seg: Dict[str, Any],
        latest_seg: Dict[str, Any],
        measurements: Dict[str, Any],
        segmentation_model_info: Optional[Dict[str, Any]] = None,
    ) -> ReliabilityEvaluationResult:
        uncertainty_reasons: List[UncertaintyReason] = []
        affected_signals: List[str] = []
        limitations: List[str] = [
            "The comparison describes image differences, not medical significance."
        ]

        # -------------------------------------------------------------
        # A. IMAGE QUALITY EVALUATION
        # -------------------------------------------------------------
        img_qual_status, img_qual_score, img_qual_exp, img_qual_lim = (
            ReliabilityEvaluator._eval_image_quality(
                earlier_quality, latest_quality, measurements, uncertainty_reasons, affected_signals, limitations
            )
        )
        comp_image_quality = ComponentStatus(
            name="Image Quality",
            status=img_qual_status,
            score=img_qual_score,
            explanation=img_qual_exp,
            limitation=img_qual_lim,
        )

        # -------------------------------------------------------------
        # B. ALIGNMENT RELIABILITY EVALUATION
        # -------------------------------------------------------------
        align_rel_status, align_score, align_exp, align_lim = (
            ReliabilityEvaluator._eval_alignment(
                alignment_res, uncertainty_reasons, affected_signals, limitations
            )
        )
        comp_alignment = ComponentStatus(
            name="Alignment",
            status=align_rel_status,
            score=align_score,
            explanation=align_exp,
            limitation=align_lim,
        )

        # -------------------------------------------------------------
        # C. SEGMENTATION RELIABILITY EVALUATION
        # -------------------------------------------------------------
        seg_rel_status, seg_score, seg_exp, seg_lim, is_fallback = (
            ReliabilityEvaluator._eval_segmentation(
                earlier_seg, latest_seg, segmentation_model_info, uncertainty_reasons, affected_signals, limitations
            )
        )
        comp_segmentation = ComponentStatus(
            name="Segmentation",
            status=seg_rel_status,
            score=seg_score,
            explanation=seg_exp,
            limitation=seg_lim,
            is_fallback=is_fallback,
        )

        # -------------------------------------------------------------
        # D. MEASUREMENT RELIABILITY EVALUATION
        # -------------------------------------------------------------
        meas_rel_status, meas_score, meas_exp, meas_lim = (
            ReliabilityEvaluator._eval_measurements(
                measurements, earlier_seg, latest_seg, alignment_res, uncertainty_reasons, affected_signals, limitations
            )
        )
        comp_measurements = ComponentStatus(
            name="Measurements",
            status=meas_rel_status,
            score=meas_score,
            explanation=meas_exp,
            limitation=meas_lim,
        )

        component_statuses = {
            "image_quality": comp_image_quality,
            "alignment": comp_alignment,
            "segmentation": comp_segmentation,
            "measurement": comp_measurements,
        }

        # -------------------------------------------------------------
        # E. SIGNAL-SPECIFIC RELIABILITY
        # -------------------------------------------------------------
        signal_reliabilities = ReliabilityEvaluator._eval_signals(
            measurements=measurements,
            img_qual_status=img_qual_status,
            align_rel_status=align_rel_status,
            seg_rel_status=seg_rel_status,
            is_fallback=is_fallback,
            uncertainty_reasons=uncertainty_reasons,
        )

        # -------------------------------------------------------------
        # F. OVERALL COMPARISON RELIABILITY (Weakest-Link Principle)
        # -------------------------------------------------------------
        # Deterministic Rules:
        # - If segmentation is unavailable/failed or alignment failed or masks missing -> 'insufficient'
        # - If image quality is poor or alignment is low or segmentation is low -> 'low'
        # - If any component is limited/moderate or uncertainty present -> 'moderate'
        # - If all components are acceptable/high and no critical uncertainty -> 'high'
        
        has_critical_failure = (
            seg_rel_status == "unavailable"
            or align_rel_status == "unavailable"
            or meas_rel_status == "unavailable"
            or (earlier_seg.get("mask") is None or latest_seg.get("mask") is None)
        )

        if has_critical_failure:
            overall_rel = "insufficient"
            rel_score = 0.0
        elif (
            img_qual_status == "poor"
            or align_rel_status == "low"
            or seg_rel_status == "low"
            or meas_rel_status == "low"
        ):
            overall_rel = "low"
            rel_score = min(0.45, round((align_score + seg_score + meas_score + (img_qual_score or 0.5)) / 4.0, 2))
        elif (
            img_qual_status == "limited"
            or align_rel_status == "moderate"
            or seg_rel_status == "moderate"
            or meas_rel_status == "moderate"
            or is_fallback
            or len(uncertainty_reasons) > 0
        ):
            overall_rel = "moderate"
            raw_score = (align_score + seg_score + meas_score + (img_qual_score or 0.8)) / 4.0
            rel_score = round(max(0.46, min(0.79, raw_score * (0.85 if uncertainty_reasons else 1.0))), 2)
        else:
            overall_rel = "high"
            raw_score = (align_score + seg_score + meas_score + (img_qual_score or 1.0)) / 4.0
            rel_score = round(max(0.80, min(1.0, raw_score)), 2)

        # Remove duplicate affected signals while preserving order
        unique_affected = list(dict.fromkeys(affected_signals))
        # Remove duplicate limitations
        unique_limitations = list(dict.fromkeys(limitations))

        uncertainty_present = len(uncertainty_reasons) > 0 or overall_rel in ["low", "insufficient", "moderate"]

        return ReliabilityEvaluationResult(
            overall_reliability=overall_rel,
            reliability_score=rel_score,
            uncertainty_present=uncertainty_present,
            uncertainty_reasons=uncertainty_reasons,
            affected_signals=unique_affected,
            limitations=unique_limitations,
            component_statuses=component_statuses,
            signal_reliabilities=signal_reliabilities,
            disclaimer=NON_DIAGNOSTIC_DISCLAIMER,
        )

    # -------------------------------------------------------------------------
    # SUB-EVALUATORS
    # -------------------------------------------------------------------------

    @staticmethod
    def _eval_image_quality(
        earlier_q: Optional[Dict[str, Any]],
        latest_q: Optional[Dict[str, Any]],
        measurements: Dict[str, Any],
        uncertainty_reasons: List[UncertaintyReason],
        affected_signals: List[str],
        limitations: List[str],
    ) -> tuple[str, Optional[float], str, Optional[str]]:
        if not earlier_q and not latest_q:
            return "unavailable", None, "Image quality assessment unavailable.", None

        e_status = (earlier_q or {}).get("quality_status", "acceptable")

        l_status = (latest_q or {}).get("quality_status", "acceptable")
        e_score = (earlier_q or {}).get("quality_score", 1.0) or 1.0
        l_score = (latest_q or {}).get("quality_score", 1.0) or 1.0
        avg_score = round((e_score + l_score) / 2.0, 2)

        # Check blur
        e_blur = (earlier_q or {}).get("blur_status")
        l_blur = (latest_q or {}).get("blur_status")
        if e_blur == "fail" or l_blur == "fail":
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="blur",
                    severity="high",
                    message="Significant blur in one or both captures affects boundary precision and sharpness.",
                )
            )
            affected_signals.extend(["shape", "area", "overlap"])
            limitations.append("Blurry captures reduce boundary detection accuracy.")
        elif e_blur == "warning" or l_blur == "warning":
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="blur",
                    severity="moderate",
                    message="Moderate blur detected in images may cause minor measurement variation.",
                )
            )
            affected_signals.extend(["shape", "overlap"])

        # Check lighting / exposure difference
        color_metrics = measurements.get("color_metrics") or {}
        bright_delta = color_metrics.get("lighting_brightness_delta", 0.0)
        e_light = (earlier_q or {}).get("lighting_status")
        l_light = (latest_q or {}).get("lighting_status")

        if bright_delta > 35.0 or e_light == "fail" or l_light == "fail":
            severity = "high" if bright_delta > 50.0 or e_light == "fail" or l_light == "fail" else "moderate"
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="lighting",
                    severity=severity,
                    message=f"Lighting shift between captures (brightness delta: {bright_delta:.1f}) affects color consistency.",
                )
            )
            affected_signals.append("color")
            limitations.append("Different lighting conditions directly influence color and tone measurements.")
        elif bright_delta > 20.0 or e_light == "warning" or l_light == "warning":
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="lighting",
                    severity="low",
                    message=f"Minor lighting difference between captures (brightness delta: {bright_delta:.1f}).",
                )
            )
            affected_signals.append("color")

        # Determine overall quality status
        if e_status == "unacceptable" or l_status == "unacceptable" or e_blur == "fail" or l_blur == "fail":
            return (
                "poor",
                avg_score,
                "Image quality is poor due to blur, low lighting, or resolution constraints.",
                "Poor image quality severely reduces comparison reliability.",
            )
        elif e_status == "needs_review" or l_status == "needs_review" or bright_delta > 25.0 or e_blur == "warning" or l_blur == "warning":
            return (
                "limited",
                avg_score,
                "Image quality is acceptable with minor lighting or focus variations.",
                "Variations in capture angle or lighting may introduce minor measurement noise.",
            )
        else:
            return (
                "acceptable",
                avg_score,
                "Image quality, resolution, and sharpness are satisfactory for comparison.",
                None,
            )

    @staticmethod
    def _eval_alignment(
        alignment_res: Dict[str, Any],
        uncertainty_reasons: List[UncertaintyReason],
        affected_signals: List[str],
        limitations: List[str],
    ) -> tuple[str, float, str, Optional[str]]:
        align_status = alignment_res.get("alignment_status", "unavailable")
        align_score = float(alignment_res.get("alignment_score", 0.0) or 0.0)
        inlier_ratio = float(alignment_res.get("inlier_ratio", 0.0) or 0.0)
        error_code = alignment_res.get("alignment_error_code")

        if align_status == "failed" or align_status == "unavailable":
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="alignment",
                    severity="high",
                    message=f"Feature alignment failed ({error_code or 'Insufficient matching keypoints'}). Position and overlap cannot be reliably determined.",
                )
            )
            affected_signals.extend(["position", "overlap", "shape"])
            limitations.append("Images could not be geometrically registered to a common frame.")
            return "unavailable" if align_status == "unavailable" else "low", align_score, "Image alignment failed.", "Perspective and position comparisons are unavailable."

        if align_status == "partially_aligned" or align_score < 0.50 or inlier_ratio < 0.40:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="alignment",
                    severity="moderate",
                    message="Images are partially aligned with limited keypoint inliers. Slight perspective shifts may affect shape and position.",
                )
            )
            affected_signals.extend(["position", "shape", "overlap"])
            limitations.append("Partial alignment may introduce slight displacement or geometric distortion.")
            return "moderate", align_score, "Partial feature alignment achieved.", "Slight framing or angle differences present."

        return "high", align_score, "Robust feature alignment achieved with verified homography.", None

    @staticmethod
    def _eval_segmentation(
        earlier_seg: Dict[str, Any],
        latest_seg: Dict[str, Any],
        model_info: Optional[Dict[str, Any]],
        uncertainty_reasons: List[UncertaintyReason],
        affected_signals: List[str],
        limitations: List[str],
    ) -> tuple[str, float, str, Optional[str], bool]:
        e_status = earlier_seg.get("status", "unavailable")
        l_status = latest_seg.get("status", "unavailable")
        e_mask = earlier_seg.get("mask")
        l_mask = latest_seg.get("mask")
        e_conf_val = earlier_seg.get("confidence")
        l_conf_val = latest_seg.get("confidence")
        e_conf = float(e_conf_val if e_conf_val is not None else (0.90 if e_mask is not None else 0.0))
        l_conf = float(l_conf_val if l_conf_val is not None else (0.90 if l_mask is not None else 0.0))
        avg_conf = round((e_conf + l_conf) / 2.0, 2)


        model_name = (model_info or {}).get("model_name", "medsam_vit_b")
        is_fallback = model_name == "fallback_cv" or (model_info or {}).get("fallback_used", False)

        if e_status != "segmented" or l_status != "segmented" or e_mask is None or l_mask is None:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="segmentation",
                    severity="high",
                    message="Region segmentation was unsuccessful on one or both captures.",
                )
            )
            affected_signals.extend(["area", "shape", "overlap", "color", "position"])
            limitations.append("Region boundaries could not be isolated.")
            return "unavailable", 0.0, "Segmentation failed or unavailable.", "Area, shape, and boundary measurements cannot be calculated.", is_fallback

        if is_fallback:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="segmentation",
                    severity="moderate",
                    message="Fallback computer-vision segmentation was used. Boundary contours have higher variance than neural MedSAM models.",
                )
            )
            affected_signals.extend(["shape", "area", "overlap"])
            limitations.append("Fallback segmentation uses color/contrast heuristics rather than neural vision embeddings.")
            return "moderate", avg_conf, "Fallback CV segmentation applied.", "Contour precision is subject to contrast boundaries.", True

        if avg_conf < 0.70:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="segmentation",
                    severity="moderate",
                    message="Segmentation localization confidence is moderate. Boundaries may contain minor noise.",
                )
            )
            affected_signals.extend(["shape", "overlap"])
            limitations.append("Lower segmentation confidence indicates subtle edge ambiguity.")
            return "moderate", avg_conf, "MedSAM segmentation completed with moderate confidence.", "Subtle edge ambiguity may exist.", False

        return "high", avg_conf, "MedSAM neural segmentation successfully identified region boundaries.", None, False

    @staticmethod
    def _eval_measurements(
        measurements: Dict[str, Any],
        earlier_seg: Dict[str, Any],
        latest_seg: Dict[str, Any],
        alignment_res: Dict[str, Any],
        uncertainty_reasons: List[UncertaintyReason],
        affected_signals: List[str],
        limitations: List[str],
    ) -> tuple[str, float, str, Optional[str]]:
        earlier_area = measurements.get("earlier_area")
        latest_area = measurements.get("latest_area")
        boundary_metrics = measurements.get("boundary_metrics") or {}
        iou = boundary_metrics.get("mask_iou_overlap", 0.0)

        if earlier_area is None or latest_area is None:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="missing_data",
                    severity="high",
                    message="Area or boundary measurements could not be extracted.",
                )
            )
            return "unavailable", 0.0, "Measurements unavailable.", "Required measurement data is missing."

        if iou < 0.20:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="measurement",
                    severity="high",
                    message=f"Very low mask overlap ({iou * 100:.1f}% IoU) suggests misalignment or major boundary differences.",
                )
            )
            affected_signals.extend(["overlap", "shape", "position"])
            limitations.append("Low overlap significantly reduces boundary comparison certainty.")
            return "low", 0.3, "Measurements extracted but exhibit low boundary overlap.", "Low overlap limits comparative boundary precision."

        if iou < 0.60:
            uncertainty_reasons.append(
                UncertaintyReason(
                    category="measurement",
                    severity="moderate",
                    message=f"Moderate mask overlap ({iou * 100:.1f}% IoU). Boundary differences should be interpreted with caution.",
                )
            )
            affected_signals.append("overlap")
            return "moderate", 0.7, "Measurements extracted with moderate boundary overlap.", "Boundary differences should be interpreted with capture conditions in mind."

        return "high", 1.0, "All observable quantitative measurements extracted successfully.", None

    @staticmethod
    def _eval_signals(
        measurements: Dict[str, Any],
        img_qual_status: str,
        align_rel_status: str,
        seg_rel_status: str,
        is_fallback: bool,
        uncertainty_reasons: List[UncertaintyReason],
    ) -> Dict[str, SignalReliability]:
        signals = {}

        # 1. AREA
        earlier_area = measurements.get("earlier_area")
        latest_area = measurements.get("latest_area")
        area_pct = measurements.get("area_change_percent")
        if earlier_area is None or latest_area is None or seg_rel_status in ["unavailable", "failed"]:
            signals["area"] = SignalReliability(
                name="Area",
                reliability="unavailable",
                uncertainty=True,
                limitation="Region segmentation or mask extraction failed.",
                interpretation="Area measurements cannot be calculated without valid segmentations.",
            )
        else:
            if is_fallback or img_qual_status in ["limited", "poor"] or seg_rel_status == "moderate":
                rel = "moderate"
                unc = True
                lim = "Fallback segmentation or image quality factors may influence area counts."
                interp = f"Segmented area changed by {area_pct:+.1f}%. Interpret moderately due to segmentation bounds." if area_pct is not None else "Area measured with moderate confidence."
            elif seg_rel_status == "low" or img_qual_status == "poor":
                rel = "low"
                unc = True
                lim = "Low segmentation confidence reduces area precision."
                interp = "Area comparison should be interpreted cautiously."
            else:
                rel = "high"
                unc = False
                lim = None
                interp = f"Area measured with consistent high segmentation confidence ({area_pct:+.1f}% change)." if area_pct is not None else "Area extracted reliably."
            signals["area"] = SignalReliability(name="Area", reliability=rel, uncertainty=unc, limitation=lim, interpretation=interp)

        # 2. SHAPE
        shape_metrics = measurements.get("shape_metrics") or {}
        hu_score = shape_metrics.get("hu_moments_match_score")
        if hu_score is None or seg_rel_status in ["unavailable", "failed"]:
            signals["shape"] = SignalReliability(
                name="Shape",
                reliability="unavailable",
                uncertainty=True,
                limitation="Boundary contours could not be extracted.",
                interpretation="Shape comparison unavailable.",
            )
        else:
            if align_rel_status in ["low", "unavailable"] or is_fallback or img_qual_status == "poor":
                rel = "low" if align_rel_status in ["low", "unavailable"] else "moderate"
                unc = True
                lim = "Framing, perspective alignment, or fallback contours affect shape geometry."
                interp = "Shape contour differences may reflect camera angle or framing shifts."
            elif align_rel_status == "moderate":
                rel = "moderate"
                unc = True
                lim = "Partial alignment may introduce slight shape variance."
                interp = "Shape comparison shows observable contour geometry with moderate alignment."
            else:
                rel = "high"
                unc = False
                lim = None
                interp = "Shape contours matched cleanly under verified alignment."
            signals["shape"] = SignalReliability(name="Shape", reliability=rel, uncertainty=unc, limitation=lim, interpretation=interp)

        # 3. COLOR
        color_metrics = measurements.get("color_metrics") or {}
        color_dist = color_metrics.get("overall_color_distance")
        bright_delta = color_metrics.get("lighting_brightness_delta", 0.0)
        if color_dist is None or seg_rel_status in ["unavailable", "failed"]:
            signals["color"] = SignalReliability(
                name="Color",
                reliability="unavailable",
                uncertainty=True,
                limitation="Color distributions could not be extracted from region masks.",
                interpretation="Color comparison unavailable.",
            )
        else:
            if bright_delta > 35.0 or img_qual_status == "poor":
                signals["color"] = SignalReliability(
                    name="Color",
                    reliability="low",
                    uncertainty=True,
                    limitation=f"Lighting conditions differ significantly between captures ({bright_delta:.1f} brightness delta).",
                    interpretation="Color differences should be interpreted cautiously because capture lighting varies.",
                )
            elif bright_delta > 20.0 or img_qual_status == "limited":
                signals["color"] = SignalReliability(
                    name="Color",
                    reliability="moderate",
                    uncertainty=True,
                    limitation=f"Moderate lighting difference ({bright_delta:.1f} brightness delta) between photos.",
                    interpretation="Color features measured with moderate lighting consistency.",
                )
            else:
                signals["color"] = SignalReliability(
                    name="Color",
                    reliability="high",
                    uncertainty=False,
                    limitation=None,
                    interpretation="Consistent lighting allows reliable observable color comparison.",
                )

        # 4. POSITION (CENTROID)
        pos_metrics = measurements.get("position_metrics") or {}
        shift_px = pos_metrics.get("displacement_px")
        if shift_px is None or align_rel_status in ["unavailable", "failed"]:
            signals["position"] = SignalReliability(
                name="Position",
                reliability="unavailable",
                uncertainty=True,
                limitation="Centroid alignment tracking is unavailable.",
                interpretation="Position comparison unavailable without keypoint alignment.",
            )
        else:
            if align_rel_status == "low":
                rel = "low"
                unc = True
                lim = "Weak alignment keypoints limit relative centroid tracking."
                interp = "Position shifts likely reflect framing or alignment limitations."
            elif align_rel_status == "moderate":
                rel = "moderate"
                unc = True
                lim = "Partial alignment may introduce minor centroid displacement."
                interp = "Centroid position tracked with moderate alignment tolerance."
            else:
                rel = "high"
                unc = False
                lim = None
                interp = f"Centroid position aligned reliably ({shift_px:.1f} px relative displacement)."
            signals["position"] = SignalReliability(name="Position", reliability=rel, uncertainty=unc, limitation=lim, interpretation=interp)

        # 5. OVERLAP (IoU)
        boundary_metrics = measurements.get("boundary_metrics") or {}
        iou = boundary_metrics.get("mask_iou_overlap")
        if iou is None or seg_rel_status in ["unavailable", "failed"]:
            signals["overlap"] = SignalReliability(
                name="Segmentation Overlap",
                reliability="unavailable",
                uncertainty=True,
                limitation="Mask overlap (IoU) cannot be calculated without both valid masks.",
                interpretation="Overlap measurement unavailable.",
            )
        else:
            if align_rel_status in ["low", "unavailable"] or seg_rel_status == "low" or is_fallback:
                rel = "low" if align_rel_status in ["low", "unavailable"] else "moderate"
                unc = True
                lim = "Low alignment or fallback contours reduce overlap precision."
                interp = f"Mask overlap ({iou * 100:.1f}% IoU) carries uncertainty from alignment or segmentation bounds."
            elif align_rel_status == "moderate" or iou < 0.70:
                rel = "moderate"
                unc = True
                lim = "Moderate alignment or boundary variance detected."
                interp = f"Mask overlap is {iou * 100:.1f}% IoU under moderate alignment."
            else:
                rel = "high"
                unc = False
                lim = None
                interp = f"High mask overlap ({iou * 100:.1f}% IoU) under robust alignment."
            signals["overlap"] = SignalReliability(name="Segmentation Overlap", reliability=rel, uncertainty=unc, limitation=lim, interpretation=interp)

        return signals


ComparisonReliabilityEvaluator = ReliabilityEvaluator
