import logging
import json
import re
from typing import Optional
from google import genai
from pydantic import ValidationError
from app.schemas.ai_explanation import ComparisonExplanationInput, AIExplanationResponse
from app.services.explanation.base_provider import BaseAIProvider
from app.services.explanation.deterministic_provider import (
    DeterministicAIProvider,
    MEDICAL_DISCLAIMER,
    SAFETY_MESSAGE,
    RECOMMENDED_NEXT_STEP,
)

logger = logging.getLogger(__name__)


class LLMProvider(BaseAIProvider):
    """
    Optional LLM provider integrating with external AI APIs (e.g. Gemini).
    Always enforces fallback to DeterministicAIProvider on API timeout, missing key,
    or schema / safety / numerical validation failure.
    """

    def __init__(self, api_key: str, model_name: str = "gemini-1.5-flash"):
        self.api_key = api_key
        self.model_name = model_name
        self.fallback_provider = DeterministicAIProvider()

        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    def generate_explanation(self, input_data: ComparisonExplanationInput) -> AIExplanationResponse:
        if not self.client:
            logger.warning("No API key provided for LLMProvider. Falling back to DeterministicAIProvider.")
            return self.fallback_provider.generate_explanation(input_data)

        # Create deterministic response as ground truth template
        det_response = self.fallback_provider.generate_explanation(input_data)

        # Prepare safe JSON payload (no PII, no raw image binaries)
        payload = input_data.model_dump(mode="json")
        prompt = (
            "You are an AI Multi-Signal Change Narrative explanation layer for SkinTwin, a computer-vision image comparison tool. "
            "Convert the following structured measurements (Area, Shape, Color, Position, Overlap) into a clear, transparent explanation for a user. "
            "RULES:\n"
            "1. NEVER invent measurements, clinical conclusions, or data not present in the input.\n"
            "2. Strictly preserve all numerical values and directions (increased, decreased, stable).\n"
            "3. NEVER provide a medical diagnosis, predict disease, or use clinical terms (benign, malignant, cancerous, melanoma, healthy, safe).\n"
            "4. Missing measurements must be explicitly marked 'unavailable', not assumed unchanged.\n"
            "5. Engineering reliability must strictly be one of: 'high', 'moderate', 'low', 'insufficient'.\n"
            "6. Always state observable photographic differences, never biological growth or pathology.\n"
            "7. The response MUST strictly adhere to the AIExplanationResponse JSON schema.\n\n"
            f"Input Data:\n{json.dumps(payload, indent=2)}"
        )

        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=AIExplanationResponse,
                    temperature=0.0,  # Deterministic generation
                ),
            )

            # Validate generated JSON against Pydantic schema
            ai_resp = AIExplanationResponse.model_validate_json(response.text)

            # Ensure safety disclaimers are strictly enforced
            ai_resp.medical_disclaimer = MEDICAL_DISCLAIMER
            ai_resp.safety_message = SAFETY_MESSAGE
            if not ai_resp.recommended_next_step:
                ai_resp.recommended_next_step = RECOMMENDED_NEXT_STEP
            ai_resp.model_metadata = det_response.model_metadata

            # If signals were empty or incomplete, fill with deterministic signals
            if not ai_resp.signals:
                ai_resp.signals = det_response.signals
            if not ai_resp.narrative_reliability:
                ai_resp.narrative_reliability = det_response.narrative_reliability
            if not ai_resp.narrative_uncertainty:
                ai_resp.narrative_uncertainty = det_response.narrative_uncertainty

            # 1. Contextual Medical Safety Pattern Check
            text_to_check = json.dumps({
                "summary": ai_resp.summary,
                "narrative_summary": ai_resp.narrative_summary.model_dump(),
                "signals": [s.model_dump() for s in ai_resp.signals],
                "observations": [obs.model_dump() for obs in ai_resp.observations],
            }).lower()

            prohibited_patterns = [
                r"\b(appears? harmless|looks? safe|is benign|malignant|diagnos(is|ed)|disease detected|cancerous|melanoma|no risk|low risk|high risk)\b",
                r"\b(appears? healthy|is normal|looks? normal)\b",
                r"\b(consult immediately|urgent emergency)\b",
                r"\b(biological growth|tumor|lesion progression)\b",
            ]
            for pattern in prohibited_patterns:
                if re.search(pattern, text_to_check):
                    logger.error(f"Safety violation: Response contains prohibited contextual pattern '{pattern}'")
                    return det_response

            # 2. Strict Numerical Preservation Check
            def _extract_numbers(text):
                return re.findall(r"[-+]?\d*\.\d+|\d+", str(text))

            def _check_preservation(expected_val, text_val):
                if expected_val is None:
                    return True
                numbers = _extract_numbers(text_val)
                if not numbers:
                    return False
                return any(abs(abs(float(n)) - abs(expected_val)) < 0.1 for n in numbers)

            # Check area signal preservation
            if input_data.area_change_percent is not None:
                area_signal = next((s for s in ai_resp.signals if s.name.lower() == "area"), None)
                if area_signal and area_signal.change_value is not None:
                    if not _check_preservation(input_data.area_change_percent, area_signal.change_value):
                        logger.error(f"Numerical mismatch in area signal: {input_data.area_change_percent} vs {area_signal.change_value}")
                        return det_response

            return ai_resp

        except (ValidationError, Exception) as e:
            logger.error(
                f"LLM generation failed, returned invalid schema, or triggered safety fallback: {e}. "
                "Falling back to deterministic provider."
            )
            return det_response
