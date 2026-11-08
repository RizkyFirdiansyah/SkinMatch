from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.scan import Scan
from app.schemas.scan import ScanResponse, ScanListResponse
import os
import uuid
import json

router = APIRouter(prefix="/api/scans", tags=["Scans"])

@router.post("", response_model=ScanResponse, status_code=200)
async def create_scan(
    image: UploadFile = File(..., description="Product label image (max 1MB)"),
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
    
    # 1. Validate file size (max 1MB)
    contents = await image.read()
    file_size = len(contents)
    
    if file_size > 1_000_000:  # 1MB
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ukuran file terlalu besar. Maksimal 1MB."
        )
    
    # 2. Save image to disk
    filename = f"{uuid.uuid4()}.jpg"
    upload_dir = "uploads/scans"
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    # Simpan sebagai path URL (forward slash) agar konsisten lintas OS
    image_path = f"{upload_dir}/{filename}"
    
    with open(filepath, "wb") as f:
        f.write(contents)
    
    # 3. DUMMY OCR - Replace dengan Risky's module di Week 6
    dummy_ocr_result = {
        "raw_text": "Aqua, Glycerin, Niacinamide, Hyaluronic Acid, Dimethicone",
        "confidence": 92.3,
        "success": True
    }
    
    # Check if profile completed
    if not current_user.profile_completed or not current_user.skin_type:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Silakan setup profil kulit Anda terlebih dahulu"
        )
    
    # 4. DUMMY ML Classification - Replace dengan Rizky's model di Week 7
    dummy_ml_result = {
        "result": "Cocok",
        "result_code": 0,
        "confidence": 87.5,
        "explanation": f"Produk ini cocok untuk kulit {current_user.skin_type.value} Anda",
        "safe_ingredients": ["Aqua", "Glycerin", "Niacinamide", "Hyaluronic Acid"],
        "risky_ingredients": [],
        "warnings": []
    }
    
    # 5. Save to database
    new_scan = Scan(
        user_id=current_user.id,
        image_path=image_path,
        ocr_raw_text=dummy_ocr_result["raw_text"],
        ocr_confidence=dummy_ocr_result["confidence"],
        classification_result=dummy_ml_result["result"],
        classification_code=dummy_ml_result["result_code"],
        confidence=dummy_ml_result["confidence"]
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
                "raw_text": dummy_ocr_result["raw_text"],
                "confidence": dummy_ocr_result["confidence"],
                "ingredients_detected": 5
            },
            "classification": {
                "result": dummy_ml_result["result"],
                "result_code": dummy_ml_result["result_code"],
                "confidence": dummy_ml_result["confidence"],
                "explanation": dummy_ml_result["explanation"],
                "ingredients_analysis": {
                    "safe": [
                        {"name": ing, "function": "Moisturizing", "risk_level": "safe"}
                        for ing in dummy_ml_result["safe_ingredients"]
                    ],
                    "risky": [],
                    "unknown": []
                },
                "warnings": dummy_ml_result["warnings"],
                "recommendations": "Produk ini aman digunakan untuk tipe kulit Anda"
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
    
    scans = db.query(Scan).filter(
        Scan.user_id == current_user.id
    ).order_by(Scan.created_at.desc()).all()
    
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
                    "has_review": False,  # Future: check dari review table
                    "thumbnail_url": f"/{scan.image_path}"
                }
                for scan in scans
            ],
            "pagination": {
                "total_items": len(scans)
            }
        }
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
                "confidence": scan.confidence
            }
        }
    }