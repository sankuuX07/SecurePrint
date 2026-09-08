import enum
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func, Text
from sqlalchemy.orm import relationship
from ..core.database import Base

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    event_type = Column(String, nullable=False, index=True)
    
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    document_id = Column(String, ForeignKey("documents.id"), nullable=True, index=True)
    print_job_id = Column(Integer, ForeignKey("print_jobs.id"), nullable=True, index=True)
    
    extra_metadata = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    user = relationship("User")
    document = relationship("Document")
    print_job = relationship("PrintJob")
