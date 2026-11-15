from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import enum

class SkinTypeEnum(str, enum.Enum):
    NORMAL = "Normal"
    KERING = "Kering"
    BERMINYAK = "Berminyak"
    SENSITIF = "Sensitif"

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    skin_type = Column(Enum(SkinTypeEnum), nullable=True)
    profile_completed = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    scans = relationship("Scan", back_populates="user")
    reviews = relationship("Review", back_populates="user")