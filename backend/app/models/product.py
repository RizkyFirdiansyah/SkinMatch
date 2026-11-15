from sqlalchemy import Column, Integer, String, Text, ForeignKey, Numeric, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Product(Base):
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    brand = Column(String(100), nullable=False, index=True)  # Index untuk search by brand
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)
    description = Column(Text, nullable=True)
    ingredients_text = Column(Text, nullable=False)  # Comma-separated ingredients
    image_url = Column(String(500), nullable=True)
    bpom_number = Column(String(50), nullable=True, index=True)  # Nomor registrasi BPOM
    price = Column(Numeric(10, 2), nullable=True)  # Harga (opsional)
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    category = relationship("Category", back_populates="products")
    scans = relationship("Scan", back_populates="product")
    reviews = relationship("Review", back_populates="product")
    
    def __repr__(self):
        return f"<Product {self.brand} - {self.name}>"