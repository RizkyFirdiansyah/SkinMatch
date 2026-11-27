"""Simpan produk: daftar, simpan, hapus.

Satu produk = satu baris `saved_products` per (user_id, scan_id); unique
constraint di tabel menjaga duplikat, endpoint ini idempoten.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database import get_db
from app.models.saved_product import SavedProduct
from app.models.scan import Scan
from app.models.user import User
from app.schemas.scan import ScanResponse

router = APIRouter(prefix="/api/saved-products", tags=["Saved Products"])


def _scan_name(scan: Scan) -> str:
    # ponytail: nama produk belum ada kolomnya; ganti ke scan.product_name
    # begitu Fitur 3 (input nama produk) merge.
    return f"Hasil pindai #{scan.id}"


def _scan_of_user(scan_id: int, user: User, db: Session) -> Scan:
    scan = db.query(Scan).filter(Scan.id == scan_id, Scan.user_id == user.id).first()
    if not scan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scan tidak ditemukan",
        )
    return scan


def _payload(entry: SavedProduct) -> dict:
    scan = entry.scan
    return {
        "saved_id": entry.id,
        "saved_at": entry.created_at.isoformat() if entry.created_at else None,
        "scan_id": scan.id,
        "timestamp": scan.created_at.isoformat() if scan.created_at else None,
        "product_name": _scan_name(scan),
        "brand": None,
        "result": scan.classification_result,
        "confidence": scan.confidence,
        "has_review": False,
        "thumbnail_url": f"/{scan.image_path}",
    }


@router.get("", response_model=ScanResponse)
def list_saved_products(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Daftar produk tersimpan, terbaru dulu."""
    entries = (
        db.query(SavedProduct)
        .filter(SavedProduct.user_id == current_user.id)
        .order_by(SavedProduct.created_at.desc(), SavedProduct.id.desc())
        .all()
    )
    return {
        "status": "success",
        "data": {
            "saved_products": [_payload(entry) for entry in entries],
            "total_items": len(entries),
        },
    }


@router.post("/{scan_id}", response_model=ScanResponse)
def save_product(
    scan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Simpan produk hasil scan. Idempoten: simpan ulang tidak bikin duplikat."""
    scan = _scan_of_user(scan_id, current_user, db)

    existing = (
        db.query(SavedProduct)
        .filter(SavedProduct.user_id == current_user.id, SavedProduct.scan_id == scan.id)
        .first()
    )
    if existing:
        return {
            "status": "success",
            "message": "Produk sudah tersimpan",
            "data": {"saved_id": existing.id, "scan_id": scan.id},
        }

    entry = SavedProduct(user_id=current_user.id, scan_id=scan.id)
    db.add(entry)
    try:
        db.commit()
    except IntegrityError:
        # Balapan dua request simpan bersamaan: constraint yang menang.
        db.rollback()
        existing = (
            db.query(SavedProduct)
            .filter(SavedProduct.user_id == current_user.id, SavedProduct.scan_id == scan.id)
            .first()
        )
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Gagal menyimpan produk",
            )
        return {
            "status": "success",
            "message": "Produk sudah tersimpan",
            "data": {"saved_id": existing.id, "scan_id": scan.id},
        }

    db.refresh(entry)
    return {
        "status": "success",
        "message": "Produk disimpan",
        "data": {"saved_id": entry.id, "scan_id": scan.id},
    }


@router.delete("/{scan_id}", response_model=ScanResponse)
def unsave_product(
    scan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Hapus produk dari daftar simpanan."""
    entry = (
        db.query(SavedProduct)
        .filter(SavedProduct.user_id == current_user.id, SavedProduct.scan_id == scan_id)
        .first()
    )
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Produk tidak ada di daftar simpanan",
        )

    db.delete(entry)
    db.commit()
    return {
        "status": "success",
        "message": "Produk dihapus dari daftar simpanan",
        "data": {"scan_id": scan_id},
    }
