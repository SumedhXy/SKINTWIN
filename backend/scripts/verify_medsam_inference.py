import argparse
import sys
import json
import cv2
import time
from pathlib import Path

# Add project root to path so we can import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.segmentation.medsam import MedSAMSegmentationModel
from app.utils.segmentation_metrics import save_mask_visualization

def verify_inference(image_path: str, bbox: list, output_dir: str):
    print(f"Loading image from {image_path}...")
    image = cv2.imread(image_path)
    if image is None:
        print(f"Error: Could not read image at {image_path}")
        sys.exit(1)

    print("Initializing MedSAM Segmentation Model...")
    model = MedSAMSegmentationModel()
    
    info = model.get_model_info()
    weights_loaded = info.get("is_loaded", False)
    pytorch_available = info.get("pytorch_available", False)
    
    # Determine explicit modes
    if weights_loaded and pytorch_available:
        inference_mode = "real_medsam"
        fallback_used = False
    elif not pytorch_available:
        inference_mode = "fallback_cv"
        fallback_used = True
    else:
        inference_mode = "fallback_cv"
        fallback_used = True

    prompt = {"bbox": bbox, "source": "user_bbox"}

    print(f"Running inference... (Mode: {inference_mode})")
    start_time = time.time()
    res = model.predict_region(image, prompt=prompt)
    duration = time.time() - start_time
    
    status = res.get("status")
    mask = res.get("mask")
    
    report = {
        "model_name": res.get("model_name"),
        "inference_mode": inference_mode,
        "weights_loaded": weights_loaded,
        "fallback_used": fallback_used,
        "inference_status": "completed_with_fallback" if fallback_used else "completed",
        "device": info.get("device", "cpu"),
        "mask_generated": mask is not None and status == "segmented",
        "inference_time_seconds": round(duration, 3),
        "error_code": res.get("error_code")
    }

    if status == "failed":
        report["inference_status"] = "failed"
    
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    
    if mask is not None:
        vis_path = out_dir / "medsam_verification_overlay.png"
        save_mask_visualization(image, mask, str(vis_path), bbox=bbox)
        print(f"Visualization saved to {vis_path}")

    report_path = out_dir / "medsam_verification_report.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"Report saved to {report_path}")
    
    print("\n--- FINAL REPORT ---")
    print(json.dumps(report, indent=2))
    
    if fallback_used:
        print("\nWARNING: Real MedSAM was NOT used. System fell back to CV segmentation.")
    else:
        print("\nSUCCESS: Real MedSAM inference executed successfully.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify MedSAM Inference")
    parser.add_argument("--image", type=str, required=True, help="Path to test image")
    parser.add_argument("--bbox", type=int, nargs=4, required=True, help="Bounding box coordinates x1 y1 x2 y2")
    parser.add_argument("--output", type=str, required=True, help="Output directory for report and visualization")
    
    args = parser.parse_args()
    verify_inference(args.image, args.bbox, args.output)
