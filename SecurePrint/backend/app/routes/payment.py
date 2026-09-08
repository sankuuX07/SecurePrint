from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from ..core.database import get_db
from ..models.user import User, UserRole
from ..models.shop import Shop
from ..models.print_job import PrintJob
from ..models.payment import Payment, PaymentMethod, PaymentStatus
from ..models.audit_log import AuditLog
from .users import get_current_user
from pydantic import BaseModel
from decimal import Decimal

router = APIRouter(prefix="/shop/print-jobs", tags=["payment"])

class PaymentResponse(BaseModel):
    id: int
    print_job_id: int
    amount: Decimal
    status: PaymentStatus
    method: PaymentMethod
    paid_at: datetime | None = None
    
    class Config:
        from_attributes = True

def _log_event(db: Session, event_type: str, user_id: int = None, extra_metadata: str = None):
    log = AuditLog(
        event_type=event_type,
        user_id=user_id,
        extra_metadata=extra_metadata
    )
    db.add(log)

@router.post("/{job_id}/payment/mark-paid", response_model=PaymentResponse)
def mark_payment_paid(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Allows a shop to mark a PAY_AT_SHOP print job as PAID.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Only shops can manage payments")
        
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
        
    job = db.query(PrintJob).filter(PrintJob.id == job_id, PrintJob.shop_id == shop.id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Print job not found or does not belong to this shop")
        
    payment = db.query(Payment).filter(Payment.print_job_id == job.id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")
        
    if payment.method != PaymentMethod.PAY_AT_SHOP:
        raise HTTPException(status_code=400, detail="Can only manually mark PAY_AT_SHOP payments as paid")
        
    if payment.status == PaymentStatus.PAID:
        raise HTTPException(status_code=400, detail="Payment is already marked as paid")
        
    if payment.status == PaymentStatus.REFUNDED:
        raise HTTPException(status_code=400, detail="Cannot mark a refunded payment as paid")
        
    payment.status = PaymentStatus.PAID
    payment.paid_at = datetime.now(timezone.utc)
    
    _log_event(db, "PAYMENT_MARKED_PAID", user_id=current_user.id, extra_metadata=f"Job {job.id} paid at shop")
    
    db.commit()
    db.refresh(payment)
    return payment

@router.get("/{job_id}/payment", response_model=PaymentResponse)
def get_payment_status(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get payment status for a print job.
    Accessible to Customer and Shop.
    """
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Print job not found")
        
    if current_user.role == UserRole.CUSTOMER and job.customer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    if current_user.role == UserRole.SHOP:
        shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
        if not shop or job.shop_id != shop.id:
            raise HTTPException(status_code=403, detail="Not authorized")
            
    payment = db.query(Payment).filter(Payment.print_job_id == job.id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")
        
    return payment
