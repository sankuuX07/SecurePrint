import httpx
import uuid
import os

BASE_URL = "http://127.0.0.1:8000/api/v1"

def run():
    uid = uuid.uuid4().hex[:6]
    with httpx.Client(base_url=BASE_URL) as client:
        # Shop
        email = f"physical_shop_{uid}@t.com"
        client.post("/auth/register", json={
            "email": email, "password": "pass", "name": "Physical Shop", "phone": f"555{uid}",
            "role": "SHOP", "shop_name": "Physical Shop", "address": "123 Street", "city": "City",
            "pricing": {
                "price_a4_bw_single": 0.1, "price_a4_bw_double": 0.2,
                "price_a4_color_single": 0.5, "price_a4_color_double": 1.0,
                "price_a3_bw_single": 0.2, "price_a3_bw_double": 0.4,
                "price_a3_color_single": 1.0, "price_a3_color_double": 2.0
            }
        })
        # Admin approve
        res = client.post("/auth/login", data={"username": "admin@secureprint.com", "password": "SuperSecureAdmin123!"})
        admin_token = res.json()["access_token"]
        res = client.get("/admin/shops/pending", headers={"Authorization": f"Bearer {admin_token}"})
        for s in res.json():
            if s["email"] == email:
                client.post(f"/admin/shops/{s['id']}/approve", headers={"Authorization": f"Bearer {admin_token}"})
                break
        
        # Cust
        cust_email = f"physical_cust_{uid}@t.com"
        client.post("/auth/register", json={"email": cust_email, "password": "pass", "name": "Physical Cust", "phone": f"444{uid}", "role": "CUSTOMER"})
        res = client.post("/auth/login", data={"username": cust_email, "password": "pass"})
        cust_token = res.json()["access_token"]
        cust_headers = {"Authorization": f"Bearer {cust_token}"}
        
        # Shop ID
        res = client.get("/shops/?page=1&page_size=50", headers=cust_headers)
        shop_id = next(s["id"] for s in res.json() if s["shop_name"] == "Physical Shop")
        
        # Doc
        pdf_path = "uploads/0432eb5c0ba14591b6517a092409342b.pdf"
        files = {"file": (pdf_path, open(pdf_path, "rb"), "application/pdf")}
        res = client.post("/documents/", headers=cust_headers, files=files)
        doc_id = res.json()["id"]
        
        # Order
        payload = {
            "document_id": doc_id, "shop_id": shop_id, "color_mode": "B/W",
            "paper_size": "A4", "print_side": "Single", "copies": 1
        }
        res = client.post("/print-jobs/", headers=cust_headers, json=payload)
        job = res.json()
        
        print(f"Test Order ID: {job['id']}")
        print(f"Customer Email: {cust_email}")
        print(f"Shop Email: {email}")
        print(f"Document ID: {doc_id}")
        print(f"Page Count: {job['selected_page_count']}")
        print(f"Print Settings: {payload['color_mode']} | {payload['paper_size']} | {payload['print_side']} | {payload['copies']} copies")
        print(f"Expected Price: {job['price']}")

if __name__ == "__main__":
    run()
