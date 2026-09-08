package com.example.secureprint.data.model

import kotlinx.serialization.Serializable

@Serializable
data class ShopPricingResponse(
    val paper_size: String,
    val color_mode: String,
    val print_side: String,
    val price_per_sheet: Double
)

@Serializable
data class ShopResponse(
    val id: Int,
    val owner_id: Int,
    val shop_name: String,
    val address: String,
    val city: String,
    val phone: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val status: String,
    val rating: Double? = null,
    val pricing: List<ShopPricingResponse>
)

@Serializable
data class ShopQrResponse(
    val qr_identifier: String,
    val status: String,
    val created_at: String,
    val revoked_at: String? = null
)
