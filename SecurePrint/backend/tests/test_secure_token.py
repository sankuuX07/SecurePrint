import pytest
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.secure_token import SecureAccessToken, SecureTokenStatus
from app.models.print_job import PrintJob, PrintJobStatus
from app.models.temporary_access import TemporaryDocumentAccess, TemporaryAccessStatus
from app.services.secure_token_service import SecureTokenService
from tests.test_temporary_access import setup_test_data

def test_create_and_validate_secure_token(client: TestClient, db_session: Session):
    c_headers, s_headers, s2_headers, shop_id, doc_id = setup_test_data(client, db_session)
    
    # Customer creates job
    create_job_response = client.post(
        "/api/v1/print-jobs/",
        json={"document_id": doc_id, "shop_id": shop_id, "copies": 1, "color_mode": "B/W", "paper_size": "A4", "print_side": "Single"},
        headers=c_headers
    )
    job_id = create_job_response.json()["id"]

    # Try creating token before accepted -> should fail
    fail_res = client.post(f"/api/v1/print-jobs/{job_id}/secure-access", headers=c_headers)
    assert fail_res.status_code == 400

    # Shop accepts job
    client.post(f"/api/v1/print-jobs/{job_id}/accept", headers=s_headers)
    
    # Create token
    res = client.post(f"/api/v1/print-jobs/{job_id}/secure-access", headers=c_headers)
    assert res.status_code == 200
    data = res.json()
    assert "token" in data
    raw_token = data["token"]
    
    # Check DB
    db_token = db_session.query(SecureAccessToken).filter(SecureAccessToken.print_job_id == job_id).first()
    assert db_token is not None
    assert db_token.status == SecureTokenStatus.ACTIVE
    
    # Shop scans token
    res = client.post("/api/v1/shop/document-access/authorize", headers=s_headers, json={"token": raw_token})
    assert res.status_code == 200
    access_data = res.json()
    assert access_data["status"] == "AUTHORIZED"
    
    # Check Complete Job revokes token
    client.post(f"/api/v1/print-jobs/{job_id}/start", headers=s_headers)
    client.post(f"/api/v1/print-jobs/{job_id}/complete", headers=s_headers)
    
    db_session.expire_all()
    db_session.refresh(db_token)
    assert db_token.status == SecureTokenStatus.REVOKED
    
    # Scan revoked token
    res = client.post("/api/v1/shop/document-access/authorize", headers=s_headers, json={"token": raw_token})
    assert res.status_code == 403
