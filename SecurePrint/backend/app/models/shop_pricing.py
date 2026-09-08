from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import relationship
from ..core.database import Base

class ShopPricing(Base):
    __tablename__ = "shop_pricing"

    id = Column(Integer, primary_key=True, index=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    
    paper_size = Column(String, nullable=False) # e.g. 'A4', 'A3'
    color_mode = Column(String, nullable=False) # e.g. 'B/W', 'Color'
    print_side = Column(String, nullable=False) # e.g. 'Single', 'Double'
    price_per_sheet = Column(Float, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    shop = relationship("Shop", back_populates="pricing")

    __table_args__ = (
        UniqueConstraint('shop_id', 'paper_size', 'color_mode', 'print_side', name='uix_shop_pricing'),
    )
