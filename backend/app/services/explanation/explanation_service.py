import json
import logging
from typing import Optional
from sqlalchemy.orm import Session
from app.models.comparison import Comparison
from app.models.capture import Capture
from app.schemas.ai_explanation import ComparisonExplanationInput, AIExplanationResponse
from app.services.explanation.base_provider import BaseAIProvider
from app.services.explanation.deterministic_provider import DeterministicAIProvider
from app.services.explanation.llm_provider import LLMProvider
from app.core.config import settings

logger = logging.getLogger(__name__)


def get_ai_provider() -> BaseAIProvider:
    provider_type = settings.AI_PROVIDER.lower()
    if provider_type == "gemini":
        api_key = settings.GEMINI_API_KEY
        if api_key:
            return LLMProvider(api_key=api_key, model_name=settings.GEMINI_MODEL)
    return DeterministicAIProvider()


class ExplanationService:
    @staticmethod
    def get_or_generate_explanation(db: Session, comparison: Comparison) -> AIExplanationResponse:
        provider = get_ai_provider()
        # If explanation is already generated and cached in DB, validate that it has modern multi-signal schema
        if comparison.ai_explanation:
            try:
                data = json.loads(comparison.ai_explanation)
                if "narrative_summary" in data and "signals" in data and "narrative_reliability" in data:
                    return AIExplanationResponse.model_validate(data)
            except Exception:
                # If parsing fails or schema was upgraded, regenerate
                pass

        # Build structured input
        earlier_capture = db.query(Capture).filter(Capture.id == comparison.earlier_capture_id).first()
        latest_capture = db.query(Capture).filter(Capture.id == comparison.latest_capture_id).first()

        def parse_json_field(val):
            if not val:
                return None
            if isinstance(val, str):
                try:
                    return json.loads(val)
                except Exception:
                    return None
            return val

        input_data = ComparisonExplanationInput(
            comparison_id=comparison.id,
            skintwin_id=comparison.skintwin_id,
            baseline_capture_date=earlier_capture.captured_at if earlier_capture else None,
            followup_capture_date=latest_capture.captured_at if latest_capture else None,
            alignment_status=comparison.alignment_status,
            alignment_score=comparison.alignment_score,
            inlier_ratio=comparison.inlier_ratio,
            match_count=comparison.match_count,
            segmentation_status=comparison.localization_status,
            localization_confidence=comparison.localization_confidence,
            model_name=comparison.segmentation_model or "unknown",
            model_version=comparison.segmentation_model_version or "unknown",
            inference_mode=(
                "real_medsam"
                if comparison.segmentation_model in ["medsam_vit_b", "MedSAM ViT-B"]
                else ("fallback_cv" if comparison.segmentation_model == "fallback_cv" else "unavailable")
            ),
            fallback_used=comparison.segmentation_model not in ["medsam_vit_b", "MedSAM ViT-B"],
            area_change_percent=comparison.area_change_percent,
            earlier_area=comparison.earlier_area,
            latest_area=comparison.latest_area,
            color_change_metrics=parse_json_field(comparison.color_change_metrics),
            shape_change_metrics=parse_json_field(comparison.shape_change_metrics),
            boundary_change_metrics=parse_json_field(comparison.boundary_change_metrics),
            position_change_metrics=parse_json_field(comparison.position_change_metrics),
            reliability_status=comparison.reliability_status,
            reliability_score=comparison.reliability_score,
            uncertainty_indicators=parse_json_field(comparison.uncertainty_reasons) or [],
            missing_or_unavailable_values=[],
        )

        # Gather missing fields
        missing = []
        if input_data.area_change_percent is None:
            missing.append("area_change")
        if input_data.color_change_metrics is None:
            missing.append("color_metrics")
        if input_data.shape_change_metrics is None:
            missing.append("shape_metrics")
        if input_data.position_change_metrics is None:
            missing.append("position_metrics")
        input_data.missing_or_unavailable_values = missing

        response = provider.generate_explanation(input_data)

        # Cache response in database record
        comparison.ai_explanation = response.model_dump_json()
        db.commit()

        return response

    @staticmethod
    def generate_explanation_force(db: Session, comparison: Comparison) -> AIExplanationResponse:
        comparison.ai_explanation = None
        return ExplanationService.get_or_generate_explanation(db, comparison)
