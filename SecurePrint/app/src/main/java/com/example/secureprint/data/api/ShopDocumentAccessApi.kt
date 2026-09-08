package com.example.secureprint.data.api

import com.example.secureprint.data.model.TemporaryDocumentAccessResponse
import com.example.secureprint.data.model.TokenRequest
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Body
import retrofit2.http.Path
import okhttp3.ResponseBody
import retrofit2.http.Streaming

interface ShopDocumentAccessApi {
    @POST("api/v1/shop/document-access/test-grant/{job_id}")
    suspend fun testGrantAccess(
        @Path("job_id") jobId: Int
    ): Response<TemporaryDocumentAccessResponse>

    @POST("api/v1/shop/document-access/authorize")
    suspend fun authorizeSecureAccess(
        @Body request: TokenRequest
    ): Response<TemporaryDocumentAccessResponse>

    @GET("api/v1/shop/document-access/{access_id}")
    suspend fun getAccessMetadata(
        @Path("access_id") accessId: String
    ): Response<TemporaryDocumentAccessResponse>

    @Streaming
    @GET("api/v1/shop/document-access/{access_id}/download")
    suspend fun downloadDocument(
        @Path("access_id") accessId: String
    ): Response<ResponseBody>
}
