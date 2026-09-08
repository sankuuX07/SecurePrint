import enum
from sqlalchemy import Column, Integer, String, Float, Enum, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from ..core.database import Base

class PrintJobStatus(str, enum.Enum):
    CREATED = "CREATED"
    SENT_TO_SHOP = "SENT_TO_SHOP"
    ACCEPTED = "ACCEPTED"
    PRINTING = "PRINTING"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class PrintJob(Base):
    __tablename__ = "print_jobs"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    document_id = Column(String, ForeignKey("documents.id"), nullable=False)
    
    copies = Column(Integer, nullable=False, default=1)
    page_range = Column(String, nullable=True) 
    color_mode = Column(String, nullable=False) 
    paper_size = Column(String, nullable=False) 
    print_side = Column(String, nullable=False) 
    orientation = Column(String, nullable=False, default="Portrait") 
    selected_page_count = Column(Integer, nullable=True)
    
    binding = Column(String, nullable=True)
    stapling = Column(String, nullable=True)
    
    price = Column(Float, nullable=False)
    status = Column(Enum(PrintJobStatus), default=PrintJobStatus.CREATED)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    printing_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)

    customer = relationship("User", foreign_keys=[customer_id])
    shop = relationship("Shop", foreign_keys=[shop_id])
    document = relationship("Document")
    status_history = relationship("PrintJobStatusHistory", back_populates="print_job", cascade="all, delete-orphan")
