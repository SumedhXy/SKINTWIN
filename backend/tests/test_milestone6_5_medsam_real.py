import os
import json
from pathlib import Path
import numpy as np
import cv2
import pytest

from app.utils.segmentation_metrics import (
    compute_dice_coefficient,
    compute_iou,
    compute_mask_contrast_and_sharpness,
    save_mask_visualization,
    log_segmentation_failure,
)
from app.services.segmentation.medsam import (
    MedSAMSegmentationModel,
    generate_auto_prompt,
)
from app.services.dataset_prep_service import (
    DatasetPrepService,
    init_dataset_structure,
    DATASET_BASE_DIR,
)
from app.services.measurement_service import MeasurementService


def test_dice_and_iou_metrics():
    """Verify Dice coefficient and IoU calculations on synthetic masks."""
    mask1 = np.zeros((100, 100), dtype=np.uint8)
    mask2 = np.zeros((100, 100), dtype=np.uint8)

    # Identical masks
    mask1[20:50, 20:50] = 255
    mask2[20:50, 20:50] = 255

    dice = compute_dice_coefficient(mask1, mask2)
    iou = compute_iou(mask1, mask2)

    assert dice == 1.0
    assert iou == 1.0

    # Partial overlap
    mask3 = np.zeros((100, 100), dtype=np.uint8)
    mask3[30:60, 30:60] = 255  # Overlaps [30:50, 30:50]

    dice_partial = compute_dice_coefficient(mask1, mask3)
    iou_partial = compute_iou(mask1, mask3)

    assert 0.0 < dice_partial < 1.0
    assert 0.0 < iou_partial < 1.0
    assert dice_partial > iou_partial  # Mathematical relationship: Dice > IoU for partial overlap


def test_contrast_and_sharpness():
    """Verify contrast ratio and boundary sharpness dynamic calculations."""
    img = np.ones((100, 100, 3), dtype=np.uint8) * 200
    mask = np.zeros((100, 100), dtype=np.uint8)
    # Dark lesion spot in center
    img[40:60, 40:60] = [50, 50, 50]
    mask[40:60, 40:60] = 255

    metrics = compute_mask_contrast_and_sharpness(img, mask)
    assert "contrast_ratio" in metrics
    assert "boundary_sharpness" in metrics
    assert metrics["contrast_ratio"] > 0.0
    assert metrics["boundary_sharpness"] > 0.0


def test_auto_prompt_generator():
    """Verify automated skin finding prompt generator returns valid bounding box."""
    # Create synthetic skin image with lesion spot
    img = np.ones((200, 200, 3), dtype=np.uint8)
    img[:, :] = [120, 140, 200]  # Skin-like BGR color
    img[70:130, 70:130] = [30, 30, 100]  # Dark pigmented mole spot

    prompt = generate_auto_prompt(img)
    assert "bbox" in prompt
    assert "source" in prompt
    bbox = prompt["bbox"]
    assert len(bbox) == 4
    x1, y1, x2, y2 = bbox
    assert 0 <= x1 < x2 <= 200
    assert 0 <= y1 < y2 <= 200


def test_medsam_real_predict_with_user_prompt():
    """Test MedSAM segmentation model prediction with user-supplied bounding box."""
    model = MedSAMSegmentationModel()
    img = np.ones((150, 150, 3), dtype=np.uint8) * 180
    img[50:100, 50:100] = [40, 40, 40]

    user_prompt = {"bbox": [40, 40, 110, 110]}
    res = model.predict_region(img, prompt=user_prompt)

    assert res["status"] == "segmented"
    assert res["prompt_source"] == "user_bbox"
    assert res["confidence"] > 0.0
    assert res["mask"] is not None
    assert res["mask_area_px"] > 0
    assert "non_diagnostic_disclaimer" in res


def test_medsam_predict_auto_prompt():
    """Test MedSAM segmentation prediction when prompt is None (automated fallback)."""
    model = MedSAMSegmentationModel()
    img = np.ones((150, 150, 3), dtype=np.uint8) * 180
    img[50:100, 50:100] = [40, 40, 40]

    res = model.predict_region(img, prompt=None)

    assert res["status"] == "segmented"
    assert res["prompt_source"] in ["auto_saliency_otsu", "auto_fallback_center"]
    assert res["confidence"] > 0.0
    assert res["mask_area_px"] > 0


def test_dataset_prep_service():
    """Test fine-tuning dataset sample preparation and split tracking."""
    capture_id = "test_cap_12345"
    img = np.ones((100, 100, 3), dtype=np.uint8) * 150
    mask = np.zeros((100, 100), dtype=np.uint8)
    mask[30:70, 30:70] = 255
    prompt = {"bbox": [25, 25, 75, 75], "source": "user_bbox"}

    meta = DatasetPrepService.prepare_sample(
        capture_id=capture_id,
        image=img,
        mask=mask,
        prompt=prompt,
        finding_type="mole",
        split_name="train",
    )

    assert meta["capture_id"] == capture_id
    assert meta["finding_type"] == "mole"
    assert Path(meta["image_path"]).exists()
    assert Path(meta["mask_path"]).exists()

    summary = DatasetPrepService.get_dataset_summary()
    assert summary["total_samples"] >= 1
    assert summary["splits"]["train"] >= 1


def test_visualization_and_failure_logging():
    """Test mask visualization export and failure logging functions."""
    img = np.ones((100, 100, 3), dtype=np.uint8) * 200
    mask = np.zeros((100, 100), dtype=np.uint8)
    mask[30:70, 30:70] = 255

    vis_path = "dataset/visualizations/test_vis.png"
    ok = save_mask_visualization(img, mask, vis_path, bbox=[25, 25, 75, 75])
    assert ok is True
    assert Path(vis_path).exists()

    # Log synthetic failure case
    log_segmentation_failure("cap_fail_001", "MASK_EMPTY", {"bbox": [0, 0, 10, 10]})
    assert Path("dataset/failures/failure_cases.log").exists()


def test_dynamic_reliability_score_calculation():
    """Verify MeasurementService calculates dynamic reliability score without hardcoding."""
    img1 = np.ones((100, 100, 3), dtype=np.uint8) * 200
    img2 = np.ones((100, 100, 3), dtype=np.uint8) * 200

    img1[30:70, 30:70] = [50, 50, 50]
    img2[30:70, 30:70] = [50, 50, 50]

    mask1 = np.zeros((100, 100), dtype=np.uint8)
    mask2 = np.zeros((100, 100), dtype=np.uint8)
    mask1[30:70, 30:70] = 255
    mask2[30:70, 30:70] = 255

    earlier_seg = {"status": "segmented", "mask": mask1, "centroid": (50.0, 50.0), "perimeter": 160.0}
    latest_seg = {"status": "segmented", "mask": mask2, "centroid": (50.0, 50.0), "perimeter": 160.0}

    align_res = {
        "alignment_status": "aligned",
        "alignment_score": 0.95,
        "match_count": 50,
        "inlier_count": 45,
        "inlier_ratio": 0.90,
    }

    metrics = MeasurementService.calculate_metrics(
        earlier_img=img1,
        latest_img=img2,
        earlier_seg=earlier_seg,
        latest_seg=latest_seg,
        alignment_res=align_res,
    )

    assert metrics["measurement_status"] == "measured"
    assert metrics["reliability_status"] == "reliable"
    assert metrics["reliability_score"] > 0.80
    assert "non_diagnostic_disclaimer" in metrics
