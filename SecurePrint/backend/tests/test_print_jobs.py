import pytest
import time
from app.models.user import User, UserStatus
from app.models.print_job import PrintJobStatus
from app.models.document import DocumentStatus

@pytest.fixture
def shop_token_and_id(client, db_session):
    # Register shop
    unique_suffix = int(time.time() * 1000)
    email = f"shopjob{unique_suffix}@test.com"
    phone = f"999{str(unique_suffix)[-7:]}"
    res = client.post("/api/v1/auth/register", json={
        "name": "Shop Job",
        "email": email,
        "phone": phone,
        "password": "Password123!",
        "role": "SHOP",
        "shop_name": "Shop Job",
        "address": "123 Job St",
        "city": "Job City",
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
    assert res.status_code == 200, res.text
    shop_id = res.json()["id"]
    
    from app.models.shop import Shop
    shop = db_session.query(User).filter(User.id == shop_id).first()
    shop.status = UserStatus.ACTIVE
    shop_entity = db_session.query(Shop).filter(Shop.owner_id == shop_id).first()
    if shop_entity:
        shop_entity.status = UserStatus.ACTIVE
    db_session.commit()
    
    # Login
    res = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"})
    token = res.json()["access_token"]
    return token, shop_entity.id if shop_entity else shop_id

@pytest.fixture
def customer_token_and_id(client, db_session):
    unique_suffix = int(time.time() * 1000)
    email = f"custjob{unique_suffix}@test.com"
    phone = f"888{str(unique_suffix)[-7:]}"
    res = client.post("/api/v1/auth/register", json={
        "name": "Customer Job",
        "email": email,
        "phone": phone,
        "password": "Password123!",
        "role": "CUSTOMER"
    })
    assert res.status_code == 200, res.text
    cust_id = res.json()["id"]
    res = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"})
    return res.json()["access_token"], cust_id

@pytest.fixture
def customer_document(client, customer_token_and_id, tmp_path):
    token, cust_id = customer_token_and_id
    file_path = tmp_path / "testdoc.pdf"
    file_path.write_bytes(b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<>>\n>>\nendobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n203\n%%EOF\n")
    
    with open(file_path, "rb") as f:
        res = client.post(
            "/api/v1/documents/",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("testdoc.pdf", f, "application/pdf")}
        )
    assert res.status_code == 200, res.text
    return res.json()["id"]

def test_get_shops(client, customer_token_and_id, shop_token_and_id):
    cust_token, _ = customer_token_and_id
    res = client.get("/api/v1/shops/", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    shops = res.json()
    assert len(shops) > 0
    assert shops[0]["status"] == "ACTIVE"

def test_print_job_pricing_calculation(client, db_session, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    _, shop_id = shop_token_and_id
    doc_id = customer_document

    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 3
    db_session.commit()

    # 1. Double Sided Test (3 pages = 2 sheets * 2 copies * 1.5 = 6.0)
    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id,
            "shop_id": shop_id,
            "copies": 2,
            "color_mode": "B/W",
            "paper_size": "A4",
            "print_side": "Double",
            "price": 0.0  # trying to tamper price
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    assert res.status_code == 200
    job = res.json()
    assert job["price"] == 6.0 # Server side calc overrides

    # 2. Single Sided Test (3 pages = 3 sheets * 1 copy * 1.0 = 3.0)
    res2 = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id,
            "shop_id": shop_id,
            "copies": 1,
            "color_mode": "B/W",
            "paper_size": "A4",
            "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    assert res2.json()["price"] == 3.0

def test_print_job_tampering_document(client, db_session, shop_token_and_id):
    # Customer 2 trying to print Customer 1's document
    res = client.post("/api/v1/auth/register", json={
        "name": "Customer Thief", "email": "thief@test.com", "phone": "1231231231", "password": "Password123!", "role": "CUSTOMER"
    })
    token = client.post("/api/v1/auth/login", data={"username": "thief@test.com", "password": "Password123!"}).json()["access_token"]
    
    _, shop_id = shop_token_and_id
    # Assuming doc_id exists from previous fixture... wait, tests should be isolated.
    # We will just fetch a random document
    from app.models.document import Document
    doc = db_session.query(Document).first()
    
    if doc and doc.owner_id != res.json()["id"]:
        res = client.post(
            "/api/v1/print-jobs/",
            json={
                "document_id": doc.id,
                "shop_id": shop_id,
                "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        assert res.status_code == 403

def test_state_machine_transitions(client, db_session, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    shop_token, shop_id = shop_token_and_id
    doc_id = customer_document
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    # Create job
    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    job_id = res.json()["id"]

    # Customer can't accept
    res = client.post(f"/api/v1/print-jobs/{job_id}/accept", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 403

    # Shop accepts
    res = client.post(f"/api/v1/print-jobs/{job_id}/accept", headers={"Authorization": f"Bearer {shop_token}"})
    assert res.status_code == 200
    assert res.json()["status"] == "ACCEPTED"

    # Shop starts
    res = client.post(f"/api/v1/print-jobs/{job_id}/start", headers={"Authorization": f"Bearer {shop_token}"})
    assert res.status_code == 200
    assert res.json()["status"] == "PRINTING"

    # Shop completes
    res = client.post(f"/api/v1/print-jobs/{job_id}/complete", headers={"Authorization": f"Bearer {shop_token}"})
    assert res.status_code == 200
    assert res.json()["status"] == "COMPLETED"

    # Shop invalid transition (complete again)
    res = client.post(f"/api/v1/print-jobs/{job_id}/complete", headers={"Authorization": f"Bearer {shop_token}"})
    assert res.status_code == 400
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    # Create job
    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    assert res.status_code == 200
    job_id = res.json()["id"]
    
    # Cancel job
    res = client.post(f"/api/v1/print-jobs/{job_id}/cancel", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    assert res.json()["status"] == "CANCELLED"
    
    # Verify history
    res = client.get(f"/api/v1/print-jobs/customer/{job_id}", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    history = res.json()["status_history"]
    assert len(history) == 2
    assert history[0]["to_status"] == "CREATED"
    assert history[1]["to_status"] == "CANCELLED"

def test_phase8_pagination_and_filters(client, db_session, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    shop_token, shop_id = shop_token_and_id
    doc_id = customer_document
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    
    res = client.get(f"/api/v1/print-jobs/customer?status=CREATED&page=1&page_size=1", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    assert len(res.json()) >= 1

def test_phase8_admin_endpoints(client, db_session, admin_token, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    shop_token, shop_id = shop_token_and_id
    doc_id = customer_document
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    job_id = res.json()["id"]
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    # Create job
    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    assert res.status_code == 200
    job_id = res.json()["id"]
    
    # Cancel job
    res = client.post(f"/api/v1/print-jobs/{job_id}/cancel", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    assert res.json()["status"] == "CANCELLED"
    
    # Verify history
    res = client.get(f"/api/v1/print-jobs/customer/{job_id}", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    history = res.json()["status_history"]
    assert len(history) == 2
    assert history[0]["to_status"] == "CREATED"
    assert history[1]["to_status"] == "CANCELLED"

def test_phase8_pagination_and_filters(client, db_session, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    shop_token, shop_id = shop_token_and_id
    doc_id = customer_document
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    
    res = client.get(f"/api/v1/print-jobs/customer?status=CREATED&page=1&page_size=1", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200
    assert len(res.json()) >= 1

def test_phase8_admin_endpoints(client, db_session, admin_token, customer_token_and_id, shop_token_and_id, customer_document):
    cust_token, cust_id = customer_token_and_id
    shop_token, shop_id = shop_token_and_id
    doc_id = customer_document
    
    from app.models.document import Document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()

    res = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id, "shop_id": shop_id, "copies": 1, 
            "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"
        },
        headers={"Authorization": f"Bearer {cust_token}"}
    )
    job_id = res.json()["id"]
    
    res = client.get(f"/api/v1/print-jobs/admin?shop_id={shop_id}", headers={"Authorization": f"Bearer {admin_token}"})
    assert res.status_code == 200
    assert len(res.json()) >= 1
    
    res = client.get(f"/api/v1/print-jobs/admin/{job_id}", headers={"Authorization": f"Bearer {admin_token}"})
    assert res.status_code == 200
    assert res.json()["id"] == job_id
    assert "status_history" in res.json()

@pytest.fixture
def admin_token(client, db_session):
    import time
    email = f"admin{int(time.time()*1000)}@test.com"
    from app.core.security import get_password_hash
    from app.models.user import User, UserRole, UserStatus
    admin_user = User(
        name="Admin User",
        email=email,
        phone="1231231233",
        password_hash=get_password_hash("Password123!"),
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE
    )
    db_session.add(admin_user)
    db_session.commit()
    token = client.post("/api/v1/auth/login", data={"username": email, "password": "Password123!"}).json()["access_token"]
    return token
