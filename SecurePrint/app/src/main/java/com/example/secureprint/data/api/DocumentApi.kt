package com.example.secureprint.data.api

import com.example.secureprint.data.model.DocumentResponse
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.*

interface DocumentApi {
    @Multipart
    @POST("api/v1/documents/")
    suspend fun uploadDocument(
        @Part file: MultipartBody.Part
    ): Response<DocumentResponse>

    @GET("api/v1/documents/")
    suspend fun getMyDocuments(
        @Query("status") status: String? = null,
        @Query("search") search: String? = null
    ): Response<List<DocumentResponse>>

    @GET("api/v1/documents/{id}")
    suspend fun getDocument(@Path("id") id: String): Response<DocumentResponse>

    @DELETE("api/v1/documents/{id}")
    suspend fun deleteDocument(@Path("id") id: String): Response<Unit>
}
