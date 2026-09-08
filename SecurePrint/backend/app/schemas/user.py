from pydantic import BaseModel, EmailStr, ConfigDict, model_validator
from datetime import datetime
from typing import Optional, Any
from ..models.user import UserRole, UserStatus

class UserBase(BaseModel):
    name: str
    email: EmailStr
    phone: str
    role: UserRole
    shop_name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None

class PricingSetup(BaseModel):
    price_a4_bw_single: float
    price_a4_bw_double: float
    price_a4_color_single: float
    price_a4_color_double: float
    price_a3_bw_single: float
    price_a3_bw_double: float
    price_a3_color_single: float
    price_a3_color_double: float

class UserCreate(UserBase):
    password: str
    pricing: Optional[PricingSetup] = None

class UserResponse(UserBase):
    id: int
    status: UserStatus
    created_at: datetime
    updated_at: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def extract_shop_details(cls, data: Any) -> Any:
        if isinstance(data, dict):
            return data
            
        ret = {
            "id": getattr(data, "id", None),
            "name": getattr(data, "name", None),
            "email": getattr(data, "email", None),
            "phone": getattr(data, "phone", None),
            "role": getattr(data, "role", None),
            "status": getattr(data, "status", None),
            "created_at": getattr(data, "created_at", None),
            "updated_at": getattr(data, "updated_at", None),
        }
        
        if ret["role"] == UserRole.SHOP and hasattr(data, "shop") and getattr(data, "shop", None):
            shop = data.shop
            ret["shop_name"] = getattr(shop, "shop_name", None)
            ret["address"] = getattr(shop, "address", None)
            ret["city"] = getattr(shop, "city", None)
        else:
            ret["shop_name"] = None
            ret["address"] = None
            ret["city"] = None
            
        return ret

class Token(BaseModel):
    access_token: str
    token_type: str
    role: UserRole

class TokenData(BaseModel):
    email: Optional[str] = None
