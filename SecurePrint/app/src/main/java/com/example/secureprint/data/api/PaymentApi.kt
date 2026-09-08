package com.example.secureprint.data.api

import com.example.secureprint.data.model.PaymentResponse
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface PaymentApi {
    @POST("api/v1/shop/print-jobs/{job_id}/payment/mark-paid")
    suspend fun markPaymentPaid(@Path("job_id") jobId: Int): PaymentResponse

    @GET("api/v1/shop/print-jobs/{job_id}/payment")
    suspend fun getPaymentStatus(@Path("job_id") jobId: Int): PaymentResponse
}
