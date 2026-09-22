import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional
import numpy as np
import cv2

logger = logging.getLogger(__name__)

DATASET_BASE_DIR = Path("dataset")
IMAGES_DIR = DATASET_BASE_DIR / "images"
MASKS_DIR = DATASET_BASE_DIR / "masks"
METADATA_DIR = DATASET_BASE_DIR / "metadata"
SPLITS_DIR = DATASET_BASE_DIR / "splits"


def init_dataset_structure() -> None:
    """Ensure all dataset preparation directories exist."""
    for d in [IMAGES_DIR, MASKS_DIR, METADATA_DIR, SPLITS_DIR]:
        d.mkdir(parents=True, exist_ok=True)

    for split in ["train.json", "validation.json", "test.json"]:
        p = SPLITS_DIR / split
        if not p.exists():
            with open(p, "w", encoding="utf-8") as f:
                json.dump([], f)


class DatasetPrepService:
    """
    Manages preparation and structuring of skin-finding captures and masks into
    standardized MedSAM fine-tuning format.
    """

    @staticmethod
    def prepare_sample(
        capture_id: str,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: Dict[str, Any],
        finding_type: str = "other",
        split_name: str = "train",
    ) -> Dict[str, Any]:
        """
        Export image, mask, and structured metadata for fine-tuning.
        Updates split allocation file (train.json, validation.json, test.json).
        """
        init_dataset_structure()

        if image is None or mask is None:
            raise ValueError("Image and mask must not be None for dataset export.")

        image_filename = f"{capture_id}.png"
        mask_filename = f"{capture_id}_mask.png"
        meta_filename = f"{capture_id}.json"

        image_path = IMAGES_DIR / image_filename
        mask_path = MASKS_DIR / mask_filename
        meta_path = METADATA_DIR / meta_filename

        # 1. Save standardized 1024x1024 image for MedSAM fine-tuning input
        h, w = image.shape[:2]
        cv2.imwrite(str(image_path), image)

        # 2. Save binary mask PNG (0 = background, 255 = lesion)
        cv2.imwrite(str(mask_path), mask)

        # 3. Save JSON metadata
        area_px = float(np.count_nonzero(mask))
        metadata = {
            "capture_id": capture_id,
            "image_path": str(image_path),
            "mask_path": str(mask_path),
            "image_dimensions": [w, h],
            "finding_type": finding_type,
            "prompt": prompt,
            "area_px": area_px,
            "non_diagnostic_disclaimer": "This sample is prepared for observable technical segmentation fine-tuning only. Not for medical diagnosis or clinical classification.",
        }

        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)

        # 4. Add to split JSON file
        split_file = SPLITS_DIR / f"{split_name}.json"
        if not split_file.exists():
            split_samples = []
        else:
            try:
                with open(split_file, "r", encoding="utf-8") as f:
                    split_samples = json.load(f)
            except Exception:
                split_samples = []

        if capture_id not in split_samples:
            split_samples.append(capture_id)
            with open(split_file, "w", encoding="utf-8") as f:
                json.dump(split_samples, f, indent=2)

        logger.info(f"Successfully exported capture {capture_id} to dataset [{split_name}] split.")
        return metadata

    @staticmethod
    def get_dataset_summary() -> Dict[str, Any]:
        """Summarize current fine-tuning dataset statistics across train/validation/test splits."""
        init_dataset_structure()
        summary = {"total_samples": 0, "splits": {}}

        for split in ["train", "validation", "test"]:
            p = SPLITS_DIR / f"{split}.json"
            if p.exists():
                try:
                    with open(p, "r", encoding="utf-8") as f:
                        items = json.load(f)
                        count = len(items)
                except Exception:
                    count = 0
            else:
                count = 0

            summary["splits"][split] = count
            summary["total_samples"] += count

        return summary
