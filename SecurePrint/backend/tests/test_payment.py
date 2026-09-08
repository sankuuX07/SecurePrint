import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.models.print_job import PrintJob
import io
import time

@pytest.fixture
def active_shop_id(client, db_session):
    unique_suffix = int(time.time() * 1000)
    email = f"shoppay{unique_suffix}@test.com"
    res = client.post("/api/v1/auth/register", json={
        "name": "Shop Pay",
        "email": email,
        "phone": f"333{str(unique_suffix)[-7:]}",
        "password": "Password123!",
        "role": "SHOP",
        "shop_name": "Shop Pay",
        "address": "123 Pay St",
        "city": "Pay City",
        "pricing": {
            "price_a4_bw_single": 1.0,
            "price_a4_bw_double": 1.5,
            "price_a4_color_single": 5.0,
            "price_a4_color_double": 8.0,
            "price_a3_bw_single": 2.0,
            "price_a3_bw_double": 3.0,
            "price_a3_color_single": 10.0,
            "price_a3_color_double": 15.0
        }
    })
    shop_id = res.json()["id"]
    
    from app.models.user import User, UserStatus
    from app.models.shop import Shop
    shop = db_session.query(User).filter(User.id == shop_id).first()
    shop.status = UserStatus.ACTIVE
    shop_entity = db_session.query(Shop).filter(Shop.owner_id == shop_id).first()
    if shop_entity:
        shop_entity.status = UserStatus.ACTIVE
    db_session.commit()
    return shop_entity.id if shop_entity else shop_id

@pytest.fixture
def shop_token_headers(client, db_session, active_shop_id):
    from app.models.shop import Shop
    shop = db_session.query(Shop).filter(Shop.id == active_shop_id).first()
    email = shop.owner.email
    res = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"})
    return {"Authorization": f"Bearer {res.json()['access_token']}"}

@pytest.fixture
def customer_token_headers(client, db_session):
    unique_suffix = int(time.time() * 1000)
    email = f"custpay{unique_suffix}@test.com"
    res = client.post("/api/v1/auth/register", json={
        "name": "Customer Pay",
        "email": email,
        "phone": f"444{str(unique_suffix)[-7:]}",
        "password": "Password123!",
        "role": "CUSTOMER"
    })
    res = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"})
    return {"Authorization": f"Bearer {res.json()['access_token']}"}

def test_payment_initialization(client: TestClient, db_session: Session, customer_token_headers, active_shop_id):
    # Upload a dummy document
    file_content = b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<>>\n>>\nendobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n203\n%%EOF\n"
    response = client.post(
        "/api/v1/documents/",
        headers=customer_token_headers,
        files={"file": ("test.pdf", io.BytesIO(file_content), "application/pdf")}
    )
    doc_id = response.json()["id"]
    
    # Create PrintJob
    job_data = {
        "shop_id": active_shop_id,
        "document_id": doc_id,
        "copies": 1,
        "page_range": "1",
        "color_mode": "B/W",
        "paper_size": "A4",
        "print_side": "Single",
        "orientation": "Portrait"
    }
    
    response = client.post("/api/v1/print-jobs/", headers=customer_token_headers, json=job_data)
    assert response.status_code == 200
    job_id = response.json()["id"]
    price = response.json()["price"]
    
    # Check Payment initialization
    payment = db_session.query(Payment).filter(Payment.print_job_id == job_id).first()
    assert payment is not None
    assert payment.method == PaymentMethod.PAY_AT_SHOP
    assert payment.status == PaymentStatus.UNPAID
    assert float(payment.amount) == price
    
    # Fetch status via endpoint
    response = client.get(f"/api/v1/shop/print-jobs/{job_id}/payment", headers=customer_token_headers)
    assert response.status_code == 200
    assert response.json()["status"] == PaymentStatus.UNPAID
    
def test_shop_can_mark_payment_paid(client: TestClient, db_session: Session, shop_token_headers, customer_token_headers, active_shop_id):
    # Setup job
    file_content = b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<>>\n>>\nendobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n203\n%%EOF\n"
    res_doc = client.post(
        "/api/v1/documents/",
        headers=customer_token_headers,
        files={"file": ("test.pdf", io.BytesIO(file_content), "application/pdf")}
    )
    doc_id = res_doc.json()["id"]
    job_data = {
        "shop_id": active_shop_id,
        "document_id": doc_id,
        "copies": 1,
        "page_range": "1",
        "color_mode": "B/W",
        "paper_size": "A4",
        "print_side": "Single",
        "orientation": "Portrait"
    }
    client.post("/api/v1/print-jobs/", headers=customer_token_headers, json=job_data)
    
    # Get the job for this shop
    response = client.get("/api/v1/print-jobs/shop", headers=shop_token_headers)
    jobs = response.json()
    assert len(jobs) > 0
    job_id = jobs[-1]["id"]
    
    # Mark paid
    response = client.post(f"/api/v1/shop/print-jobs/{job_id}/payment/mark-paid", headers=shop_token_headers)
    assert response.status_code == 200
    assert response.json()["status"] == PaymentStatus.PAID
    
    # Try to mark paid again (should fail)
    response = client.post(f"/api/v1/shop/print-jobs/{job_id}/payment/mark-paid", headers=shop_token_headers)
    assert response.status_code == 400
    
def test_customer_cannot_mark_paid(client: TestClient, customer_token_headers, active_shop_id):
    # Setup job
    file_content = b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<>>\n>>\nendobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n203\n%%EOF\n"
    res_doc = client.post(
        "/api/v1/documents/",
        headers=customer_token_headers,
        files={"file": ("test.pdf", io.BytesIO(file_content), "application/pdf")}
    )
    doc_id = res_doc.json()["id"]
    job_data = {
        "shop_id": active_shop_id,
        "document_id": doc_id,
        "copies": 1,
        "page_range": "1",
        "color_mode": "B/W",
        "paper_size": "A4",
        "print_side": "Single",
        "orientation": "Portrait"
    }
    client.post("/api/v1/print-jobs/", headers=customer_token_headers, json=job_data)
    
    response = client.get("/api/v1/print-jobs/customer", headers=customer_token_headers)
    jobs = response.json()
    assert len(jobs) > 0
    job_id = jobs[-1]["id"]
    
    response = client.post(f"/api/v1/shop/print-jobs/{job_id}/payment/mark-paid", headers=customer_token_headers)
    assert response.status_code == 403
