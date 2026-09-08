import enum
from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, func, Numeric
from sqlalchemy.orm import relationship
from ..core.database import Base

class PaymentStatus(str, enum.Enum):
    UNPAID = "UNPAID"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

class PaymentMethod(str, enum.Enum):
    PAY_AT_SHOP = "PAY_AT_SHOP"
    ONLINE = "ONLINE"

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    print_job_id = Column(Integer, ForeignKey("print_jobs.id"), nullable=False, index=True, unique=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False)
    
    amount = Column(Numeric(10, 2), nullable=False)
    currency = Column(String, default="INR")
    status = Column(Enum(PaymentStatus), default=PaymentStatus.UNPAID)
    method = Column(Enum(PaymentMethod), default=PaymentMethod.PAY_AT_SHOP)
    
    transaction_reference = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    paid_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    print_job = relationship("PrintJob", backref="payment")
