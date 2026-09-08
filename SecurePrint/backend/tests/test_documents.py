import os
import pytest
from app.services.storage import UPLOAD_DIR

def get_token(client, email, password):
    response = client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    return response.json()["access_token"]

def test_documents_empty_initially(client):
    # Register customer
    client.post("/api/v1/auth/register", json={
        "name": "Doc User", "email": "doc@test.com", "phone": "2222222222", 
        "password": "Password123!", "role": "CUSTOMER"
    })
    token = get_token(client, "doc@test.com", "Password123!")
    
    response = client.get(
        "/api/v1/documents/",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json() == []

def test_upload_document(client, tmp_path):
    token = get_token(client, "doc@test.com", "Password123!")
    
    # Create dummy pdf (minimal valid pdf)
    file_path = tmp_path / "test.pdf"
    file_path.write_bytes(b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<>>\n>>\nendobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n203\n%%EOF\n")
    
    with open(file_path, "rb") as f:
        response = client.post(
            "/api/v1/documents/",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("test.pdf", f, "application/pdf")}
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data["original_filename"] == "test.pdf"
    assert data["status"] == "ACTIVE"
    
    # Check if the document was listed
    list_response = client.get(
        "/api/v1/documents/",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert len(list_response.json()) == 1
    assert list_response.json()[0]["id"] == data["id"]
    
def test_invalid_extension_rejected(client, tmp_path):
    token = get_token(client, "doc@test.com", "Password123!")
    
    file_path = tmp_path / "test.exe"
    file_path.write_bytes(b"dummy exe content")
    
    with open(file_path, "rb") as f:
        response = client.post(
            "/api/v1/documents/",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("test.exe", f, "application/octet-stream")}
        )
    
    assert response.status_code == 400
    assert "not allowed" in response.json()["detail"]
