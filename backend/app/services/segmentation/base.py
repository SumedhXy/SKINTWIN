from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
import numpy as np


class SegmentationModelInterface(ABC):
    """Abstract interface for skin finding segmentation models (MedSAM ViT-B, fine-tuned SAM, etc.)."""

    @abstractmethod
    def load_model(self) -> bool:
        """Load model weights into memory/device. Returns True if successfully loaded."""
        pass

    @abstractmethod
    def predict_region(
        self, image: np.ndarray, prompt: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Run region segmentation on BGR image given optional ROI bounding box or point prompt.
        Returns dictionary containing:
        - status: "segmented", "low_confidence", "failed", or "unavailable"
        - confidence: float (0.0 to 1.0)
        - mask: Optional[np.ndarray] (2D uint8 0/255)
        - mask_area_px: float
        - centroid: Optional[tuple[float, float]]
        - perimeter: Optional[float]
        - model_name: str
        - model_version: str
        - error_code: Optional[str]
        """
        pass

    @abstractmethod
    def get_model_info(self) -> Dict[str, Any]:
        """Return model metadata (architecture, version, device, weights path)."""
        pass
