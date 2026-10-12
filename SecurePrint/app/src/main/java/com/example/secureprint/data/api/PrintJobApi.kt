package com.example.secureprint.data.api

import com.example.secureprint.data.model.PrintJobCreate
import com.example.secureprint.data.model.PrintJobDetailResponse
import com.example.secureprint.data.model.PrintJobResponse
import com.example.secureprint.data.model.SecureTokenResponse
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface PrintJobApi {
    @POST("api/v1/print-jobs/")
    suspend fun createPrintJob(@Body request: PrintJobCreate): PrintJobResponse

    @GET("api/v1/print-jobs/customer")
    suspend fun getCustomerPrintJobs(
        @Query("status") status: String? = null,
        @Query("shop_id") shopId: Int? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): List<PrintJobResponse>
    
    @GET("api/v1/print-jobs/customer/{jobId}")
    suspend fun getCustomerPrintJobDetail(@Path("jobId") jobId: Int): PrintJobDetailResponse
    
    @POST("api/v1/print-jobs/{jobId}/cancel")
    suspend fun cancelPrintJob(@Path("jobId") jobId: Int): PrintJobResponse

    @POST("api/v1/print-jobs/{jobId}/secure-access")
    suspend fun createSecureAccessToken(@Path("jobId") jobId: Int): SecureTokenResponse

    @GET("api/v1/print-jobs/shop")
    suspend fun getShopPrintJobs(
        @Query("status") status: String? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): List<PrintJobResponse>
    
    @GET("api/v1/print-jobs/shop/{jobId}")
    suspend fun getShopPrintJobDetail(@Path("jobId") jobId: Int): PrintJobDetailResponse

    @POST("api/v1/print-jobs/{jobId}/accept")
    suspend fun acceptPrintJob(@Path("jobId") jobId: Int): PrintJobResponse

    @POST("api/v1/print-jobs/{jobId}/start")
    suspend fun startPrintJob(@Path("jobId") jobId: Int): PrintJobResponse

    @POST("api/v1/print-jobs/{jobId}/complete")
    suspend fun completePrintJob(@Path("jobId") jobId: Int): PrintJobResponse
    
    @GET("api/v1/print-jobs/admin")
    suspend fun getAdminPrintJobs(
        @Query("status") status: String? = null,
        @Query("shop_id") shopId: Int? = null,
        @Query("customer_id") customerId: Int? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): List<PrintJobResponse>
    
    @GET("api/v1/print-jobs/admin/{jobId}")
    suspend fun getAdminPrintJobDetail(@Path("jobId") jobId: Int): PrintJobDetailResponse
}
