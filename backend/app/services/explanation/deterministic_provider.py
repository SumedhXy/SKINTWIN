import logging
import math
from typing import Any, Dict, List, Optional
from app.schemas.ai_explanation import (
    ComparisonExplanationInput,
    AIExplanationResponse,
    ObservationItem,
    ReliabilityExplanation,
    ModelMetadataInfo,
    NarrativeSummary,
    SignalItem,
    NarrativeReliability,
    NarrativeUncertainty,
)
from app.services.explanation.base_provider import BaseAIProvider

logger = logging.getLogger(__name__)

# Mandatory standard medical safety disclaimer. Must not be altered.
MEDICAL_DISCLAIMER = (
    "SkinTwin is an image comparison software and does NOT provide medical diagnosis, "
    "disease prediction, or clinical assessment. Measurements reflect computer-vision image metrics only. "
    "Always consult a qualified dermatologist or healthcare professional for medical evaluation of skin conditions."
)

SAFETY_MESSAGE = "This is an analysis of observable image differences and is not a medical diagnosis."

RECOMMENDED_NEXT_STEP = (
    "Continue standardized tracking. If you notice concerning changes or have health concerns, "
    "consider consulting a qualified healthcare professional."
)


class DeterministicAIProvider(BaseAIProvider):
    """
    Zero-external-dependency deterministic multi-signal narrative provider.
    Converts computer-vision metrics (Area, Shape, Color, Position, Overlap) into
    transparent, non-diagnostic narratives with engineering reliability and uncertainty.
    """

    def generate_explanation(self, input_data: ComparisonExplanationInput) -> AIExplanationResponse:
        signals = self._build_signals(input_data)
        narrative_rel = self._build_narrative_reliability(input_data, signals)
        uncertainty = self._build_narrative_uncertainty(input_data, narrative_rel)
        narrative_summary = self._build_narrative_summary(input_data, signals, narrative_rel, uncertainty)

        # Legacy backward-compatible fields
        observations = self._build_legacy_observations(signals, input_data)
        legacy_rel = ReliabilityExplanation(
            status="reliable" if narrative_rel.overall == "high" else ("needs_review" if narrative_rel.overall == "moderate" else "unavailable"),
            explanation=(
                "The image alignment and segmentation were verified, allowing for a reliable comparison."
                if narrative_rel.overall == "high"
                else (
                    "Measurements carry uncertainty due to lighting, alignment, or capture variations. Review limitations."
                    if narrative_rel.overall == "moderate"
                    else "Comparison cannot be evaluated reliably due to image quality or processing constraints."
                )
            ),
        )
        legacy_summary = narrative_summary.description

        model_meta = ModelMetadataInfo(
            model_name=input_data.model_name,
            model_version=input_data.model_version,
            inference_mode=input_data.inference_mode,
        )

        return AIExplanationResponse(
            narrative_summary=narrative_summary,
            signals=signals,
            narrative_reliability=narrative_rel,
            narrative_uncertainty=uncertainty,
            safety_message=SAFETY_MESSAGE,
            recommended_next_step=RECOMMENDED_NEXT_STEP,
            summary=legacy_summary,
            observations=observations,
            reliability=legacy_rel,
            limitations=narrative_rel.limitations,
            missing_information=list(set(input_data.missing_or_unavailable_values)),
            recommended_next_steps=[
                "Continue standardized tracking using consistent lighting and camera distance.",
                RECOMMENDED_NEXT_STEP,
            ],
            medical_disclaimer=MEDICAL_DISCLAIMER,
            model_metadata=model_meta,
        )

    # -------------------------------------------------------------------------
    # 1. MULTI-SIGNAL INTERPRETATION
    # -------------------------------------------------------------------------

    def _build_signals(self, data: ComparisonExplanationInput) -> List[SignalItem]:
        signals: List[SignalItem] = []

        is_insufficient = (
            data.alignment_status == "failed"
            or data.segmentation_status in ["failed", "unavailable"]
            or (data.earlier_area is None and data.latest_area is None)
        )

        # Signal 1: Area
        signals.append(self._interpret_area(data, is_insufficient))

        # Signal 2: Shape
        signals.append(self._interpret_shape(data, is_insufficient))

        # Signal 3: Color
        signals.append(self._interpret_color(data, is_insufficient))

        # Signal 4: Centroid / Position
        signals.append(self._interpret_position(data, is_insufficient))

        # Signal 5: Segmentation Overlap (IoU)
        signals.append(self._interpret_overlap(data, is_insufficient))

        return signals

    def _interpret_area(self, data: ComparisonExplanationInput, is_insufficient: bool) -> SignalItem:
        if is_insufficient or data.area_change_percent is None or data.earlier_area is None or data.latest_area is None:
            return SignalItem(
                name="Area",
                baseline_value=f"{data.earlier_area:.1f} px" if data.earlier_area is not None else None,
                followup_value=f"{data.latest_area:.1f} px" if data.latest_area is not None else None,
                change_value=None,
                change_unit="percent",
                direction="unavailable",
                status="unavailable",
                reliability="insufficient",
                explanation="Area comparison is unavailable because region segmentation or alignment could not be verified.",
            )

        pct = data.area_change_percent
        rel = "high" if data.reliability_status == "reliable" and not data.uncertainty_indicators else "moderate"
        if data.reliability_status in ["unreliable", "unavailable"]:
            rel = "low"

        if abs(pct) <= 5.0:
            direction = "stable"
            status = "stable"
            exp = (
                f"The measured segmented area changed from {data.earlier_area:.1f} to {data.latest_area:.1f} px "
                f"({pct:+.1f}%), which is within normal measurement variation tolerance."
            )
        elif pct > 0:
            direction = "increased"
            status = "observable_difference"
            exp = (
                f"The measured segmented area appears larger in the follow-up image, "
                f"from {data.earlier_area:.1f} to {data.latest_area:.1f} px ({pct:+.1f}%)."
            )
        else:
            direction = "decreased"
            status = "observable_difference"
            exp = (
                f"The measured segmented area appears smaller in the follow-up image, "
                f"from {data.earlier_area:.1f} to {data.latest_area:.1f} px ({pct:+.1f}%)."
            )

        return SignalItem(
            name="Area",
            baseline_value=round(data.earlier_area, 1),
            followup_value=round(data.latest_area, 1),
            change_value=round(pct, 2),
            change_unit="percent",
            direction=direction,
            status=status,
            reliability=rel,
            explanation=exp,
        )

    def _interpret_shape(self, data: ComparisonExplanationInput, is_insufficient: bool) -> SignalItem:
        shape_dict = data.shape_change_metrics or {}
        hu_score = shape_dict.get("hu_moments_match_score")
        p_earlier = shape_dict.get("earlier_perimeter_px")
        p_latest = shape_dict.get("latest_perimeter_px")

        if is_insufficient or (hu_score is None and p_earlier is None):
            return SignalItem(
                name="Shape",
                baseline_value=None,
                followup_value=None,
                change_value=None,
                change_unit="score",
                direction="unavailable",
                status="unavailable",
                reliability="insufficient",
                explanation="Shape comparison is unavailable because boundary contours could not be extracted.",
            )

        rel = "high" if data.alignment_status == "aligned" and not data.uncertainty_indicators else "moderate"
        if data.alignment_status != "aligned":
            rel = "low"

        if hu_score is not None and hu_score > 0.15:
            direction = "differed"
            status = "observable_difference"
            exp = f"The measured shape contours differ between captures (contour variation score {hu_score:.3f})."
        elif hu_score is not None:
            direction = "stable"
            status = "stable"
            exp = f"The measured contour shape is largely consistent between captures (variation score {hu_score:.3f})."
        else:
            direction = "stable"
            status = "stable"
            exp = "Shape contour analysis shows consistent boundary geometry between captures."

        return SignalItem(
            name="Shape",
            baseline_value=p_earlier,
            followup_value=p_latest,
            change_value=hu_score,
            change_unit="score",
            direction=direction,
            status=status,
            reliability=rel,
            explanation=exp,
        )

    def _interpret_color(self, data: ComparisonExplanationInput, is_insufficient: bool) -> SignalItem:
        color_dict = data.color_change_metrics or {}
        color_dist = color_dict.get("overall_color_distance")
        bright_delta = color_dict.get("lighting_brightness_delta", 0.0)

        if is_insufficient or color_dist is None:
            return SignalItem(
                name="Color",
                baseline_value=None,
                followup_value=None,
                change_value=None,
                change_unit="delta_e",
                direction="unavailable",
                status="unavailable",
                reliability="insufficient",
                explanation="Color comparison is unavailable because region color distributions were not extracted.",
            )

        has_lighting_issue = bright_delta > 35.0
        rel = "low" if has_lighting_issue else ("high" if data.reliability_status == "reliable" else "moderate")

        if color_dist > 15.0:
            direction = "differed"
            status = "observable_difference"
            if has_lighting_issue:
                exp = (
                    f"A difference in measured color features was detected (distance {color_dist:.1f}), "
                    f"but color comparison has limited reliability due to lighting shifts ({bright_delta:.1f} brightness delta)."
                )
            else:
                exp = f"A difference in measured color features was detected across the segmented area (color distance {color_dist:.1f})."
        else:
            direction = "stable"
            status = "stable"
            exp = f"Measured color distribution is consistent across both captures (color distance {color_dist:.1f})."

        return SignalItem(
            name="Color",
            baseline_value=color_dict.get("earlier_mean_bgr"),
            followup_value=color_dict.get("latest_mean_bgr"),
            change_value=round(float(color_dist), 1),
            change_unit="delta_e",
            direction=direction,
            status=status,
            reliability=rel,
            explanation=exp,
        )

    def _interpret_position(self, data: ComparisonExplanationInput, is_insufficient: bool) -> SignalItem:
        pos_dict = data.position_change_metrics or {}
        shift_px = pos_dict.get("displacement_px")
        c_earlier = pos_dict.get("earlier_centroid")
        c_latest = pos_dict.get("latest_centroid")

        if is_insufficient or shift_px is None:
            return SignalItem(
                name="Position",
                baseline_value=None,
                followup_value=None,
                change_value=None,
                change_unit="px",
                direction="unavailable",
                status="unavailable",
                reliability="insufficient",
                explanation="Position and centroid tracking are unavailable.",
            )

        rel = "high" if data.alignment_status == "aligned" else "moderate"

        if shift_px > 10.0:
            direction = "shifted"
            status = "observable_difference"
            exp = f"The detected region's relative position differs by {shift_px:.1f} px between captures (may reflect framing or alignment variation)."
        else:
            direction = "stable"
            status = "stable"
            exp = f"The detected region position is well-aligned between captures ({shift_px:.1f} px relative displacement)."

        return SignalItem(
            name="Position",
            baseline_value=c_earlier,
            followup_value=c_latest,
            change_value=round(float(shift_px), 1),
            change_unit="px",
            direction=direction,
            status=status,
            reliability=rel,
            explanation=exp,
        )

    def _interpret_overlap(self, data: ComparisonExplanationInput, is_insufficient: bool) -> SignalItem:
        boundary_dict = data.boundary_change_metrics or {}
        iou_score = boundary_dict.get("mask_iou_overlap")

        if is_insufficient or iou_score is None:
            return SignalItem(
                name="Segmentation Overlap",
                baseline_value=None,
                followup_value=None,
                change_value=None,
                change_unit="iou",
                direction="unavailable",
                status="unavailable",
                reliability="insufficient",
                explanation="Segmentation overlap (IoU) could not be computed.",
            )

        pct_overlap = round(iou_score * 100.0, 1)
        if iou_score >= 0.80:
            direction = "stable"
            status = "stable"
            rel = "high"
            exp = f"High mask overlap ({pct_overlap}% IoU), indicating strong boundary alignment between captures."
        elif iou_score >= 0.50:
            direction = "differed"
            status = "observable_difference"
            rel = "moderate"
            exp = f"Moderate mask overlap ({pct_overlap}% IoU). Partial boundary variation or slight framing shift observed."
        else:
            direction = "differed"
            status = "observable_difference"
            rel = "low"
            exp = f"Low mask overlap ({pct_overlap}% IoU). Lower overlap reduces the overall reliability of boundary comparisons."

        return SignalItem(
            name="Segmentation Overlap",
            baseline_value=None,
            followup_value=None,
            change_value=round(float(iou_score), 3),
            change_unit="iou",
            direction=direction,
            status=status,
            reliability=rel,
            explanation=exp,
        )

    # -------------------------------------------------------------------------
    # 2. RELIABILITY & LIMITATIONS
    # -------------------------------------------------------------------------

    def _build_narrative_reliability(
        self, data: ComparisonExplanationInput, signals: List[SignalItem]
    ) -> NarrativeReliability:
        limitations: List[str] = []

        # Check alignment
        align_status = "acceptable"
        if data.alignment_status != "aligned":
            align_status = "limited"
            limitations.append("Images could not be perfectly aligned across feature keypoints.")

        # Check segmentation
        seg_status = "completed"
        if data.segmentation_status != "segmented":
            seg_status = "incomplete"
            limitations.append("Region segmentation could not be cleanly isolated.")

        # Check quality & lighting
        quality_status = "acceptable"
        color_dict = data.color_change_metrics or {}
        bright_delta = color_dict.get("lighting_brightness_delta", 0.0)
        if bright_delta > 35.0:
            quality_status = "lighting_shift"
            limitations.append(f"Significant lighting brightness variation between captures ({bright_delta:.1f} delta).")

        # Collect any uncertainty indicators from data
        for unc in data.uncertainty_indicators:
            if unc not in limitations:
                limitations.append(unc)

        # Determine overall reliability level (high, moderate, low, insufficient)
        if (
            data.alignment_status == "failed"
            or data.segmentation_status in ["failed", "unavailable"]
            or (data.earlier_area is None and data.latest_area is None)
        ):
            overall = "insufficient"
        elif data.reliability_status == "unreliable" or len(limitations) >= 3:
            overall = "low"
        elif data.reliability_status == "needs_review" or len(limitations) > 0:
            overall = "moderate"
        else:
            overall = "high"

        if not limitations and overall == "high":
            limitations.append("Minor differences in angle or distance can still influence measurements.")

        return NarrativeReliability(
            overall=overall,
            quality_status=quality_status,
            alignment_status=align_status,
            segmentation_status=seg_status,
            limitations=limitations,
        )

    # -------------------------------------------------------------------------
    # 3. UNCERTAINTY
    # -------------------------------------------------------------------------

    def _build_narrative_uncertainty(
        self, data: ComparisonExplanationInput, reliability: NarrativeReliability
    ) -> NarrativeUncertainty:
        if reliability.overall in ["insufficient", "low"]:
            return NarrativeUncertainty(
                present=True,
                explanation="Significant photographic or technical limitations prevent reliable measurement comparison. Retaking photos with consistent lighting is recommended.",
            )
        elif reliability.overall == "moderate":
            return NarrativeUncertainty(
                present=True,
                explanation="Some differences may be influenced by capture conditions such as lighting angle, camera distance, or alignment variation.",
            )
        return NarrativeUncertainty(
            present=False,
            explanation="Capture conditions and image alignment are well-matched for observable comparison.",
        )

    # -------------------------------------------------------------------------
    # 4. SYNTHESIZED NARRATIVE SUMMARY (AGREEMENT / DISAGREEMENT)
    # -------------------------------------------------------------------------

    def _build_narrative_summary(
        self,
        data: ComparisonExplanationInput,
        signals: List[SignalItem],
        reliability: NarrativeReliability,
        uncertainty: NarrativeUncertainty,
    ) -> NarrativeSummary:
        if reliability.overall == "insufficient":
            return NarrativeSummary(
                title="Comparison Unavailable",
                description="The comparison could not be completed because image alignment, segmentation, or required metrics were unavailable.",
                status="insufficient_data",
            )

        diff_signals = [s.name for s in signals if s.status == "observable_difference"]
        stable_signals = [s.name for s in signals if s.status == "stable"]

        if reliability.overall in ["low", "insufficient"]:
            title = "Uncertain Comparison Results"
            desc = "Image quality or alignment constraints limit the reliability of this comparison. Review the reliability notes below."
            status = "review_required"
        elif diff_signals:
            title = "Observable Differences Detected"
            signals_str = ", ".join(diff_signals)
            if reliability.overall == "moderate":
                desc = (
                    f"Observable differences were measured in {signals_str}. "
                    f"Comparison reliability is moderate because capture conditions or lighting vary between captures."
                )
            else:
                desc = (
                    f"The comparison measured observable differences in {signals_str} "
                    f"across the two captures with high engineering reliability."
                )
            status = "observable_difference"
        else:
            title = "No Significant Difference Measured"
            desc = (
                "The available image metrics (Area, Shape, Color, Position) show consistent measurements within normal variation tolerance."
            )
            status = "no_significant_difference"

        return NarrativeSummary(title=title, description=desc, status=status)

    # -------------------------------------------------------------------------
    # 5. LEGACY OBSERVATIONS FOR BACKWARD COMPATIBILITY
    # -------------------------------------------------------------------------

    def _build_legacy_observations(
        self, signals: List[SignalItem], data: ComparisonExplanationInput
    ) -> List[ObservationItem]:
        obs = []
        for s in signals:
            metric_key = s.name.lower().replace(" ", "_")
            if metric_key == "segmentation_overlap":
                metric_key = "overlap"
            status_str = "changed" if s.status == "observable_difference" else ("unchanged" if s.status == "stable" else "unavailable")
            val_str = f"{s.change_value} {s.change_unit}" if s.change_value is not None else None
            obs.append(
                ObservationItem(
                    metric=metric_key,
                    status=status_str,
                    value=val_str,
                    explanation=s.explanation,
                )
            )
        return obs
