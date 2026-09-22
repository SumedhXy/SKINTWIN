import os
import time
import json
import numpy as np
import cv2
from pathlib import Path

# Adjust path to import app modules
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.services.segmentation.medsam import MedSAMSegmentationModel

def create_synthetic_image(size=(300, 300), bg_color=(200, 200, 200), fg_color=(50, 50, 200), fg_radius=50):
    img = np.zeros((size[0], size[1], 3), dtype=np.uint8)
    img[:] = bg_color
    center = (size[1] // 2, size[0] // 2)
    cv2.circle(img, center, fg_radius, fg_color, -1)
    return img

def apply_blur(img, ksize=(15, 15)):
    return cv2.GaussianBlur(img, ksize, 0)

def adjust_exposure(img, gamma=1.0):
    invGamma = 1.0 / gamma
    table = np.array([((i / 255.0) ** invGamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
    return cv2.LUT(img, table)

def run_audit():
    print("Starting Deployment Readiness Audit...")
    outputs_dir = Path("outputs/audit")
    outputs_dir.mkdir(parents=True, exist_ok=True)
    
    # Initialize model
    start_init = time.time()
    model = MedSAMSegmentationModel()
    init_time = time.time() - start_init
    
    print(f"Model initialized in {init_time:.2f}s")
    print(f"Model Name: {model.model_name}")
    print(f"Is PyTorch Available: {model._pytorch_available}")
    print(f"Is Loaded: {model._is_loaded}")
    
    test_cases = [
        {"name": "standard_clear", "img": create_synthetic_image(), "bbox": [100, 100, 200, 200]},
        {"name": "underexposed", "img": adjust_exposure(create_synthetic_image(), gamma=0.3), "bbox": [100, 100, 200, 200]},
        {"name": "overexposed", "img": adjust_exposure(create_synthetic_image(), gamma=2.5), "bbox": [100, 100, 200, 200]},
        {"name": "blurred", "img": apply_blur(create_synthetic_image(), (25, 25)), "bbox": [100, 100, 200, 200]},
        {"name": "low_resolution", "img": create_synthetic_image(size=(64, 64), fg_radius=15), "bbox": [16, 16, 48, 48]},
        {"name": "high_resolution", "img": create_synthetic_image(size=(1024, 1024), fg_radius=200), "bbox": [300, 300, 700, 700]},
        {"name": "invalid_roi_out_of_bounds", "img": create_synthetic_image(), "bbox": [400, 400, 500, 500]},
        {"name": "invalid_roi_negative", "img": create_synthetic_image(), "bbox": [-50, -50, 50, 50]},
    ]
    
    results = []
    
    for tc in test_cases:
        print(f"\nRunning test: {tc['name']}")
        start_time = time.time()
        
        try:
            x1, y1, x2, y2 = tc["bbox"]
            res = model.predict_region(tc["img"], prompt={"bbox": [x1, y1, x2, y2], "source": "manual"})
            
            # Save overlay for inspection if successful
            if res.get("status") == "success" and "mask" in res:
                mask = res["mask"]
                overlay = tc["img"].copy()
                overlay[mask > 0] = [0, 255, 0] # Green mask
                cv2.rectangle(overlay, (int(x1), int(y1)), (int(x2), int(y2)), (255, 0, 0), 2)
                cv2.imwrite(str(outputs_dir / f"{tc['name']}_overlay.png"), overlay)
            
            # Remove actual mask array from json log
            if "mask" in res:
                res["mask_shape"] = res["mask"].shape
                del res["mask"]
                
        except Exception as e:
            res = {"status": "error", "error_message": str(e)}
            
        inf_time = time.time() - start_time
        res["test_name"] = tc["name"]
        res["inference_time"] = inf_time
        results.append(res)
        
        print(f"Status: {res.get('status')} | Time: {inf_time:.3f}s")
        
    with open(outputs_dir / "audit_report.json", "w") as f:
        json.dump(results, f, indent=2)
        
    print("\nAudit complete. Results saved to outputs/audit/")

if __name__ == "__main__":
    run_audit()
