from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional
from ..models.document import DocumentStatus

class DocumentBase(BaseModel):
    id: str
    original_filename: str
    mime_type: Optional[str] = None
    file_size: Optional[int] = None
    page_count: Optional[int] = None
    status: DocumentStatus
    created_at: datetime
    expires_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None

class DocumentResponse(DocumentBase):

    model_config = ConfigDict(from_attributes=True)
