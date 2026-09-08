import uuid
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models.user import User
from ..models.document import Document, DocumentStatus
from ..schemas.document import DocumentResponse
from ..services.storage import save_upload_file
from .users import get_current_user

router = APIRouter(prefix="/documents", tags=["documents"])

@router.post("/", response_model=DocumentResponse)
async def upload_document(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    storage_key = await save_upload_file(file)
    
    # Get actual path to calculate pages and file size
    from ..services.storage import get_file_path
    from ..services.page_counter import count_pages
    import os
    
    file_path = get_file_path(storage_key)
    try:
        page_count = await count_pages(file, file_path)
    except ValueError as e:
        os.remove(file_path)
        raise HTTPException(status_code=400, detail=str(e))
        
    file_size = os.path.getsize(file_path)
    
    document_id = str(uuid.uuid4())
    db_document = Document(
        id=document_id,
        owner_id=current_user.id,
        original_filename=file.filename,
        storage_key=storage_key,
        mime_type=file.content_type,
        file_size=file_size,
        page_count=page_count,
        status=DocumentStatus.ACTIVE,
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    
    return db_document

@router.get("/", response_model=List[DocumentResponse])
def get_documents(
    status: Optional[DocumentStatus] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Enforce ownership: users can only list their own documents
    page_size = min(page_size, 100)
    query = db.query(Document).filter(Document.owner_id == current_user.id)
    
    if status:
        query = query.filter(Document.status == status)
    if search:
        query = query.filter(Document.original_filename.ilike(f"%{search}%"))
        
    query = query.order_by(Document.created_at.desc())
    docs = query.offset((page - 1) * page_size).limit(page_size).all()
    return docs

@router.get("/{document_id}", response_model=DocumentResponse)
def get_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    doc = db.query(Document).filter(Document.id == document_id, Document.owner_id == current_user.id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    return doc

@router.delete("/{document_id}")
def delete_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from ..models.print_job import PrintJob, PrintJobStatus
    from ..services.storage import delete_file

    doc = db.query(Document).filter(Document.id == document_id, Document.owner_id == current_user.id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
        
    # Check if there are active print jobs
    active_jobs = db.query(PrintJob).filter(
        PrintJob.document_id == document_id,
        PrintJob.status.in_([
            PrintJobStatus.CREATED, 
            PrintJobStatus.SENT_TO_SHOP, 
            PrintJobStatus.ACCEPTED, 
            PrintJobStatus.PRINTING
        ])
    ).count()
    
    if active_jobs > 0:
        raise HTTPException(status_code=400, detail="Cannot delete document while it is required by an active print job.")
        
    # Delete physical file
    delete_file(doc.storage_key)
    
    # Update status to DELETED
    doc.status = DocumentStatus.DELETED
    doc.deleted_at = datetime.now(timezone.utc)
    db.commit()
    
    return {"message": "Document successfully deleted"}
