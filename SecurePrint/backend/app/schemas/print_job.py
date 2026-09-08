from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional, List
from ..models.print_job import PrintJobStatus

class PrintJobBase(BaseModel):
    document_id: str
    shop_id: int
    copies: int
    page_range: Optional[str] = None
    color_mode: str
    paper_size: str
    print_side: str
    orientation: str = "Portrait"
    binding: Optional[str] = None
    stapling: Optional[str] = None

class PrintJobCreate(PrintJobBase):
    pass

class PrintJobResponse(PrintJobBase):
    id: int
    customer_id: int
    price: float
    status: PrintJobStatus
    created_at: datetime
    accepted_at: Optional[datetime] = None
    printing_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    selected_page_count: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)

class PrintJobStatusHistoryResponse(BaseModel):
    id: int
    from_status: Optional[PrintJobStatus] = None
    to_status: PrintJobStatus
    changed_at: datetime
    notes: Optional[str] = None
    
    model_config = ConfigDict(from_attributes=True)

class PrintJobDetailResponse(PrintJobResponse):
    status_history: List[PrintJobStatusHistoryResponse] = []
