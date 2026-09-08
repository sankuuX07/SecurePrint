package com.example.secureprint.data.model

import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(
    val username: String,
    val password: String
)

@Serializable
data class RegisterRequest(
    val name: String,
    val email: String,
    val phone: String,
    val password: String,
    val role: String,
    val shop_name: String? = null,
    val address: String? = null,
    val city: String? = null,
    val pricing: PricingSetup? = null
)

@Serializable
data class PricingSetup(
    val price_a4_bw_single: Double,
    val price_a4_bw_double: Double,
    val price_a4_color_single: Double,
    val price_a4_color_double: Double,
    val price_a3_bw_single: Double,
    val price_a3_bw_double: Double,
    val price_a3_color_single: Double,
    val price_a3_color_double: Double
)

@Serializable
data class AuthResponse(
    val access_token: String,
    val token_type: String,
    val role: String
)

@Serializable
data class UserResponse(
    val id: Int,
    val name: String,
    val email: String,
    val phone: String,
    val role: String,
    val status: String,
    val shop_name: String? = null,
    val address: String? = null,
    val city: String? = null
)
