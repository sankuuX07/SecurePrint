package com.example.secureprint.data.repository

import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.AuthResponse
import com.example.secureprint.data.model.RegisterRequest
import com.example.secureprint.data.model.UserResponse
import retrofit2.Response

class AuthRepository {
    private val authApi = RetrofitClient.authApi
    private val userApi = RetrofitClient.userApi

    suspend fun login(email: String, password: String): Response<AuthResponse> {
        return authApi.login(email, password)
    }

    suspend fun register(request: RegisterRequest): Response<UserResponse> {
        return authApi.register(request)
    }

    suspend fun getCurrentUser(): Response<UserResponse> {
        return userApi.getCurrentUser()
    }

    suspend fun getPendingShops(): Response<List<UserResponse>> {
        return userApi.getPendingShops()
    }

    suspend fun approveShop(id: Int): Response<UserResponse> {
        return userApi.approveShop(id)
    }

    suspend fun rejectShop(id: Int): Response<UserResponse> {
        return userApi.rejectShop(id)
    }
}
