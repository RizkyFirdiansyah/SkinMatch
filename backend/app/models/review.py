from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum

class VerdictEnum(str, enum.Enum):
    COCOK = "Cocok"
    TIDAK_COCOK = "Tidak Cocok"

class Review(Base):
    __tablename__ = "reviews"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=True)  # Opsional: review dari scan mana
    rating = Column(Integer, nullable=False)  # 1-5 stars
    verdict = Column(SQLEnum(VerdictEnum), nullable=False)  # Cocok / Tidak Cocok
    comment = Column(String(500), nullable=True)  # Max 500 chars
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="reviews")
    product = relationship("Product", back_populates="reviews")
    scan = relationship("Scan")
    
    def __repr__(self):
        return f"<Review {self.user_id} on {self.product_id}: {self.rating}★ {self.verdict}>"
