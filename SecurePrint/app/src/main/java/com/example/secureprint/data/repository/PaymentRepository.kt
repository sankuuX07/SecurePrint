package com.example.secureprint.data.repository

import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.PaymentResponse

class PaymentRepository {
    private val api = RetrofitClient.paymentApi

    suspend fun markPaymentPaid(jobId: Int): PaymentResponse {
        return api.markPaymentPaid(jobId)
    }

    suspend fun getPaymentStatus(jobId: Int): PaymentResponse {
        return api.getPaymentStatus(jobId)
    }
}
