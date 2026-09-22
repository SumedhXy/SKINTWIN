import os
import pytest
import cv2
import numpy as np
from pathlib import Path
from app.services.segmentation.medsam import MedSAMSegmentationModel

@pytest.mark.real_inference
def test_real_medsam_inference_does_not_use_fallback():
    """
    Test that enforces REAL MedSAM inference using PyTorch weights.
    It will skip (or fail) if the host environment blocks PyTorch Native DLLs 
    and forces a fallback.
    """
    # 1. Initialize Model
    model = MedSAMSegmentationModel()
    info = model.get_model_info()

    # 2. Check for Real Capabilities
    weights_loaded = info.get("weights_loaded", False)
    pytorch_available = info.get("pytorch_available", False)
    inference_mode = info.get("inference_mode", "unavailable")
    fallback_used = info.get("fallback_used", True)

    if not pytorch_available:
        pytest.skip("PyTorch unavailable in this environment (likely WinError 4551 AppLocker block). Cannot test REAL MedSAM inference.")

    if not weights_loaded:
        pytest.skip("PyTorch is available, but MedSAM weights file is missing. Cannot test REAL MedSAM inference.")

    assert fallback_used is False, "Fallback must not be used for real inference verification"
    assert inference_mode == "real_medsam", "Inference mode must be 'real_medsam'"
    assert "fallback_cv" not in info.get("model_name", ""), "Model name cannot be fallback_cv"

    # 3. Create real test image (Synthetic but treated as real for inference pipeline test)
    width, height = 300, 300
    img = np.full((height, width, 3), 150, dtype=np.uint8)
    # Add a mock lesion
    cv2.circle(img, (150, 150), 40, (50, 50, 200), -1)

    # 4. Run real inference
    prompt = {"bbox": [100, 100, 200, 200]}
    res = model.predict_region(img, prompt=prompt)

    # 5. Verify Output
    assert res["status"] == "segmented"
    assert res["mask"] is not None
    assert isinstance(res["mask"], np.ndarray)
    assert res["mask_area_px"] > 0
    assert res["inference_mode"] == "real_medsam"
    assert res["fallback_used"] is False

    print("✅ REAL MedSAM inference executed successfully on PyTorch.")
