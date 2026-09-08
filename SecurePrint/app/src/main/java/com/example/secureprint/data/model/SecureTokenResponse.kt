package com.example.secureprint.data.model

data class SecureTokenResponse(
    val token: String,
    val expires_at: String,
    val print_job_id: Int,
    val document_id: String,
    val shop_id: Int
)
