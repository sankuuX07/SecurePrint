import pytest
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.temporary_access import TemporaryDocumentAccess, TemporaryAccessStatus
from app.models.print_job import PrintJob, PrintJobStatus
from app.models.document import DocumentStatus, Document
from app.models.audit_log import AuditLog
from app.services.temporary_access_service import DOCUMENT_ACCESS_DURATION_MINUTES
import time

import time
import uuid

def setup_test_data(client: TestClient, db_session: Session):
    # Customer
    suffix = uuid.uuid4().hex[:8]
    client.post("/api/v1/auth/register", json={"name": "C", "email": f"c{suffix}@t.com", "phone": f"11{suffix[-8:]}", "password": "Password1!", "role": "CUSTOMER"})
    c_token = client.post("/api/v1/auth/login", data={"username": f"c{suffix}@t.com", "password": "Password1!"}).json()["access_token"]
    c_headers = {"Authorization": f"Bearer {c_token}"}
    
    # Shop 1
    pricing = {
        "price_a4_bw_single": 0.1, "price_a4_bw_double": 0.2, "price_a4_color_single": 0.5, "price_a4_color_double": 1.0,
        "price_a3_bw_single": 0.2, "price_a3_bw_double": 0.4, "price_a3_color_single": 1.0, "price_a3_color_double": 2.0
    }
    res = client.post("/api/v1/auth/register", json={"name": "S", "email": f"s{suffix}@t.com", "phone": f"22{suffix[-8:]}", "password": "Password1!", "role": "SHOP", "shop_name": "S", "address": "123", "city": "NYC", "pricing": pricing})
    if res.status_code != 201:
        print("SHOP 1 REGISTRATION FAILED:", res.json())
    # Approve shop 1
    from app.models.user import User, UserStatus
    shop_user = db_session.query(User).filter(User.email == f"s{suffix}@t.com").first()
    shop_user.status = UserStatus.ACTIVE
    db_session.commit()
    s_token = client.post("/api/v1/auth/login", data={"username": f"s{suffix}@t.com", "password": "Password1!"}).json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}
    
    from app.models.shop import Shop
    shop1 = db_session.query(Shop).filter(Shop.owner_id == shop_user.id).first()
    shop1_id = shop1.id
    shop1.status = UserStatus.ACTIVE
    db_session.commit()
    
    # Pricing is handled by auth.py register API
    
    # Shop 2
    client.post("/api/v1/auth/register", json={"name": "S2", "email": f"s2{suffix}@t.com", "phone": f"33{suffix[-8:]}", "password": "Password1!", "role": "SHOP", "shop_name": "S2", "address": "123", "city": "NYC", "pricing": pricing})
    shop2_user = db_session.query(User).filter(User.email == f"s2{suffix}@t.com").first()
    shop2_user.status = UserStatus.ACTIVE
    shop2 = db_session.query(Shop).filter(Shop.owner_id == shop2_user.id).first()
    shop2.status = UserStatus.ACTIVE
    db_session.commit()
    s2_token = client.post("/api/v1/auth/login", data={"username": f"s2{suffix}@t.com", "password": "Password1!"}).json()["access_token"]
    s2_headers = {"Authorization": f"Bearer {s2_token}"}
    
    # Upload doc
    file_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources <<>> /Contents 4 0 R >>\nendobj\n4 0 obj\n<< /Length 0 >>\nstream\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000216 00000 n \ntrailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n265\n%%EOF"
    res = client.post("/api/v1/documents/", files={"file": ("test.pdf", file_content, "application/pdf")}, headers=c_headers)
    if res.status_code != 201:
        print("DOC UPLOAD FAILED:", res.json())
    doc_id = res.json()["id"]
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.page_count = 1
    db_session.commit()
    
    return c_headers, s_headers, s2_headers, shop1_id, doc_id

def test_grant_access_valid(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    
    # Customer creates job
    create_job_response = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id,
            "shop_id": shop_id,
            "copies": 1,
            "color_mode": "B/W",
            "paper_size": "A4",
            "print_side": "Single"
        },
        headers=c_headers
    )
    job_id = create_job_response.json()["id"]

    # Shop accepts job
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    
    # Test grant access
    grant_response = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    assert grant_response.status_code == 200
    access = grant_response.json()
    assert access["status"] == "ACTIVE"
    assert access["print_job_id"] == job_id
    assert access["document_id"] == doc_id
    
    # Check Audit Log
    logs = db_session.query(AuditLog).filter(AuditLog.event_type == "DOCUMENT_TEMP_ACCESS_GRANTED").all()
    assert len(logs) > 0
    assert logs[-1].print_job_id == job_id

def test_grant_access_wrong_shop(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    # Customer creates job for Shop 1
    create_job_response = client.post(
        "/api/v1/print-jobs/",
        json={
            "document_id": doc_id,
            "shop_id": shop_id,
            "copies": 1,
            "color_mode": "B/W",
            "paper_size": "A4",
            "print_side": "Single"
        },
        headers=c_headers
    )
    if create_job_response.status_code != 200:
        print("JOB CREATE FAILED:", create_job_response.json())
    job_id = create_job_response.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    
    # Shop 2 tries to grant access to Shop 1's job
    grant_response = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s2_headers)
    assert grant_response.status_code == 403

def test_grant_access_completed_job(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    create_job_response = client.post(
        "/api/v1/print-jobs/",
        json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"},
        headers=c_headers
    )
    job_id = create_job_response.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    client.post(f"/api/v1/print-jobs/{job_id}/start", headers=s_headers)
    client.post(f"/api/v1/print-jobs/{job_id}/complete", headers=s_headers)
    
    # Grant should fail since job is completed
    grant_response = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    assert grant_response.status_code == 400

def test_auto_revoke_on_cancel(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    # Create and accept
    res = client.post("/api/v1/print-jobs/", json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"}, headers=c_headers)
    job_id = res.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    
    # Grant
    grant_res = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    access_id = grant_res.json()["id"]
    
    # Customer cancels
    client.post(f"/api/v1/print-jobs/{job_id}/cancel", headers=c_headers)
    
    # Verify access is revoked
    metadata_res = client.get(f"/api/v1/shop/document-access/{access_id}", headers=s_headers)
    assert metadata_res.status_code == 410
    
    # Verify DB status
    access = db_session.query(TemporaryDocumentAccess).filter(TemporaryDocumentAccess.id == access_id).first()
    assert access.status == TemporaryAccessStatus.REVOKED
    
    # Verify audit log
    revoke_logs = db_session.query(AuditLog).filter(AuditLog.event_type == "DOCUMENT_TEMP_ACCESS_REVOKED", AuditLog.print_job_id == job_id).all()
    assert len(revoke_logs) > 0

def test_download_expired_access(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    res = client.post("/api/v1/print-jobs/", json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"}, headers=c_headers)
    job_id = res.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    
    grant_res = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    access_id = grant_res.json()["id"]
    
    # Manually expire in DB
    access = db_session.query(TemporaryDocumentAccess).filter(TemporaryDocumentAccess.id == access_id).first()
    access.expires_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    db_session.commit()
    
    # Attempt download
    download_res = client.get(f"/api/v1/shop/document-access/{access_id}/download", headers=s_headers)
    assert download_res.status_code == 410 # Expired

def test_deleted_document_invalidates_access(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    res = client.post("/api/v1/print-jobs/", json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"}, headers=c_headers)
    job_id = res.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    grant_res = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    access_id = grant_res.json()["id"]
    
    # Force delete the document
    doc = db_session.query(Document).filter(Document.id == doc_id).first()
    doc.status = DocumentStatus.DELETED
    db_session.commit()
    
    download_res = client.get(f"/api/v1/shop/document-access/{access_id}/download", headers=s_headers)
    assert download_res.status_code == 410 # Document unavailable

def test_download_success(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    res = client.post("/api/v1/print-jobs/", json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"}, headers=c_headers)
    job_id = res.json()["id"]
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    grant_res = client.post(f"/api/v1/shop/document-access/test-grant/{job_id}", headers=s_headers)
    access_id = grant_res.json()["id"]
    
    download_res = client.get(f"/api/v1/shop/document-access/{access_id}/download", headers=s_headers)
    assert download_res.status_code == 200
    
    # Audit log check
    used_logs = db_session.query(AuditLog).filter(AuditLog.event_type == "DOCUMENT_TEMP_ACCESS_USED", AuditLog.print_job_id == job_id).all()
    assert len(used_logs) > 0
    
    # Access count check
    access = db_session.query(TemporaryDocumentAccess).filter(TemporaryDocumentAccess.id == access_id).first()
    assert access.access_count == 1
