import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.user import UserStatus, User, UserRole
from app.models.shop_qr import ShopQrCode, QRStatus
import time

@pytest.fixture
def admin_token_headers(client, db_session):
    email = f"admin_qr_{int(time.time()*1000)}@test.com"
    from app.core.security import get_password_hash
    admin_user = User(
        name="Admin User",
        email=email,
        phone=f"111{str(int(time.time()))[-7:]}",
        password_hash=get_password_hash("Password123!"),
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE
    )
    db_session.add(admin_user)
    db_session.commit()
    token = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def test_user_data():
    return {
        "name": "Customer Test",
        "email": f"customer_qr_{int(time.time()*1000)}@test.com",
        "phone": f"222{str(int(time.time()))[-7:]}",
        "password": "Password123!",
        "role": "CUSTOMER"
    }

@pytest.fixture
def shop_pricing_data():
    return {
        "price_a4_bw_single": 1.0,
        "price_a4_bw_double": 1.5,
        "price_a4_color_single": 5.0,
        "price_a4_color_double": 8.0,
        "price_a3_bw_single": 2.0,
        "price_a3_bw_double": 3.0,
        "price_a3_color_single": 10.0,
        "price_a3_color_double": 15.0
    }

def test_shop_qr_generation_on_registration(client: TestClient, db_session: Session, test_user_data, shop_pricing_data):
    # Register a shop
    test_user_data["role"] = "SHOP"
    test_user_data["shop_name"] = "QR Test Shop"
    test_user_data["address"] = "123 QR St"
    test_user_data["city"] = "QR City"
    test_user_data["pricing"] = shop_pricing_data
    test_user_data["email"] = "qr_shop@example.com"
    test_user_data["phone"] = "9876543212"
    
    response = client.post("/api/v1/auth/register", json=test_user_data)
    assert response.status_code == 200
    shop_owner_id = response.json()["id"]
    
    # Check if a revoked/pending QR was created
    qr = db_session.query(ShopQrCode).join(ShopQrCode.shop).filter(ShopQrCode.shop.has(owner_id=shop_owner_id)).first()
    assert qr is not None
    assert qr.status == QRStatus.REVOKED
    qr_identifier = qr.qr_identifier
    
    # Resolving it should fail
    response = client.get(f"/api/v1/shops/qr/{qr_identifier}")
    assert response.status_code == 403
    
def test_shop_qr_activation_on_approval(client: TestClient, db_session: Session, admin_token_headers):
    # Assuming the shop from previous test is ID 2 if tests run sequentially, or we find it
    # Let's find the pending shop
    response = client.get("/api/v1/admin/shops/pending", headers=admin_token_headers)
    assert response.status_code == 200
    pending_shops = response.json()
    assert len(pending_shops) > 0
    
    shop_to_approve = pending_shops[-1]["id"] # The one we just created
    
    response = client.post(f"/api/v1/admin/shops/{shop_to_approve}/approve", headers=admin_token_headers)
    assert response.status_code == 200
    
    qr = db_session.query(ShopQrCode).join(ShopQrCode.shop).filter(ShopQrCode.shop.has(owner_id=shop_to_approve)).order_by(ShopQrCode.created_at.desc()).first()
    assert qr.status == QRStatus.ACTIVE
    
    # Should resolve now
    response = client.get(f"/api/v1/shops/qr/{qr.qr_identifier}")
    assert response.status_code == 200
    assert response.json()["shop_name"] == "QR Test Shop"
    
def test_shop_can_view_and_regenerate_qr(client: TestClient, db_session: Session, test_user_data):
    # Login as the approved shop
    login_data = {
        "username": "qr_shop@example.com",
        "password": test_user_data["password"]
    }
    response = client.post("/api/v1/auth/login", data=login_data)
    token = response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # View QR
    response = client.get("/api/v1/shop/qr", headers=headers)
    assert response.status_code == 200
    old_qr_id = response.json()["qr_identifier"]
    
    # Regenerate QR
    response = client.post("/api/v1/shop/qr/regenerate", headers=headers)
    assert response.status_code == 200
    new_qr_id = response.json()["qr_identifier"]
    
    assert old_qr_id != new_qr_id
    
    # Old should be revoked
    response = client.get(f"/api/v1/shops/qr/{old_qr_id}")
    assert response.status_code == 403
    
    # New should be active
    response = client.get(f"/api/v1/shops/qr/{new_qr_id}")
    assert response.status_code == 200
    
def test_invalid_qr_rejected(client: TestClient):
    response = client.get("/api/v1/shops/qr/invalid-qr-code")
    assert response.status_code == 404
