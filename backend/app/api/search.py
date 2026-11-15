from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from app.database import get_db
from app.models.product import Product
from app.models.category import Category


router = APIRouter(prefix="/api/search", tags=["Search"])


@router.get("/products")
def search_products(
    brand: Optional[str] = Query(None, description="Filter by brand (partial match)"),
    category: Optional[str] = Query(None, description="Filter by category slug"),
    keyword: Optional[str] = Query(None, description="Search in product name"),
    limit: int = Query(10, ge=1, le=50, description="Results per page"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    db: Session = Depends(get_db)
):
    """
    Cari produk skincare berdasarkan brand, kategori, atau keyword.
    
    **Contoh:**
    - `/api/search/products?brand=Wardah` - Semua produk Wardah
    - `/api/search/products?category=serum` - Semua serum
    - `/api/search/products?keyword=brightening` - Produk dengan kata "brightening"
    - `/api/search/products?brand=Wardah&category=serum` - Serum Wardah saja
    - `/api/search/products?limit=20&offset=0` - Pagination
    """
    # Base query dengan join category
    query = db.query(Product).join(Category)
    
    # Filter by brand (case insensitive, partial match)
    if brand:
        query = query.filter(Product.brand.ilike(f"%{brand}%"))
    
    # Filter by category slug
    if category:
        query = query.filter(Category.slug == category)
    
    # Search by keyword in product name
    if keyword:
        query = query.filter(Product.name.ilike(f"%{keyword}%"))
    
    # Count total results (before pagination)
    total = query.count()
    
    # Apply pagination
    products = query.limit(limit).offset(offset).all()
    
    # Format response
    results = []
    for p in products:
        results.append({
            "id": p.id,
            "name": p.name,
            "brand": p.brand,
            "category": p.category.name,
            "category_slug": p.category.slug,
            "image_url": p.image_url,
            "bpom_number": p.bpom_number,
            "price": float(p.price) if p.price else None
        })
    
    return {
        "success": True,
        "message": f"Ditemukan {total} produk",
        "data": {
            "products": results,
            "pagination": {
                "total": total,
                "limit": limit,
                "offset": offset,
                "has_more": (offset + limit) < total
            }
        }
    }


@router.get("/products/{product_id}")
def get_product_detail(
    product_id: int,
    db: Session = Depends(get_db)
):
    """
    Detail produk lengkap (termasuk ingredients).
    """
    product = db.query(Product).filter(Product.id == product_id).first()
    
    if not product:
        raise HTTPException(
            status_code=404,
            detail="Produk tidak ditemukan"
        )
    
    return {
        "success": True,
        "data": {
            "id": product.id,
            "name": product.name,
            "brand": product.brand,
            "category": product.category.name,
            "category_slug": product.category.slug,
            "description": product.description,
            "ingredients": product.ingredients_text.split(", ") if product.ingredients_text else [],
            "image_url": product.image_url,
            "bpom_number": product.bpom_number,
            "price": float(product.price) if product.price else None,
            "created_at": product.created_at.isoformat()
        }
    }


@router.get("/categories")
def get_categories(db: Session = Depends(get_db)):
    """
    Daftar semua kategori produk.
    """
    categories = db.query(Category).all()
    
    return {
        "success": True,
        "data": {
            "categories": [
                {
                    "id": c.id,
                    "name": c.name,
                    "slug": c.slug
                }
                for c in categories
            ]
        }
    }


@router.get("/brands")
def get_brands(db: Session = Depends(get_db)):
    """
    Daftar semua brand yang ada di database (distinct).
    """
    # Query distinct brands
    brands = db.query(Product.brand).distinct().order_by(Product.brand).all()
    
    return {
        "success": True,
        "data": {
            "brands": [b[0] for b in brands]  # Unpack tuple
        }
    }