from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from ..core.database import get_db
from .users import get_current_user
from ..models.user import User, UserRole
from ..services.temporary_access_service import TemporaryDocumentAccessService
from ..services.secure_token_service import SecureTokenService
from ..services.storage import get_file_path

router = APIRouter(prefix="/shop/document-access", tags=["shop_document_access"])

class TemporaryDocumentAccessResponse(BaseModel):
    id: str
    print_job_id: int
    document_id: str
    status: str
    expires_at: datetime
    
    class Config:
        from_attributes = True

class TokenRequest(BaseModel):
    token: str

@router.post("/test-grant/{job_id}", response_model=TemporaryDocumentAccessResponse)
def test_grant_temporary_access(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Development-only endpoint to simulate the future Phase 9 QR authorization.
    In production, this endpoint should be disabled or replaced by QR logic.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    access = TemporaryDocumentAccessService.grant_access(db, job_id, current_user)
    return access

@router.post("/authorize")
def authorize_secure_access(
    req: TokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Shop scans the Secure Access QR and posts the raw token here.
    Validates token and returns a newly granted TemporaryDocumentAccess if successful.
    """
    return SecureTokenService.validate_token(db, req.token, current_user)

@router.get("/{access_id}", response_model=TemporaryDocumentAccessResponse)
def get_temporary_access_metadata(
    access_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get the status and metadata of the access record without downloading the document.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    access = TemporaryDocumentAccessService.validate_access(db, access_id, current_user)
    return access

@router.get("/{access_id}/download")
def download_temporary_document(
    access_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Securely stream the document if access is valid.
    Never exposes storage paths or permanent URLs.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    access = TemporaryDocumentAccessService.validate_access(db, access_id, current_user)
    
    # Validated, stream the file
    from ..models.document import Document
    doc = db.query(Document).filter(Document.id == access.document_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
        
    file_path = get_file_path(doc.storage_key)
    
    TemporaryDocumentAccessService.record_access_usage(db, access, current_user)
    
    # Use FileResponse to stream the file safely, specifying media type and download filename
    return FileResponse(
        path=file_path,
        media_type=doc.mime_type or "application/octet-stream",
        filename=doc.original_filename
    )
