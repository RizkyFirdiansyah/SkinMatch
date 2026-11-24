from sqlalchemy import (
    Column,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum

class VerdictEnum(str, enum.Enum):
    COCOK = "Cocok"
    TIDAK_COCOK = "Tidak Cocok"

class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("scan_id", name="uq_reviews_scan_id"),)
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=True)
    rating = Column(Integer, nullable=False)  # 1-5 stars
    verdict = Column(SQLEnum(VerdictEnum), nullable=False)  # Cocok / Tidak Cocok
    comment = Column(String(500), nullable=True)  # Max 500 chars
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="reviews")
    product = relationship("Product", back_populates="reviews")
    scan = relationship("Scan", back_populates="review")
    
    def __repr__(self):
        return f"<Review {self.user_id} on {self.product_id}: {self.rating}★ {self.verdict}>"
