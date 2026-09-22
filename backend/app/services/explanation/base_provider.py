import abc
from app.schemas.ai_explanation import ComparisonExplanationInput, AIExplanationResponse

class BaseAIProvider(abc.ABC):
    """Abstract base class for AI explanation providers."""

    @abc.abstractmethod
    def generate_explanation(self, input_data: ComparisonExplanationInput) -> AIExplanationResponse:
        """
        Generate an AI explanation based on structured ML measurements.
        Must return a valid AIExplanationResponse that strictly adheres to medical safety rules.
        """
        pass
