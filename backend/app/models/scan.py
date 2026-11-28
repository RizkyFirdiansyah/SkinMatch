from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, Float, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class Scan(Base):
    __tablename__ = "scans"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    product_name = Column(String(150), nullable=True)  # nama bebas dari user, boleh sama
    image_path = Column(String(255), nullable=False)
    
    # OCR results
    ocr_raw_text = Column(Text, nullable=True)
    ocr_confidence = Column(Float, nullable=True)
    
    # ML results
    classification_result = Column(String(20), nullable=True)  # "Cocok" or "Tidak Cocok"
    classification_code = Column(Integer, nullable=True)  # 0 or 1
    confidence = Column(Float, nullable=True)
    classification_details = Column(JSON, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="scans")
    product = relationship("Product", back_populates="scans")