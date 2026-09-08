from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime

class ShopPricingResponse(BaseModel):
    paper_size: str
    color_mode: str
    print_side: str
    price_per_sheet: float

    model_config = ConfigDict(from_attributes=True)

class ShopResponse(BaseModel):
    id: int
    owner_id: int
    shop_name: str
    address: str
    city: str
    phone: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    status: str
    rating: Optional[float] = None
    pricing: List[ShopPricingResponse] = []
    
    model_config = ConfigDict(from_attributes=True)
