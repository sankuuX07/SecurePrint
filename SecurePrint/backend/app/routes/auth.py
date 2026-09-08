from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..core.security import get_password_hash, verify_password, create_access_token
from ..models.user import User, UserRole, UserStatus
from ..models.shop_pricing import ShopPricing
from ..schemas.user import UserCreate, UserResponse, Token

router = APIRouter(prefix="/auth", tags=["authentication"])

@router.post("/register", response_model=UserResponse)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    # Check if user exists
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = db.query(User).filter(User.phone == user_in.phone).first()
    if user:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    if user_in.role == UserRole.ADMIN:
        raise HTTPException(status_code=400, detail="Admin registration is disabled")

    # Set status based on role
    user_status = UserStatus.ACTIVE
    if user_in.role == UserRole.SHOP:
        user_status = UserStatus.PENDING

    db_user = User(
        name=user_in.name,
        email=user_in.email,
        phone=user_in.phone,
        password_hash=get_password_hash(user_in.password),
        role=user_in.role,
        status=user_status
    )
    db.add(db_user)
    db.flush() # To get user ID

    if user_in.role == UserRole.SHOP:
        if not user_in.pricing:
            raise HTTPException(status_code=400, detail="Pricing setup is required for shops")
        if (user_in.shop_name is None or user_in.shop_name.strip() == "") or \
           (user_in.address is None or user_in.address.strip() == "") or \
           (user_in.city is None or user_in.city.strip() == ""):
            raise HTTPException(status_code=400, detail="Shop details are required")
        
        from ..models.shop import Shop
        db_shop = Shop(
            owner_id=db_user.id,
            shop_name=user_in.shop_name,
            address=user_in.address,
            city=user_in.city,
            phone=user_in.phone, # Use user phone or add shop phone to schema? Using user phone.
            status=user_status
        )
        db.add(db_shop)
        db.flush() # To get shop ID
        
        # Validate all are non-negative
        prices = [
            user_in.pricing.price_a4_bw_single, user_in.pricing.price_a4_bw_double,
            user_in.pricing.price_a4_color_single, user_in.pricing.price_a4_color_double,
            user_in.pricing.price_a3_bw_single, user_in.pricing.price_a3_bw_double,
            user_in.pricing.price_a3_color_single, user_in.pricing.price_a3_color_double
        ]
        if any(p < 0 for p in prices):
            raise HTTPException(status_code=400, detail="Pricing values must be non-negative")

        pricing_entries = [
            ShopPricing(shop_id=db_shop.id, paper_size="A4", color_mode="B/W", print_side="Single", price_per_sheet=user_in.pricing.price_a4_bw_single),
            ShopPricing(shop_id=db_shop.id, paper_size="A4", color_mode="B/W", print_side="Double", price_per_sheet=user_in.pricing.price_a4_bw_double),
            ShopPricing(shop_id=db_shop.id, paper_size="A4", color_mode="Color", print_side="Single", price_per_sheet=user_in.pricing.price_a4_color_single),
            ShopPricing(shop_id=db_shop.id, paper_size="A4", color_mode="Color", print_side="Double", price_per_sheet=user_in.pricing.price_a4_color_double),
            ShopPricing(shop_id=db_shop.id, paper_size="A3", color_mode="B/W", print_side="Single", price_per_sheet=user_in.pricing.price_a3_bw_single),
            ShopPricing(shop_id=db_shop.id, paper_size="A3", color_mode="B/W", print_side="Double", price_per_sheet=user_in.pricing.price_a3_bw_double),
            ShopPricing(shop_id=db_shop.id, paper_size="A3", color_mode="Color", print_side="Single", price_per_sheet=user_in.pricing.price_a3_color_single),
            ShopPricing(shop_id=db_shop.id, paper_size="A3", color_mode="Color", print_side="Double", price_per_sheet=user_in.pricing.price_a3_color_double),
        ]
        db.add_all(pricing_entries)

        # Generate pending Shop QR Identity
        import uuid
        from ..models.shop_qr import ShopQrCode, QRStatus
        
        qr_identifier = f"SP-SHOP-{uuid.uuid4().hex[:12].upper()}"
        shop_qr = ShopQrCode(
            shop_id=db_shop.id,
            qr_identifier=qr_identifier,
            status=QRStatus.REVOKED  # Will be activated by admin
        )
        db.add(shop_qr)

    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/login", response_model=Token)
def login(db: Session = Depends(get_db), form_data: OAuth2PasswordRequestForm = Depends()):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    if user.status == UserStatus.PENDING:
        raise HTTPException(status_code=403, detail="Account pending approval")
    if user.status == UserStatus.REJECTED:
        raise HTTPException(status_code=403, detail="Account rejected")
    if user.status == UserStatus.INACTIVE:
        raise HTTPException(status_code=403, detail="Account inactive")

    access_token = create_access_token(subject=user.email)
    return {"access_token": access_token, "token_type": "bearer", "role": user.role}
