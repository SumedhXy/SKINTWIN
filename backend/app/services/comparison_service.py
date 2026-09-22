import json
import logging
from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from fastapi import status

from app.core.errors import NotFoundException, SkinTwinException
from app.models.comparison import Comparison
from app.models.capture import Capture
from app.models.skintwin import SkinTwin
from app.models.user import User
from app.schemas.comparison import (
    ComparisonCreateRequest,
    ComparisonResponse,
)
from app.services.skintwin_service import _get_owned_twin
from app.services.storage import get_storage_adapter
from app.services.alignment_service import AlignmentService
from app.services.segmentation import get_segmentation_model
from app.services.measurement_service import MeasurementService
import numpy as np
import cv2

logger = logging.getLogger(__name__)


from app.services.reliability_evaluator import (
    ComparisonReliabilityEvaluator,
    NON_DIAGNOSTIC_SAFETY_DISCLAIMER,
)


def _build_comparison_response(comp: Comparison, skintwin_public_id: str) -> ComparisonResponse:
    # Parse observable_metrics to extract structured reliability data if present
    structured_rel = {}
    if comp.observable_metrics:
        try:
            obs_data = json.loads(comp.observable_metrics) if isinstance(comp.observable_metrics, str) else comp.observable_metrics
            if isinstance(obs_data, dict):
                structured_rel = obs_data.get("structured_reliability") or {}
        except Exception:
            structured_rel = {}

    overall_rel = structured_rel.get("overall_reliability")
    if not overall_rel:
        if comp.reliability_status == "reliable":
            overall_rel = "high"
        elif comp.reliability_status == "needs_review":
            overall_rel = "moderate"
        elif comp.reliability_status in ["unreliable", "low"]:
            overall_rel = "low"
        elif comp.reliability_status in ["insufficient", "unavailable"]:
            overall_rel = "insufficient"
        else:
            overall_rel = "moderate"

    # Parse uncertainty reasons
    unc_reasons_list: List[str] = []
    if comp.uncertainty_reasons:
        try:
            parsed_unc = json.loads(comp.uncertainty_reasons) if isinstance(comp.uncertainty_reasons, str) else comp.uncertainty_reasons
            if isinstance(parsed_unc, list):
                unc_reasons_list = [str(item) for item in parsed_unc]
            elif isinstance(parsed_unc, str):
                unc_reasons_list = [parsed_unc]
        except Exception:
            unc_reasons_list = [str(comp.uncertainty_reasons)]

    uncertainty_present = structured_rel.get("uncertainty_present")
    if uncertainty_present is None:
        uncertainty_present = overall_rel in ["moderate", "low", "insufficient"] or bool(unc_reasons_list)

    # Component breakdown fallback if not cached
    components = structured_rel.get("components")
    if not components:
        components = {
            "image_quality": {
                "status": "acceptable" if overall_rel in ["high", "moderate"] else "limited",
                "score": 1.0 if overall_rel == "high" else 0.7,
                "details": "Image quality evaluated from capture parameters.",
            },
            "alignment": {
                "status": "high" if comp.alignment_status == "aligned" else ("moderate" if comp.alignment_status == "partially_aligned" else "low"),
                "score": comp.alignment_score,
                "details": f"Alignment score: {comp.alignment_score or 0.0:.2f}",
            },
            "segmentation": {
                "status": "high" if comp.localization_status == "segmented" and comp.segmentation_model != "fallback_cv" else ("moderate" if comp.segmentation_model == "fallback_cv" else "low"),
                "score": comp.localization_confidence,
                "model_name": comp.segmentation_model,
                "fallback_used": comp.segmentation_model == "fallback_cv",
                "details": f"Segmentation model: {comp.segmentation_model or 'unknown'}",
            },
            "measurements": {
                "status": "high" if comp.measurement_status == "measured" and overall_rel in ["high", "moderate"] else "low",
                "details": "Quantitative measurements computed from segmented boundaries.",
            },
        }

    # Signal reliabilities fallback if not cached
    signal_reliabilities = structured_rel.get("signal_reliabilities")
    if not signal_reliabilities:
        signal_reliabilities = [
            {
                "name": "Area",
                "reliability": overall_rel if overall_rel != "insufficient" else "unavailable",
                "uncertainty": overall_rel != "high",
                "interpretation": "Area calculated from segmented region pixel counts.",
            },
            {
                "name": "Shape",
                "reliability": "high" if comp.alignment_status == "aligned" and overall_rel == "high" else "moderate",
                "uncertainty": overall_rel != "high",
                "interpretation": "Shape calculated from contour moments.",
            },
            {
                "name": "Color",
                "reliability": "high" if overall_rel == "high" else "moderate",
                "uncertainty": overall_rel != "high",
                "interpretation": "Color calculated from region color distributions.",
            },
            {
                "name": "Centroid",
                "reliability": "high" if comp.alignment_status == "aligned" else "moderate",
                "uncertainty": comp.alignment_status != "aligned",
                "interpretation": "Centroid position shift calculated in aligned coordinate space.",
            },
            {
                "name": "Segmentation Overlap",
                "reliability": overall_rel if overall_rel != "insufficient" else "unavailable",
                "uncertainty": overall_rel != "high",
                "interpretation": "Overlap computed as mask intersection over union.",
            },
        ]

    return ComparisonResponse(
        id=comp.id,
        skintwin_public_id=skintwin_public_id,
        earlier_capture_id=comp.earlier_capture_id,
        latest_capture_id=comp.latest_capture_id,
        processing_status=comp.processing_status,
        processing_error_code=comp.processing_error_code,
        alignment_status=comp.alignment_status,
        alignment_score=comp.alignment_score,
        match_count=comp.match_count,
        inlier_count=comp.inlier_count,
        inlier_ratio=comp.inlier_ratio,
        alignment_method=comp.alignment_method,
        alignment_error_code=comp.alignment_error_code,
        localization_status=comp.localization_status,
        localization_confidence=comp.localization_confidence,
        segmentation_model=comp.segmentation_model,
        segmentation_model_version=comp.segmentation_model_version,
        segmentation_error_code=comp.segmentation_error_code,
        earlier_area=comp.earlier_area,
        latest_area=comp.latest_area,
        area_change_percent=comp.area_change_percent,
        color_change_metrics=comp.color_change_metrics,
        shape_change_metrics=comp.shape_change_metrics,
        boundary_change_metrics=comp.boundary_change_metrics,
        position_change_metrics=comp.position_change_metrics,
        comparison_status=comp.comparison_status,
        measurement_status=comp.measurement_status,
        reliability_status=comp.reliability_status,
        reliability_score=comp.reliability_score,
        uncertainty_reasons=unc_reasons_list,
        observable_change_summary=comp.observable_change_summary,
        observable_metrics=comp.observable_metrics,
        ai_explanation=comp.ai_explanation,
        comparison_version=comp.comparison_version,
        overall_reliability=overall_rel,
        uncertainty_present=uncertainty_present,
        components=components,
        signal_reliabilities=signal_reliabilities,
        structured_uncertainty_reasons=structured_rel.get("structured_uncertainty_reasons") or [
            {"category": "general", "severity": "low", "message": r} for r in unc_reasons_list
        ],
        affected_signals=structured_rel.get("affected_signals") or [],
        limitations=structured_rel.get("limitations") or [
            "Comparison describes observable image differences, not clinical or medical significance."
        ],
        safety_disclaimer=structured_rel.get("safety_disclaimer") or NON_DIAGNOSTIC_SAFETY_DISCLAIMER,
        analyzed_at=comp.analyzed_at,
        created_at=comp.created_at,
    )



class ComparisonService:

    @staticmethod
    def create(
        db: Session, user: User, skintwin_public_id: str, request: ComparisonCreateRequest
    ) -> ComparisonResponse:
        """
        Validate capture pair ownership, chronology, run OpenCV alignment,
        run MedSAM segmentation, compute observable quantitative metrics, and evaluate reliability.
        """
        # 1. Enforce SkinTwin ownership (raises 404 if not found or wrong user)
        twin = _get_owned_twin(db, skintwin_public_id, user)

        # 2. Check earlier capture existence & ownership
        earlier = (
            db.query(Capture)
            .filter(
                Capture.id == request.earlier_capture_id,
                Capture.skintwin_id == twin.id,
                Capture.user_id == user.id,
            )
            .first()
        )
        if not earlier:
            raise NotFoundException(
                message="Earlier capture not found for this SkinTwin.",
                code="CAPTURE_NOT_FOUND",
            )

        # 3. Check latest capture existence & ownership
        latest = (
            db.query(Capture)
            .filter(
                Capture.id == request.latest_capture_id,
                Capture.skintwin_id == twin.id,
                Capture.user_id == user.id,
            )
            .first()
        )
        if not latest:
            raise NotFoundException(
                message="Latest capture not found for this SkinTwin.",
                code="CAPTURE_NOT_FOUND",
            )

        # 4. Check that captures are not identical
        if earlier.id == latest.id:
            raise SkinTwinException(
                code="SAME_CAPTURE_PAIR",
                message="Earlier capture and latest capture cannot be the same image.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # 5. Check chronology (earlier capture cannot be after latest capture)
        if earlier.captured_at > latest.captured_at:
            raise SkinTwinException(
                code="INVALID_CAPTURE_CHRONOLOGY",
                message="Earlier capture timestamp cannot be later than the latest capture timestamp.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # 6. Load images from private storage
        storage = get_storage_adapter()
        try:
            earlier_bytes = storage.get_file(earlier.image_object_key)
            latest_bytes = storage.get_file(latest.image_object_key)

            earlier_img = cv2.imdecode(np.frombuffer(earlier_bytes, np.uint8), cv2.IMREAD_COLOR)
            latest_img = cv2.imdecode(np.frombuffer(latest_bytes, np.uint8), cv2.IMREAD_COLOR)
        except Exception as e:
            logger.warning(f"Failed to read capture storage images: {e}")
            earlier_img = None
            latest_img = None

        # 7. Run OpenCV Image Alignment Pipeline
        if earlier_img is not None and latest_img is not None:
            align_res = AlignmentService.align_image_pair(earlier_img, latest_img)
            aligned_latest_img = align_res.get("aligned_latest_image")
            if aligned_latest_img is None:
                aligned_latest_img = latest_img
        else:
            align_res = {
                "alignment_status": "unavailable",
                "alignment_score": 0.0,
                "match_count": 0,
                "inlier_count": 0,
                "inlier_ratio": 0.0,
                "alignment_method": "orb_ransac",
                "alignment_error_code": "IMAGE_DECODE_FAILED",
            }
            aligned_latest_img = latest_img

        # 8. Run MedSAM ViT-B Region Segmentation Pipeline
        seg_model = get_segmentation_model()

        if earlier_img is not None:
            earlier_seg = seg_model.predict_region(earlier_img, prompt=request.earlier_prompt)
        else:
            earlier_seg = {"status": "unavailable", "confidence": 0.0, "mask": None, "error_code": "NO_IMAGE"}

        if aligned_latest_img is not None:
            latest_seg = seg_model.predict_region(aligned_latest_img, prompt=request.latest_prompt)
        else:
            latest_seg = {"status": "unavailable", "confidence": 0.0, "mask": None, "error_code": "NO_IMAGE"}

        # Determine overall localization status & confidence
        if earlier_seg.get("status") == "segmented" and latest_seg.get("status") == "segmented":
            loc_status = "segmented"
            loc_conf = round((earlier_seg.get("confidence", 0.0) + latest_seg.get("confidence", 0.0)) / 2.0, 2)
        elif earlier_seg.get("status") == "unavailable" or latest_seg.get("status") == "unavailable":
            loc_status = "unavailable"
            loc_conf = 0.0
        else:
            loc_status = "failed"
            loc_conf = 0.0

        seg_error_code = earlier_seg.get("error_code") or latest_seg.get("error_code")

        # 9. Compute Observable Measurements & Evaluate Reliability / Uncertainty
        earlier_quality = {
            "quality_status": earlier.quality_status,
            "quality_score": earlier.quality_score,
            "blur_status": earlier.blur_status,
            "lighting_status": earlier.lighting_status,
            "resolution_status": earlier.resolution_status,
            "framing_status": earlier.framing_status,
            "quality_details": json.loads(earlier.quality_details) if earlier.quality_details and isinstance(earlier.quality_details, str) else (earlier.quality_details or {}),
        } if earlier else None

        latest_quality = {
            "quality_status": latest.quality_status,
            "quality_score": latest.quality_score,
            "blur_status": latest.blur_status,
            "lighting_status": latest.lighting_status,
            "resolution_status": latest.resolution_status,
            "framing_status": latest.framing_status,
            "quality_details": json.loads(latest.quality_details) if latest.quality_details and isinstance(latest.quality_details, str) else (latest.quality_details or {}),
        } if latest else None

        if earlier_img is not None and latest_img is not None:
            metrics_res = MeasurementService.calculate_metrics(
                earlier_img=earlier_img,
                latest_img=aligned_latest_img,
                earlier_seg=earlier_seg,
                latest_seg=latest_seg,
                alignment_res=align_res,
                earlier_quality=earlier_quality,
                latest_quality=latest_quality,
                segmentation_model_info=seg_model.get_model_info(),
            )
        else:
            metrics_res = {
                "measurement_status": "unavailable",
                "reliability_status": "unavailable",
                "reliability_score": 0.0,
                "uncertainty_reasons": ["Storage image file unreadable"],
                "earlier_area": None,
                "latest_area": None,
                "area_change_percent": None,
                "color_change_metrics": None,
                "shape_change_metrics": None,
                "boundary_change_metrics": None,
                "position_change_metrics": None,
                "observable_change_summary": None,
                "observable_metrics": None,
            }

        now = datetime.now(timezone.utc)

        # 10. Persist Comparison Record into PostgreSQL
        comp = Comparison(
            skintwin_id=twin.id,
            user_id=user.id,
            earlier_capture_id=earlier.id,
            latest_capture_id=latest.id,
            processing_status="completed",
            processing_error_code=None,
            alignment_status=align_res["alignment_status"],
            alignment_score=align_res["alignment_score"],
            match_count=align_res["match_count"],
            inlier_count=align_res["inlier_count"],
            inlier_ratio=align_res["inlier_ratio"],
            alignment_method=align_res["alignment_method"],
            alignment_error_code=align_res["alignment_error_code"],
            localization_status=loc_status,
            localization_confidence=loc_conf,
            segmentation_model=seg_model.get_model_info()["model_name"],
            segmentation_model_version=seg_model.get_model_info()["model_version"],
            segmentation_error_code=seg_error_code,
            earlier_area=metrics_res["earlier_area"],
            latest_area=metrics_res["latest_area"],
            area_change_percent=metrics_res["area_change_percent"],
            color_change_metrics=metrics_res["color_change_metrics"],
            shape_change_metrics=metrics_res["shape_change_metrics"],
            boundary_change_metrics=metrics_res["boundary_change_metrics"],
            position_change_metrics=metrics_res["position_change_metrics"],
            comparison_status="completed",
            measurement_status=metrics_res["measurement_status"],
            reliability_status=metrics_res["reliability_status"],
            reliability_score=metrics_res["reliability_score"],
            uncertainty_reasons=json.dumps(metrics_res["uncertainty_reasons"]),
            observable_change_summary=metrics_res["observable_change_summary"],
            observable_metrics=metrics_res["observable_metrics"],
            ai_explanation=None,
            comparison_version="1.0.0",
            analyzed_at=now,
        )

        db.add(comp)
        db.commit()
        db.refresh(comp)

        return _build_comparison_response(comp, twin.public_id)

    @staticmethod
    def list_for_skintwin(
        db: Session, user: User, skintwin_public_id: str
    ) -> List[ComparisonResponse]:
        """List all comparisons created for a SkinTwin."""
        twin = _get_owned_twin(db, skintwin_public_id, user)
        comps = (
            db.query(Comparison)
            .filter(Comparison.skintwin_id == twin.id)
            .order_by(Comparison.created_at.desc())
            .all()
        )
        return [_build_comparison_response(c, twin.public_id) for c in comps]

    @staticmethod
    def get_by_id(db: Session, user: User, comparison_id: str) -> ComparisonResponse:
        """Get details for a single comparison (ownership enforced)."""
        comp = db.query(Comparison).filter(Comparison.id == comparison_id).first()
        if not comp or comp.user_id != user.id:
            raise NotFoundException(message="Comparison not found.", code="COMPARISON_NOT_FOUND")

        twin = db.query(SkinTwin).filter(SkinTwin.id == comp.skintwin_id).first()
        twin_public_id = twin.public_id if twin else ""
        return _build_comparison_response(comp, twin_public_id)

    @staticmethod
    def delete(db: Session, user: User, comparison_id: str) -> None:
        """Delete a comparison record."""
        comp = db.query(Comparison).filter(Comparison.id == comparison_id).first()
        if not comp or comp.user_id != user.id:
            raise NotFoundException(message="Comparison not found.", code="COMPARISON_NOT_FOUND")

        db.delete(comp)
        db.commit()
