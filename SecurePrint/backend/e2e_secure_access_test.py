import httpx
import os
from datetime import datetime, timedelta, timezone

BASE_URL = "http://127.0.0.1:8000/api/v1"

def register_shop(client, email, name, phone):
    client.post("/auth/register", json={
        "email": email, "password": "pass", "name": name, "phone": phone,
        "role": "SHOP", "shop_name": name, "address": "123 Street", "city": "City",
        "pricing": {
            "price_a4_bw_single": 0.1, "price_a4_bw_double": 0.2,
            "price_a4_color_single": 0.5, "price_a4_color_double": 1.0,
            "price_a3_bw_single": 0.2, "price_a3_bw_double": 0.4,
            "price_a3_color_single": 1.0, "price_a3_color_double": 2.0
        }
    })
    # login as admin to approve
    res = client.post("/auth/login", data={"username": "admin@secureprint.com", "password": "SuperSecureAdmin123!"})
    admin_token = res.json()["access_token"]
    
    # get shop user id by logging in (will fail but give us a way to check if it exists, or just query admin shops)
    res = client.get("/admin/shops/pending", headers={"Authorization": f"Bearer {admin_token}"})
    for s in res.json():
        if s["email"] == email:
            client.post(f"/admin/shops/{s['id']}/approve", headers={"Authorization": f"Bearer {admin_token}"})
            break

    res = client.post("/auth/login", data={"username": email, "password": "pass"})
    if res.status_code == 200:
        return res.json()["access_token"]
    return None

def run_test():
    import uuid
    uid = uuid.uuid4().hex[:6]
    with httpx.Client(base_url=BASE_URL) as client:
        print("=== 1. SETUP ACCOUNTS ===")
        # Shop A
        shop_a_token = register_shop(client, f"secure_shop_A_{uid}@t.com", f"Secure Shop A {uid}", f"111{uid}")
        res = client.get("/users/me", headers={"Authorization": f"Bearer {shop_a_token}"})
        shop_a_user_id = res.json()["id"]
        
        # Shop B (for wrong shop test)
        shop_b_token = register_shop(client, f"secure_shop_B_{uid}@t.com", f"Secure Shop B {uid}", f"222{uid}")

        # Customer
        client.post("/auth/register", json={"email": f"secure_cust_{uid}@t.com", "password": "pass", "name": "Secure Cust", "phone": f"333{uid}", "role": "CUSTOMER"})
        res = client.post("/auth/login", data={"username": f"secure_cust_{uid}@t.com", "password": "pass"})
        cust_token = res.json()["access_token"]
        cust_headers = {"Authorization": f"Bearer {cust_token}"}
        
        # Find Shop A id from customer view
        res = client.get("/shops/?page=1&page_size=50", headers=cust_headers)
        shop_a_id = next(s["id"] for s in res.json() if s["shop_name"] == f"Secure Shop A {uid}")

        print(f"Accounts created. Shop A User ID: {shop_a_user_id}, Shop A Entity ID: {shop_a_id}")

        print("\n=== 2. CREATE ORDER ===")
        pdf_path = "uploads/0432eb5c0ba14591b6517a092409342b.pdf"
        files = {"file": (pdf_path, open(pdf_path, "rb"), "application/pdf")}
        res = client.post("/documents/", headers=cust_headers, files=files)
        doc_id = res.json()["id"]
        
        payload = {
            "document_id": doc_id, "shop_id": shop_a_id, "color_mode": "B/W",
            "paper_size": "A4", "print_side": "Single", "copies": 1
        }
        res = client.post("/print-jobs/", headers=cust_headers, json=payload)
        job_id = res.json()["id"]
        print(f"Created Job {job_id} for Document {doc_id}")
        
        # Shop A must ACCEPT the job before secure token can be generated
        res = client.post(f"/print-jobs/{job_id}/accept", headers={"Authorization": f"Bearer {shop_a_token}"})
        print(f"Shop A accepted job: {res.status_code}")

        print("\n=== 3. GENERATE SECURE ACCESS QR (Token A) ===")
        res = client.post(f"/print-jobs/{job_id}/secure-access", headers=cust_headers)
        token_a = res.json()["token"]
        print(f"Token A generated: SP-ACCESS-...{token_a[-5:]}")
        
        print("\n=== 4 & 5. SHOP AUTHORIZES TOKEN A (SUCCESS) ===")
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_a_token}"}, json={"token": token_a})
        if res.status_code != 200:
            print("Failed to authorize Token A:", res.text)
            return
        access_id_a = res.json()["access_id"]
        print(f"Authorization successful! Access ID: {access_id_a}")
        
        print("\n=== 6. VERIFY DOCUMENT DOWNLOAD ===")
        res = client.get(f"/shop/document-access/{access_id_a}/download", headers={"Authorization": f"Bearer {shop_a_token}"})
        print(f"Shop A downloaded document: Status {res.status_code}, Bytes: {len(res.content)}")
        if res.status_code != 200:
             print(res.text)

        print("\n=== 7. UNAUTHORIZED DOWNLOAD TEST ===")
        res = client.get(f"/shop/document-access/{access_id_a}/download", headers=cust_headers)
        print(f"Customer tried to use Shop access ID (Expected 403): {res.status_code}")
        
        print("\n=== 8. WRONG-SHOP TEST ===")
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_b_token}"}, json={"token": token_a})
        print(f"Shop B tries to authorize Token A (Expected 403): {res.status_code} {res.json().get('detail')}")
        
        print("\n=== 9. INVALID TOKEN TEST ===")
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_a_token}"}, json={"token": "SP-ACCESS-FAKE123"})
        print(f"Shop A tries invalid token (Expected 404): {res.status_code} {res.json().get('detail')}")
        
        print("\n=== 13. OLD QR REUSE TEST (Revocation) ===")
        # Generate Token B (which implicitly revokes Token A)
        res = client.post(f"/print-jobs/{job_id}/secure-access", headers=cust_headers)
        token_b = res.json()["token"]
        print(f"Token B generated (Token A should be revoked).")
        # Try to use Token A again
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_a_token}"}, json={"token": token_a})
        print(f"Shop A tries to authorize revoked Token A (Expected 403): {res.status_code} {res.json().get('detail')}")

        print("\n=== 10. EXPIRED TOKEN TEST ===")
        # Manually expire Token B in the database
        from app.core.database import SessionLocal
        from app.models.secure_token import SecureAccessToken
        import hashlib
        db = SessionLocal()
        t_hash = hashlib.sha256(token_b.encode("utf-8")).hexdigest()
        token_record = db.query(SecureAccessToken).filter(SecureAccessToken.token_hash == t_hash).first()
        token_record.expires_at = datetime.now(timezone.utc) - timedelta(minutes=5)
        db.commit()
        db.close()
        
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_a_token}"}, json={"token": token_b})
        print(f"Shop A tries to authorize expired Token B (Expected 403): {res.status_code} {res.json().get('detail')}")
        
        print("\n=== 12. COMPLETED JOB TEST ===")
        # Generate Token C
        res = client.post(f"/print-jobs/{job_id}/secure-access", headers=cust_headers)
        token_c = res.json()["token"]
        print("Token C generated.")
        
        # Start and then Complete the job
        res = client.post(f"/print-jobs/{job_id}/start", headers={"Authorization": f"Bearer {shop_a_token}"})
        res = client.post(f"/print-jobs/{job_id}/complete", headers={"Authorization": f"Bearer {shop_a_token}"})
        print(f"Job completed: {res.status_code}")
        
        # Try to authorize Token C on completed job
        res = client.post("/shop/document-access/authorize", headers={"Authorization": f"Bearer {shop_a_token}"}, json={"token": token_c})
        print(f"Shop A tries to authorize Token C after job completion (Expected 403): {res.status_code} {res.json().get('detail')}")

if __name__ == "__main__":
    run_test()
