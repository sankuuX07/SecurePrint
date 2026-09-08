from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func, Enum
from sqlalchemy.orm import relationship
from ..core.database import Base
from .print_job import PrintJobStatus

class PrintJobStatusHistory(Base):
    __tablename__ = "print_job_status_history"

    id = Column(Integer, primary_key=True, index=True)
    print_job_id = Column(Integer, ForeignKey("print_jobs.id"), nullable=False, index=True)
    from_status = Column(Enum(PrintJobStatus), nullable=True)
    to_status = Column(Enum(PrintJobStatus), nullable=False)
    changed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    changed_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    notes = Column(String, nullable=True)

    print_job = relationship("PrintJob", back_populates="status_history")
    changer = relationship("User")
