package com.example.secureprint.data.model

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SignupLoginContractTest {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    @Test
    fun testCustomerRegisterRequestSerializationMatchesFastApiSchema() {
        val request = RegisterRequest(
            name = "Test Customer",
            email = "customer@example.com",
            phone = "9876543210",
            password = "SecurePassword123!",
            role = "CUSTOMER"
        )

        val serialized = json.encodeToString(request)

        assertTrue(serialized.contains("\"name\":\"Test Customer\""))
        assertTrue(serialized.contains("\"email\":\"customer@example.com\""))
        assertTrue(serialized.contains("\"phone\":\"9876543210\""))
        assertTrue(serialized.contains("\"password\":\"SecurePassword123!\""))
        assertTrue(serialized.contains("\"role\":\"CUSTOMER\""))
    }

    @Test
    fun testShopRegisterRequestSerializationMatchesFastApiSchema() {
        val pricing = PricingSetup(
            price_a4_bw_single = 1.0,
            price_a4_bw_double = 1.5,
            price_a4_color_single = 5.0,
            price_a4_color_double = 8.0,
            price_a3_bw_single = 2.0,
            price_a3_bw_double = 3.0,
            price_a3_color_single = 10.0,
            price_a3_color_double = 15.0
        )

        val request = RegisterRequest(
            name = "Shop Owner",
            email = "shop@example.com",
            phone = "9876543211",
            password = "ShopPassword123!",
            role = "SHOP",
            shop_name = "Quick Print Shop",
            address = "123 Main Street",
            city = "Tech City",
            pricing = pricing
        )

        val serialized = json.encodeToString(request)

        assertTrue(serialized.contains("\"shop_name\":\"Quick Print Shop\""))
        assertTrue(serialized.contains("\"address\":\"123 Main Street\""))
        assertTrue(serialized.contains("\"city\":\"Tech City\""))
        assertTrue(serialized.contains("\"pricing\":{"))
        assertTrue(serialized.contains("\"price_a4_bw_single\":1.0"))
    }

    @Test
    fun testUserResponseDeserializationFromFastApiJson() {
        val backendJson = """
            {
                "id": 1,
                "name": "Test Customer",
                "email": "customer@example.com",
                "phone": "9876543210",
                "role": "CUSTOMER",
                "status": "ACTIVE",
                "shop_name": null,
                "address": null,
                "city": null,
                "created_at": "2026-10-19T10:00:00.000000",
                "updated_at": null
            }
        """.trimIndent()

        val response = json.decodeFromString<UserResponse>(backendJson)

        assertEquals(1, response.id)
        assertEquals("Test Customer", response.name)
        assertEquals("customer@example.com", response.email)
        assertEquals("9876543210", response.phone)
        assertEquals("CUSTOMER", response.role)
        assertEquals("ACTIVE", response.status)
        assertEquals("2026-10-19T10:00:00.000000", response.created_at)
    }

    @Test
    fun testAuthResponseDeserializationFromFastApiLoginJson() {
        val backendJson = """
            {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy",
                "token_type": "bearer",
                "role": "CUSTOMER"
            }
        """.trimIndent()

        val response = json.decodeFromString<AuthResponse>(backendJson)

        assertEquals("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy", response.access_token)
        assertEquals("bearer", response.token_type)
        assertEquals("CUSTOMER", response.role)
    }
}
