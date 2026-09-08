from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from ..core.database import get_db
from ..models.user import User, UserRole, UserStatus
from ..schemas.user import UserResponse
from .users import get_current_user

router = APIRouter(prefix="/admin", tags=["admin"])

def check_admin(current_user: User = Depends(get_current_user)):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Not enough privileges")
    return current_user

@router.get("/shops/pending", response_model=List[UserResponse])
def get_pending_shops(db: Session = Depends(get_db), admin: User = Depends(check_admin)):
    return db.query(User).filter(User.role == UserRole.SHOP, User.status == UserStatus.PENDING).all()

@router.post("/shops/{shop_id}/approve", response_model=UserResponse)
def approve_shop(shop_id: int, db: Session = Depends(get_db), admin: User = Depends(check_admin)):
    shop_user = db.query(User).filter(User.id == shop_id, User.role == UserRole.SHOP).first()
    if not shop_user:
        raise HTTPException(status_code=404, detail="Shop not found")

    shop_user.status = UserStatus.ACTIVE
    
    from ..models.shop import Shop
    shop_entity = db.query(Shop).filter(Shop.owner_id == shop_id).first()
    if shop_entity:
        shop_entity.status = UserStatus.ACTIVE
        
        # Activate primary QR
        from ..models.shop_qr import ShopQrCode, QRStatus
        shop_qr = db.query(ShopQrCode).filter(ShopQrCode.shop_id == shop_entity.id).order_by(ShopQrCode.created_at.desc()).first()
        if shop_qr:
            shop_qr.status = QRStatus.ACTIVE
        
    db.commit()
    db.refresh(shop_user)
    return shop_user

@router.post("/shops/{shop_id}/reject", response_model=UserResponse)
def reject_shop(shop_id: int, db: Session = Depends(get_db), admin: User = Depends(check_admin)):
    shop_user = db.query(User).filter(User.id == shop_id, User.role == UserRole.SHOP).first()
    if not shop_user:
        raise HTTPException(status_code=404, detail="Shop not found")

    shop_user.status = UserStatus.REJECTED
    
    from ..models.shop import Shop
    shop_entity = db.query(Shop).filter(Shop.owner_id == shop_id).first()
    if shop_entity:
        shop_entity.status = UserStatus.REJECTED
        
    db.commit()
    db.refresh(shop_user)
    return shop_user
