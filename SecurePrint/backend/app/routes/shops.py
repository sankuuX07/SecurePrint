from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..core.database import get_db
from .users import get_current_user
from ..models.user import User, UserRole, UserStatus
from ..schemas.shop import ShopResponse

router = APIRouter(prefix="/shops", tags=["shops"])

@router.get("/", response_model=List[ShopResponse])
def get_approved_shops(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Returns a list of all ACTIVE shops.
    Customers use this to select a shop for printing.
    """
    from ..models.shop import Shop
    shops = db.query(Shop).filter(
        Shop.status == UserStatus.ACTIVE
    ).all()
    
    return shops
