def test_register_customer(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Customer Test",
            "email": "customer@test.com",
            "phone": "1234567890",
            "password": "Password123!",
            "role": "CUSTOMER"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "CUSTOMER"
    assert data["status"] == "ACTIVE"

def test_register_shop(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Shop Owner",
            "email": "shop@test.com",
            "phone": "0987654321",
            "password": "Password123!",
            "role": "SHOP",
            "shop_name": "Test Shop",
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
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "SHOP"
    assert data["status"] == "PENDING"
    assert data["shop_name"] == "Test Shop"
    assert data["address"] == "123 Test St"
    assert data["city"] == "Test City"

def test_register_shop_missing_pricing(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Shop Owner 2",
            "email": "shop2@test.com",
            "phone": "0987654322",
            "password": "Password123!",
            "role": "SHOP",
            "shop_name": "Test Shop 2"
        }
    )
    assert response.status_code == 400
    assert "Pricing setup is required for shops" in response.json()["detail"]

def test_register_admin_rejected(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Fake Admin",
            "email": "fakeadmin@test.com",
            "phone": "1111111111",
            "password": "Password123!",
            "role": "ADMIN"
        }
    )
    assert response.status_code == 400
    assert "Admin registration is disabled" in response.json()["detail"]

def test_register_shop_empty_details(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Shop Owner 3",
            "email": "shop3@test.com",
            "phone": "0987654323",
            "password": "Password123!",
            "role": "SHOP",
            "shop_name": "",
            "address": " ",
            "city": "",
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
    )
    assert response.status_code == 400
    assert "Shop details are required" in response.json()["detail"]
