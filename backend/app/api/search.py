from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import or_
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
    search_in: str = Query("name", description="Search in all, name, brand, or ingredient"),
    categories: Optional[str] = Query(None, description="Comma-separated category slugs"),
    brands: Optional[str] = Query(None, description="Comma-separated exact brand names"),
    min_price: Optional[float] = Query(None, ge=0),
    max_price: Optional[float] = Query(None, ge=0),
    include_ingredients: Optional[str] = Query(
        None, description="Comma-separated ingredients that must be present"
    ),
    exclude_ingredients: Optional[str] = Query(
        None, description="Comma-separated ingredients that must be absent"
    ),
    sort_by: str = Query("name", description="Sort by name, price_asc, or price_desc"),
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
    valid_search_fields = {"all", "name", "brand", "ingredient"}
    if search_in not in valid_search_fields:
        raise HTTPException(status_code=400, detail="search_in tidak valid")

    valid_sorts = {"name", "price_asc", "price_desc"}
    if sort_by not in valid_sorts:
        raise HTTPException(status_code=400, detail="sort_by tidak valid")

    if min_price is not None and max_price is not None and min_price > max_price:
        raise HTTPException(
            status_code=400,
            detail="Harga minimum tidak boleh melebihi harga maksimum",
        )

    def split_values(value: Optional[str]) -> list[str]:
        if not value:
            return []
        return [part.strip() for part in value.split(",") if part.strip()]

    # Base query dengan join category
    query = db.query(Product).join(Category)

    # Filter by brand (case insensitive, partial match)
    if brand:
        query = query.filter(Product.brand.ilike(f"%{brand}%"))

    # Filter by category slug
    if category:
        query = query.filter(Category.slug == category)

    selected_categories = split_values(categories)
    if selected_categories:
        query = query.filter(Category.slug.in_(selected_categories))

    selected_brands = split_values(brands)
    if selected_brands:
        query = query.filter(Product.brand.in_(selected_brands))

    # Search by keyword in selected product fields
    if keyword:
        term = f"%{keyword.strip()}%"
        if search_in == "name":
            query = query.filter(Product.name.ilike(term))
        elif search_in == "brand":
            query = query.filter(Product.brand.ilike(term))
        elif search_in == "ingredient":
            query = query.filter(Product.ingredients_text.ilike(term))
        else:
            query = query.filter(
                or_(
                    Product.name.ilike(term),
                    Product.brand.ilike(term),
                    Product.ingredients_text.ilike(term),
                )
            )

    for ingredient in split_values(include_ingredients):
        query = query.filter(Product.ingredients_text.ilike(f"%{ingredient}%"))

    for ingredient in split_values(exclude_ingredients):
        query = query.filter(~Product.ingredients_text.ilike(f"%{ingredient}%"))

    if min_price is not None:
        query = query.filter(Product.price >= min_price)
    if max_price is not None:
        query = query.filter(Product.price <= max_price)

    # Count total results (before pagination)
    total = query.count()

    if sort_by == "price_asc":
        query = query.order_by(Product.price.asc(), Product.name.asc())
    elif sort_by == "price_desc":
        query = query.order_by(Product.price.desc(), Product.name.asc())
    else:
        query = query.order_by(Product.name.asc())

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
            "price": float(p.price) if p.price is not None else None,
            "ingredients": [
                ingredient.strip()
                for ingredient in (p.ingredients_text or "").split(",")
                if ingredient.strip()
            ],
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