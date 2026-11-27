from sqlalchemy import Column, Integer, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class SavedProduct(Base):
    __tablename__ = "saved_products"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="saved_products")
    scan = relationship("Scan")

    __table_args__ = (
        UniqueConstraint("user_id", "scan_id", name="uq_saved_products_user_scan"),
    )

    def __repr__(self):
        return f"<SavedProduct user={self.user_id} scan={self.scan_id}>"
