from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.review import Review, VerdictEnum
from app.models.scan import Scan
from app.schemas.review import ScanReviewRequest
from app.schemas.scan import ScanResponse, ScanListResponse
import os
import uuid
import joblib
import json
import numpy as np
import cv2
import threading
from pathlib import Path
from app.skinmatch_ml.ocr.engine import create_ocr, extract_text
from app.skinmatch_ml.text.extract import LexiconMatcher
from app.skinmatch_ml.classify.model import predict_scores

router = APIRouter(prefix="/api/scans", tags=["Scans"])

# Global ML State
_ml_state = {
    "ocr": None,
    "matcher": None,
    "clf": None,
    "labels_config": None,
    "initialized": False
}
_lock = threading.Lock()

def _ensure_initialized():
    with _lock:
        if _ml_state["initialized"]:
            return
        
        # Load OCR
        _ml_state["ocr"] = create_ocr(tier="small")
        
        # Load Lexicon
        lex_path = Path("data/lexicon/lexicon_v1.csv")
        alias_path = Path("data/lexicon/alias_v1.csv")
        _ml_state["matcher"] = LexiconMatcher.from_files(lex_path, alias_path)
        
        # Map skinmatch_ml to app.skinmatch_ml for joblib unpickling compatibility
        import sys
        import app.skinmatch_ml
        import app.skinmatch_ml.classify
        import app.skinmatch_ml.classify.model
        import app.skinmatch_ml.text
        import app.skinmatch_ml.ocr
        
        sys.modules['skinmatch_ml'] = app.skinmatch_ml
        sys.modules['skinmatch_ml.classify'] = app.skinmatch_ml.classify
        sys.modules['skinmatch_ml.classify.model'] = app.skinmatch_ml.classify.model
        sys.modules['skinmatch_ml.text'] = app.skinmatch_ml.text
        sys.modules['skinmatch_ml.ocr'] = app.skinmatch_ml.ocr

        # Load Model
        _ml_state["clf"] = joblib.load("models/model.joblib")
        with open("models/labels.json", "r", encoding="utf-8") as f:
            _ml_state["labels_config"] = json.load(f)
            
        _ml_state["initialized"] = True

MAX_FILE_SIZE = 2 * 1024 * 1024  # 2MB

# Allowed image types
ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp"
}

@router.post("", response_model=ScanResponse, status_code=200)
async def create_scan(
    image: UploadFile = File(..., description="Product label image (max 2MB)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload & analyze product image
    
    Flow:
    1. Validate file size
    2. Save image
    3. OCR extraction (DUMMY for now - will integrate Risky's module)
    4. ML classification (DUMMY for now - will integrate Rizky's model)
    5. Save to database
    6. Return result
    """
    
    # 1. Validate file size (max 2MB)
    contents = await image.read()
    file_size = len(contents)
    
    # Validate file type
    if image.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Format file tidak didukung. Gunakan JPG, PNG, atau WEBP."
        )
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ukuran file terlalu besar. Maksimal 2MB."
        )

    # Check if profile completed
    if not current_user.profile_completed or not current_user.skin_type:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Silakan setup profil kulit Anda terlebih dahulu"
        )

    # 2. Save image to disk
    extension = "jpg" if image.content_type in {"image/jpeg", "image/jpg"} else image.content_type.split("/")[-1]
    filename = f"{uuid.uuid4()}.{extension}"
    upload_dir = "uploads/scans"
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    # Simpan sebagai path URL (forward slash) agar konsisten lintas OS
    image_path = f"{upload_dir}/{filename}"
    
    with open(filepath, "wb") as f:
        f.write(contents)
    
    # 3. Real OCR & Lexicon Extraction
    _ensure_initialized()
    
    img = cv2.imdecode(np.frombuffer(contents, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Gambar tidak dapat dibaca"
        )
    
    try:
        ocr_output = _ml_state["ocr"].predict(img)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OCR gagal: {type(exc).__name__}"
        ) from exc
        
    texts, scores = extract_text(ocr_output)
    raw_text = "\n".join(texts)
    ocr_confidence = float(np.mean(scores) * 100) if scores else 0.0
    
    # Extract ingredients using LexiconMatcher
    extracted_ingredients = _ml_state["matcher"].extract(raw_text)
    
    # 4. ML Classification using model.joblib
    text_for_clf = ", ".join(extracted_ingredients)
    scores_array = predict_scores(_ml_state["clf"], [text_for_clf])[0]
    
    skin_type_map = {
        "Normal": "Normal",
        "Kering": "Kering",
        "Sensitif": "Sensitif",
        "Berminyak": "Berminyak_Berjerawat"
    }
    user_label = skin_type_map.get(current_user.skin_type.value, "Normal")
    labels = _ml_state["labels_config"]["labels"]
    
    try:
        label_idx = labels.index(user_label)
        user_score = float(scores_array[label_idx])
    except (ValueError, IndexError):
        user_score = 0.5
        
    threshold = _ml_state["labels_config"]["thresholds"].get(user_label, 0.5)
    is_suitable = user_score >= threshold
    
    ml_result = "Cocok" if is_suitable else "Tidak Cocok"
    ml_code = 0 if is_suitable else 1
    confidence = round(user_score * 100, 1)
    
    explanation = f"Produk ini {'cocok' if is_suitable else 'kurang cocok'} untuk kulit {current_user.skin_type.value} Anda berdasarkan analisis bahan aktif."
    
    safe_list = [{"name": ing, "function": "Active / Ingredient", "risk_level": "safe"} for ing in extracted_ingredients]
    ingredients_analysis = {
        "safe": safe_list,
        "risky": [],
        "unknown": []
    }
    warnings = [] if is_suitable else ["Komposisi bahan kurang selaras dengan tipe kulit Anda."]
    
    classification_details = {
        "explanation": explanation,
        "ingredients_analysis": ingredients_analysis,
        "warnings": warnings,
        "recommendations": "Produk ini aman digunakan" if is_suitable else "Disarankan konsultasi atau pilih produk lain yang lebih sesuai."
    }

    # 5. Save to database
    new_scan = Scan(
        user_id=current_user.id,
        image_path=image_path,
        ocr_raw_text=raw_text,
        ocr_confidence=ocr_confidence,
        classification_result=ml_result,
        classification_code=ml_code,
        confidence=confidence,
        classification_details=classification_details
    )
    
    db.add(new_scan)
    db.commit()
    db.refresh(new_scan)
    
    # 6. Return result
    return {
        "status": "success",
        "data": {
            "scan_id": new_scan.id,
            "user_id": current_user.id,
            "timestamp": new_scan.created_at.isoformat(),
            "image_url": f"/{image_path}",
            "ocr_result": {
                "raw_text": raw_text,
                "confidence": ocr_confidence,
                "ingredients_detected": len(extracted_ingredients)
            },
            "classification": {
                "result": ml_result,
                "result_code": ml_code,
                "confidence": confidence,
                "explanation": explanation,
                "ingredients_analysis": ingredients_analysis,
                "warnings": warnings,
                "recommendations": classification_details["recommendations"]
            }
        }
    }

@router.get("", response_model=ScanListResponse)
def get_scans(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get scan history for current user
    - Sorted by newest first
    """
    
    scans = (
        db.query(Scan)
        .options(joinedload(Scan.review))
        .filter(Scan.user_id == current_user.id)
        .order_by(Scan.created_at.desc())
        .all()
    )
    
    return {
        "status": "success",
        "data": {
            "scans": [
                {
                    "scan_id": scan.id,
                    "timestamp": scan.created_at.isoformat(),
                    "product_name": "Unknown Product",  # Future: extract dari product catalog
                    "brand": None,
                    "result": scan.classification_result,
                    "confidence": scan.confidence,
                    "has_review": scan.review is not None,
                    "review": (
                        {
                            "rating": scan.review.rating,
                            "verdict": scan.review.verdict.value,
                            "comment": scan.review.comment,
                            "reviewed_at": scan.review.created_at.isoformat(),
                        }
                        if scan.review is not None
                        else None
                    ),
                    "thumbnail_url": f"/{scan.image_path}"
                }
                for scan in scans
            ],
            "pagination": {
                "total_items": len(scans)
            }
        }
    }

@router.put("/{scan_id}/review")
def save_scan_review(
    scan_id: int,
    review_data: ScanReviewRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    scan = (
        db.query(Scan)
        .filter(Scan.id == scan_id, Scan.user_id == current_user.id)
        .with_for_update()
        .first()
    )
    if not scan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scan tidak ditemukan",
        )

    review = db.query(Review).filter(Review.scan_id == scan.id).first()
    verdict = (
        VerdictEnum.COCOK
        if review_data.verdict == VerdictEnum.COCOK.value
        else VerdictEnum.TIDAK_COCOK
    )
    comment = review_data.comment.strip() if review_data.comment else None
    if review is None:
        review = Review(
            user_id=current_user.id,
            product_id=scan.product_id,
            scan_id=scan.id,
            rating=review_data.rating,
            verdict=verdict,
            comment=comment or None,
        )
        db.add(review)
    else:
        review.rating = review_data.rating
        review.verdict = verdict
        review.comment = comment or None

    db.commit()
    db.refresh(review)

    return {
        "status": "success",
        "data": {
            "scan_id": scan.id,
            "review_id": review.id,
            "rating": review.rating,
            "verdict": review.verdict.value,
            "comment": review.comment,
            "reviewed_at": review.created_at.isoformat(),
        },
    }

@router.delete("/{scan_id}/review")
def delete_scan_review(
    scan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    scan = (
        db.query(Scan)
        .filter(Scan.id == scan_id, Scan.user_id == current_user.id)
        .with_for_update()
        .first()
    )
    if not scan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scan tidak ditemukan",
        )

    review = db.query(Review).filter(Review.scan_id == scan.id).first()
    if review is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ulasan tidak ditemukan",
        )

    db.delete(review)
    db.commit()
    return {
        "status": "success",
        "data": {
            "scan_id": scan.id,
            "deleted": True,
        },
    }

@router.get("/{scan_id}", response_model=ScanResponse)
def get_scan_detail(
    scan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get scan detail by ID
    - Only accessible by owner
    """
    
    scan = db.query(Scan).filter(
        Scan.id == scan_id,
        Scan.user_id == current_user.id
    ).first()
    
    if not scan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scan tidak ditemukan"
        )

    classification_details = scan.classification_details or {}

    return {
        "status": "success",
        "data": {
            "scan_id": scan.id,
            "user_id": scan.user_id,
            "timestamp": scan.created_at.isoformat(),
            "image_url": f"/{scan.image_path}",
            "ocr_result": {
                "raw_text": scan.ocr_raw_text,
                "confidence": scan.ocr_confidence
            },
            "classification": {
                "result": scan.classification_result,
                "result_code": scan.classification_code,
                "confidence": scan.confidence,
                **classification_details
            }
        }
    }