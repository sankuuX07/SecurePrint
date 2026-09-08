import enum
from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from ..core.database import Base

class QRStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    REVOKED = "REVOKED"

class ShopQrCode(Base):
    __tablename__ = "shop_qr_codes"

    id = Column(Integer, primary_key=True, index=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    qr_identifier = Column(String, unique=True, nullable=False, index=True)
    status = Column(Enum(QRStatus), default=QRStatus.ACTIVE)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    revoked_at = Column(DateTime(timezone=True), nullable=True)

    shop = relationship("Shop", backref="qr_codes")
