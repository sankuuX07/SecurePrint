import httpx
import json

payload = {
    "name": "Test Shop",
    "email": "shop@test.com",
    "phone": "1234567890",
    "password": "password",
    "role": "SHOP",
    "shop_name": "Test Shop Name",
    "address": "123 Test St",
    "city": "Test City",
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
}

try:
    response = httpx.post("http://127.0.0.1:8000/api/v1/auth/register", json=payload)
    print("Status:", response.status_code)
    print("Response:", json.dumps(response.json(), indent=2))
except Exception as e:
    print("Error:", e)
