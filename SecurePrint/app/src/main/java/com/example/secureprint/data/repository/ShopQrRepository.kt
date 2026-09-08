package com.example.secureprint.data.repository

import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.ShopResponse
import com.example.secureprint.data.model.ShopQrResponse

class ShopQrRepository {
    private val api = RetrofitClient.shopQrApi

    suspend fun resolveShopQr(qrIdentifier: String): ShopResponse {
        return api.resolveShopQr(qrIdentifier)
    }

    suspend fun getMyShopQr(): ShopQrResponse {
        return api.getMyShopQr()
    }

    suspend fun regenerateShopQr(): ShopQrResponse {
        return api.regenerateShopQr()
    }
}
