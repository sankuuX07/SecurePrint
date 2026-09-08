import enum
import uuid
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Enum, func
from sqlalchemy.orm import relationship
from ..core.database import Base

class TemporaryAccessStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    REVOKED = "REVOKED"

class TemporaryDocumentAccess(Base):
    __tablename__ = "temporary_document_access"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    print_job_id = Column(Integer, ForeignKey("print_jobs.id"), nullable=False, index=True)
    document_id = Column(String, ForeignKey("documents.id"), nullable=False, index=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    
    status = Column(Enum(TemporaryAccessStatus), default=TemporaryAccessStatus.ACTIVE, nullable=False, index=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    
    last_accessed_at = Column(DateTime(timezone=True), nullable=True)
    access_count = Column(Integer, default=0, nullable=False)
    
    print_job = relationship("PrintJob")
    document = relationship("Document")
    shop = relationship("Shop")
