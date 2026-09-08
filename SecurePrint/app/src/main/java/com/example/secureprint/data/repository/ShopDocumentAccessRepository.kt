package com.example.secureprint.data.repository

import com.example.secureprint.data.api.ShopDocumentAccessApi
import com.example.secureprint.data.model.TemporaryDocumentAccessResponse
import com.example.secureprint.data.model.TokenRequest
import okhttp3.ResponseBody
import retrofit2.Response

class ShopDocumentAccessRepository(private val api: ShopDocumentAccessApi) {
    suspend fun testGrantAccess(jobId: Int): Response<TemporaryDocumentAccessResponse> {
        return api.testGrantAccess(jobId)
    }

    suspend fun authorizeSecureAccess(request: TokenRequest): Response<TemporaryDocumentAccessResponse> {
        return api.authorizeSecureAccess(request)
    }

    suspend fun getAccessMetadata(accessId: String): Response<TemporaryDocumentAccessResponse> {
        return api.getAccessMetadata(accessId)
    }

    suspend fun downloadDocument(accessId: String): Response<ResponseBody> {
        return api.downloadDocument(accessId)
    }
}
