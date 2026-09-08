package com.example.secureprint.data.api

import com.example.secureprint.data.model.UserResponse
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path

interface UserApi {
    @GET("api/v1/users/me")
    suspend fun getCurrentUser(): Response<UserResponse>

    @GET("api/v1/admin/shops/pending")
    suspend fun getPendingShops(): Response<List<UserResponse>>

    @POST("api/v1/admin/shops/{id}/approve")
    suspend fun approveShop(
        @Path("id") shopId: Int
    ): Response<UserResponse>

    @POST("api/v1/admin/shops/{id}/reject")
    suspend fun rejectShop(
        @Path("id") shopId: Int
    ): Response<UserResponse>
}
