import math
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone

from ..core.database import get_db
from .users import get_current_user
from ..models.user import User, UserRole, UserStatus
from ..models.document import Document, DocumentStatus
from ..models.shop_pricing import ShopPricing
from ..models.print_job import PrintJob, PrintJobStatus
from ..models.print_job_status_history import PrintJobStatusHistory
from ..schemas.print_job import PrintJobCreate, PrintJobResponse, PrintJobDetailResponse
from ..services.temporary_access_service import TemporaryDocumentAccessService
from ..services.secure_token_service import SecureTokenService

router = APIRouter(prefix="/print-jobs", tags=["print_jobs"])

def calculate_price(db: Session, shop_id: int, pages: int, copies: int, paper_size: str, color_mode: str, print_side: str) -> float:
    pricing = db.query(ShopPricing).filter(
        ShopPricing.shop_id == shop_id,
        ShopPricing.paper_size.ilike(paper_size),
        ShopPricing.color_mode.ilike(color_mode),
        ShopPricing.print_side.ilike(print_side)
    ).first()
    
    if not pricing:
        raise HTTPException(status_code=400, detail="The selected shop does not offer this printing configuration.")
    
    is_double = print_side.lower() == "double"
    sheets = math.ceil(pages / 2) if is_double else pages
    return sheets * copies * pricing.price_per_sheet

def change_status_transactional(db: Session, job: PrintJob, new_status: PrintJobStatus, user_id: int):
    valid_transitions = {
        PrintJobStatus.CREATED: [PrintJobStatus.SENT_TO_SHOP, PrintJobStatus.ACCEPTED, PrintJobStatus.CANCELLED],
        PrintJobStatus.SENT_TO_SHOP: [PrintJobStatus.ACCEPTED, PrintJobStatus.CANCELLED],
        PrintJobStatus.ACCEPTED: [PrintJobStatus.PRINTING, PrintJobStatus.CANCELLED],
        PrintJobStatus.PRINTING: [PrintJobStatus.COMPLETED],
        PrintJobStatus.COMPLETED: [],
        PrintJobStatus.CANCELLED: []
    }
    
    if new_status not in valid_transitions[job.status]:
        raise HTTPException(status_code=400, detail="Invalid state transition")
        
    history = PrintJobStatusHistory(
        print_job_id=job.id,
        from_status=job.status,
        to_status=new_status,
        changed_by=user_id,
        changed_at=datetime.now(timezone.utc)
    )
    
    job.status = new_status
    now_utc = datetime.now(timezone.utc)
    if new_status == PrintJobStatus.ACCEPTED:
        job.accepted_at = now_utc
    elif new_status == PrintJobStatus.PRINTING:
        job.printing_at = now_utc
    elif new_status == PrintJobStatus.COMPLETED:
        job.completed_at = now_utc
        TemporaryDocumentAccessService.revoke_access(db, job.id)
        SecureTokenService.revoke_tokens_for_job(db, job.id, log=True)
    elif new_status == PrintJobStatus.CANCELLED:
        job.cancelled_at = now_utc
        TemporaryDocumentAccessService.revoke_access(db, job.id)
        SecureTokenService.revoke_tokens_for_job(db, job.id, log=True)
        
    db.add(history)

@router.post("/", response_model=PrintJobResponse)
def create_print_job(
    job_in: PrintJobCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from ..models.shop import Shop
    from ..services.page_range import parse_page_range
    
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(status_code=403, detail="Only customers can create print jobs")
        
    document = db.query(Document).filter(Document.id == job_in.document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
        
    if document.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot create print job for a document you do not own")
        
    if not document.page_count or document.page_count <= 0:
        raise HTTPException(status_code=400, detail="Document page count is invalid")
        
    try:
        selected_page_count = parse_page_range(job_in.page_range, document.page_count)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
        
    shop = db.query(Shop).filter(Shop.id == job_in.shop_id).first()
    if not shop or shop.status != UserStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Selected shop is invalid or not approved")

    price = calculate_price(
        db=db,
        shop_id=shop.id,
        pages=selected_page_count,
        copies=job_in.copies,
        paper_size=job_in.paper_size,
        color_mode=job_in.color_mode,
        print_side=job_in.print_side
    )

    new_job = PrintJob(
        customer_id=current_user.id,
        shop_id=shop.id,
        document_id=document.id,
        copies=job_in.copies,
        page_range=job_in.page_range,
        selected_page_count=selected_page_count,
        color_mode=job_in.color_mode,
        paper_size=job_in.paper_size,
        print_side=job_in.print_side,
        orientation=job_in.orientation,
        binding=job_in.binding,
        stapling=job_in.stapling,
        price=price,
        status=PrintJobStatus.CREATED,
        created_at=datetime.now(timezone.utc)
    )
    db.add(new_job)
    db.flush()
    
    # Baseline history
    history = PrintJobStatusHistory(
        print_job_id=new_job.id,
        from_status=None,
        to_status=PrintJobStatus.CREATED,
        changed_by=current_user.id,
        changed_at=datetime.now(timezone.utc)
    )
    db.add(history)
    
    # Initialize Payment
    from ..models.payment import Payment, PaymentMethod, PaymentStatus
    payment = Payment(
        print_job_id=new_job.id,
        customer_id=current_user.id,
        shop_id=shop.id,
        amount=price,
        method=PaymentMethod.PAY_AT_SHOP,
        status=PaymentStatus.UNPAID
    )
    db.add(payment)
    
    document.status = DocumentStatus.IN_PRINT_JOB
    db.commit()
    db.refresh(new_job)
    return new_job

@router.get("/customer", response_model=List[PrintJobResponse])
def get_customer_print_jobs(
    status: Optional[PrintJobStatus] = None,
    shop_id: Optional[int] = None,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    page_size = min(page_size, 100)
    query = db.query(PrintJob).filter(PrintJob.customer_id == current_user.id)
    
    if status:
        query = query.filter(PrintJob.status == status)
    if shop_id:
        query = query.filter(PrintJob.shop_id == shop_id)
        
    return query.order_by(PrintJob.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

@router.get("/customer/{job_id}", response_model=PrintJobDetailResponse)
def get_customer_print_job_detail(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.customer_id == current_user.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job

@router.get("/shop", response_model=List[PrintJobResponse])
def get_shop_print_jobs(
    status: Optional[PrintJobStatus] = None,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from ..models.shop import Shop
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
        
    page_size = min(page_size, 100)
    query = db.query(PrintJob).filter(PrintJob.shop_id == shop.id)
    
    if status:
        query = query.filter(PrintJob.status == status)
        
    return query.order_by(PrintJob.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

@router.get("/shop/{job_id}", response_model=PrintJobDetailResponse)
def get_shop_print_job_detail(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from ..models.shop import Shop
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
        
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.shop_id == shop.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job

@router.post("/{job_id}/cancel", response_model=PrintJobResponse)
def cancel_print_job(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    # Only customer can cancel for now, and must own the job
    if current_user.role != UserRole.CUSTOMER or job.customer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to cancel this job")
        
    change_status_transactional(db, job, PrintJobStatus.CANCELLED, current_user.id)
    
    # Check if document has other active print jobs
    active_jobs = db.query(PrintJob).filter(
        PrintJob.document_id == job.document_id,
        PrintJob.id != job.id,
        PrintJob.status.in_([
            PrintJobStatus.CREATED, 
            PrintJobStatus.SENT_TO_SHOP, 
            PrintJobStatus.ACCEPTED, 
            PrintJobStatus.PRINTING
        ])
    ).count()
    
    if active_jobs == 0:
        doc = db.query(Document).filter(Document.id == job.document_id).first()
        if doc and doc.status != DocumentStatus.DELETED:
            doc.status = DocumentStatus.ACTIVE
            
    db.commit()
    db.refresh(job)
    return job

@router.post("/{job_id}/accept", response_model=PrintJobResponse)
def accept_print_job(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from ..models.shop import Shop
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.shop_id == shop.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    change_status_transactional(db, job, PrintJobStatus.ACCEPTED, current_user.id)
    db.commit()
    db.refresh(job)
    return job

@router.post("/{job_id}/start", response_model=PrintJobResponse)
def start_print_job(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from ..models.shop import Shop
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.shop_id == shop.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    change_status_transactional(db, job, PrintJobStatus.PRINTING, current_user.id)
    db.commit()
    db.refresh(job)
    return job

@router.post("/{job_id}/complete", response_model=PrintJobResponse)
def complete_print_job(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from ..models.shop import Shop
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.shop_id == shop.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    change_status_transactional(db, job, PrintJobStatus.COMPLETED, current_user.id)
    
    active_jobs = db.query(PrintJob).filter(
        PrintJob.document_id == job.document_id,
        PrintJob.id != job.id,
        PrintJob.status.in_([
            PrintJobStatus.CREATED, 
            PrintJobStatus.SENT_TO_SHOP, 
            PrintJobStatus.ACCEPTED, 
            PrintJobStatus.PRINTING
        ])
    ).count()
    
    if active_jobs == 0:
        doc = db.query(Document).filter(Document.id == job.document_id).first()
        if doc and doc.status != DocumentStatus.DELETED:
            doc.status = DocumentStatus.PRINTED
            
    db.commit()
    db.refresh(job)
    return job

@router.get("/admin", response_model=List[PrintJobResponse])
def get_admin_print_jobs(
    status: Optional[PrintJobStatus] = None,
    shop_id: Optional[int] = None,
    customer_id: Optional[int] = None,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    page_size = min(page_size, 100)
    query = db.query(PrintJob)
    
    if status:
        query = query.filter(PrintJob.status == status)
    if shop_id:
        query = query.filter(PrintJob.shop_id == shop_id)
    if customer_id:
        query = query.filter(PrintJob.customer_id == customer_id)
        
    return query.order_by(PrintJob.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

@router.get("/admin/{job_id}", response_model=PrintJobDetailResponse)
def get_admin_print_job_detail(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job

@router.post("/{job_id}/secure-access")
def generate_secure_access_token(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Customer generates a short-lived Secure Access Token (QR payload).
    """
    return SecureTokenService.create_token(db, job_id, current_user)
