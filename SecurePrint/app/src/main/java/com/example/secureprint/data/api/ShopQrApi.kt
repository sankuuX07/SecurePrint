package com.example.secureprint.data.api

import com.example.secureprint.data.model.ShopResponse
import com.example.secureprint.data.model.ShopQrResponse
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface ShopQrApi {
    @GET("api/v1/shops/qr/{qr_identifier}")
    suspend fun resolveShopQr(@Path("qr_identifier") qrIdentifier: String): ShopResponse

    @GET("api/v1/shop/qr")
    suspend fun getMyShopQr(): ShopQrResponse

    @POST("api/v1/shop/qr/regenerate")
    suspend fun regenerateShopQr(): ShopQrResponse
}
