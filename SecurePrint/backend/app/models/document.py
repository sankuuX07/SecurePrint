import enum
from sqlalchemy import Column, Integer, String, Enum, DateTime, func, ForeignKey
from ..core.database import Base

class DocumentStatus(str, enum.Enum):
    PENDING = "PENDING"
    UPLOADED = "UPLOADED"
    ACTIVE = "ACTIVE"
    IN_PRINT_JOB = "IN_PRINT_JOB"
    PRINTED = "PRINTED"
    EXPIRED = "EXPIRED"
    DELETED = "DELETED"
    FAILED = "FAILED"

class Document(Base):
    __tablename__ = "documents"

    id = Column(String, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    original_filename = Column(String, nullable=False)
    storage_key = Column(String, nullable=False)
    mime_type = Column(String, nullable=True)
    file_size = Column(Integer, nullable=True)
    page_count = Column(Integer, nullable=True)
    
    status = Column(Enum(DocumentStatus), default=DocumentStatus.PENDING)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

