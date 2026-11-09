from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ProductBase(BaseModel):
    name: str
    brand: str
    category_id: int
    description: Optional[str] = None
    ingredients_text: str
    image_url: Optional[str] = None
    bpom_number: Optional[str] = None
    price: Optional[float] = None


class ProductCreate(ProductBase):
    pass


class ProductResponse(ProductBase):
    id: int
    created_at: datetime
    category_name: str  # Dari join
    
    class Config:
        from_attributes = True


class ProductListItem(BaseModel):
    """Response untuk list produk (tanpa ingredients)"""
    id: int
    name: str
    brand: str
    category_name: str
    image_url: Optional[str] = None
    bpom_number: Optional[str] = None
    price: Optional[float] = None
    
    class Config:
        from_attributes = True