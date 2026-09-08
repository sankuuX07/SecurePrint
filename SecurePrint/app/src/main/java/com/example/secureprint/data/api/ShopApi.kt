package com.example.secureprint.data.api

import com.example.secureprint.data.model.ShopResponse
import retrofit2.http.GET

interface ShopApi {
    @GET("shops/")
    suspend fun getShops(): List<ShopResponse>
}
