import sys
import platform
import json
from pathlib import Path

def get_environment_info():
    info = {
        "python_version": platform.python_version(),
        "os": platform.platform(),
        "architecture": platform.architecture()[0],
        "pytorch_available": False,
        "pytorch_version": None,
        "torchvision_version": None,
        "opencv_version": None,
        "device": "unavailable",
        "medsam_checkpoint_exists": False,
        "medsam_checkpoint_path": None,
        "medsam_checkpoint_size_mb": 0.0,
        "dll_load_error": None,
        "real_medsam_capable": False
    }

    # 1. Check OpenCV
    try:
        import cv2
        info["opencv_version"] = cv2.__version__
    except ImportError as e:
        info["dll_load_error"] = f"OpenCV Import Error: {e}"

    # 2. Check PyTorch & Torchvision
    try:
        import torch
        info["pytorch_available"] = True
        info["pytorch_version"] = torch.__version__
        
        try:
            import torchvision
            info["torchvision_version"] = torchvision.__version__
        except ImportError:
            pass

        if torch.cuda.is_available():
            info["device"] = "cuda"
        else:
            info["device"] = "cpu"

    except (ImportError, OSError) as e:
        info["pytorch_available"] = False
        info["dll_load_error"] = str(e)
        if "WinError 4551" in str(e):
            info["dll_load_error"] = "Windows AppLocker / WDAC Policy Block (WinError 4551): Native PyTorch DLLs are restricted."

    # 3. Check MedSAM Checkpoint
    checkpoint_path = Path("models/medsam_vit_b.pth")
    info["medsam_checkpoint_path"] = str(checkpoint_path)
    if checkpoint_path.exists():
        info["medsam_checkpoint_exists"] = True
        info["medsam_checkpoint_size_mb"] = round(checkpoint_path.stat().st_size / (1024 * 1024), 2)

    # 4. Capability Check
    if info["pytorch_available"] and info["medsam_checkpoint_exists"]:
        info["real_medsam_capable"] = True

    return info

if __name__ == "__main__":
    print("=" * 60)
    print(" SKIN TWIN - MEDSAM ENVIRONMENT DIAGNOSTIC TOOL ")
    print("=" * 60)
    
    info = get_environment_info()
    
    for k, v in info.items():
        print(f"{k.ljust(30)}: {v}")
    
    print("-" * 60)
    if not info["real_medsam_capable"]:
        print("STATUS: BLOCKED / FALLBACK MODE")
        print("REASON:")
        if not info["pytorch_available"]:
            print(f" - PyTorch is unavailable. Error: {info['dll_load_error']}")
            if "WinError 4551" in str(info["dll_load_error"]):
                print("   -> Resolution: Run this backend on Linux, WSL, or an environment without AppLocker restrictions.")
        if not info["medsam_checkpoint_exists"]:
            print(f" - Checkpoint missing at {info['medsam_checkpoint_path']}")
        print("\nThe SkinTwin backend will operate safely using deterministic Fallback CV Segmentation.")
    else:
        print("STATUS: REAL MEDSAM INFERENCE CAPABLE ✅")
    print("=" * 60)
