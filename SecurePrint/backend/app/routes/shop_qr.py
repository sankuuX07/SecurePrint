from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import uuid

from ..core.database import get_db
from ..models.user import User, UserRole, UserStatus
from ..models.shop import Shop
from ..models.shop_qr import ShopQrCode, QRStatus
from ..models.audit_log import AuditLog
from .users import get_current_user
from ..schemas.shop import ShopResponse

router = APIRouter(prefix="/shops/qr", tags=["shop_qr"])
shop_action_router = APIRouter(prefix="/shop/qr", tags=["shop_qr_management"])

def _log_event(db: Session, event_type: str, user_id: int = None, extra_metadata: str = None):
    log = AuditLog(
        event_type=event_type,
        user_id=user_id,
        extra_metadata=extra_metadata
    )
    db.add(log)

@router.get("/{qr_identifier}", response_model=ShopResponse)
def resolve_shop_qr(qr_identifier: str, db: Session = Depends(get_db)):
    """
    Resolve a QR identifier to a valid, active shop.
    Returns safe shop information.
    """
    qr = db.query(ShopQrCode).filter(ShopQrCode.qr_identifier == qr_identifier).first()
    
    if not qr:
        _log_event(db, "SHOP_QR_RESOLUTION_FAILED", extra_metadata=f"Invalid QR: {qr_identifier}")
        raise HTTPException(status_code=404, detail="Invalid Shop QR")
        
    if qr.status != QRStatus.ACTIVE:
        _log_event(db, "SHOP_QR_RESOLUTION_FAILED", extra_metadata=f"Revoked/Inactive QR: {qr_identifier}")
        raise HTTPException(status_code=403, detail="This QR code is no longer active.")
        
    shop = db.query(Shop).filter(Shop.id == qr.shop_id).first()
    if not shop or shop.status != UserStatus.ACTIVE:
        _log_event(db, "SHOP_QR_RESOLUTION_FAILED", extra_metadata=f"Shop not active for QR: {qr_identifier}")
        raise HTTPException(status_code=403, detail="The associated shop is not currently active.")
        
    _log_event(db, "SHOP_QR_SCANNED", extra_metadata=f"QR {qr_identifier} resolved to Shop {shop.id}")
    return shop

# --- Shop Actions ---

from pydantic import BaseModel

class ShopQrResponse(BaseModel):
    qr_identifier: str
    status: str
    created_at: datetime
    revoked_at: datetime | None = None
    
    class Config:
        from_attributes = True

@shop_action_router.get("", response_model=ShopQrResponse)
def get_my_shop_qr(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Get the currently active QR identity for the authenticated shop.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
        
    # Get the latest active QR
    qr = db.query(ShopQrCode).filter(
        ShopQrCode.shop_id == shop.id, 
        ShopQrCode.status == QRStatus.ACTIVE
    ).order_by(ShopQrCode.created_at.desc()).first()
    
    if not qr:
        # Fallback to get latest revoked/pending if no active
        qr = db.query(ShopQrCode).filter(ShopQrCode.shop_id == shop.id).order_by(ShopQrCode.created_at.desc()).first()
        if not qr:
            raise HTTPException(status_code=404, detail="No QR code found for this shop")
            
    return qr

@shop_action_router.post("/regenerate", response_model=ShopQrResponse)
def regenerate_shop_qr(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Revoke current QR and generate a new one.
    """
    if current_user.role != UserRole.SHOP:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    shop = db.query(Shop).filter(Shop.owner_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
        
    # Revoke all existing active QRs
    active_qrs = db.query(ShopQrCode).filter(
        ShopQrCode.shop_id == shop.id,
        ShopQrCode.status == QRStatus.ACTIVE
    ).all()
    
    now = datetime.now(timezone.utc)
    for aqr in active_qrs:
        aqr.status = QRStatus.REVOKED
        aqr.revoked_at = now
        _log_event(db, "SHOP_QR_REVOKED", user_id=current_user.id, extra_metadata=f"Revoked {aqr.qr_identifier}")
        
    # Create new QR
    new_qr_identifier = f"SP-SHOP-{uuid.uuid4().hex[:12].upper()}"
    new_qr = ShopQrCode(
        shop_id=shop.id,
        qr_identifier=new_qr_identifier,
        status=QRStatus.ACTIVE if shop.status == UserStatus.ACTIVE else QRStatus.REVOKED
    )
    db.add(new_qr)
    
    _log_event(db, "SHOP_QR_REGENERATED", user_id=current_user.id, extra_metadata=f"Created {new_qr_identifier}")
    
    db.commit()
    db.refresh(new_qr)
    return new_qr
