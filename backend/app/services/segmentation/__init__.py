from app.services.segmentation.base import SegmentationModelInterface
from app.services.segmentation.medsam import MedSAMSegmentationModel

_SEGMENTATION_MODEL = None


def get_segmentation_model() -> SegmentationModelInterface:
    """Return a singleton segmentation model to avoid repeated expensive initialization."""
    global _SEGMENTATION_MODEL
    if _SEGMENTATION_MODEL is None:
        _SEGMENTATION_MODEL = MedSAMSegmentationModel()
    return _SEGMENTATION_MODEL


__all__ = [
    "SegmentationModelInterface",
    "MedSAMSegmentationModel",
    "get_segmentation_model",
]
