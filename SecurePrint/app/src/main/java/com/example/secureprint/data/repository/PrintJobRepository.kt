package com.example.secureprint.data.repository

import com.example.secureprint.data.api.PrintJobApi
import com.example.secureprint.data.model.PrintJobCreate
import com.example.secureprint.data.model.PrintJobDetailResponse
import com.example.secureprint.data.model.PrintJobResponse
import com.example.secureprint.data.model.SecureTokenResponse

class PrintJobRepository(private val api: PrintJobApi) {

    suspend fun createPrintJob(request: PrintJobCreate): PrintJobResponse {
        return api.createPrintJob(request)
    }

    suspend fun getCustomerPrintJobs(status: String? = null, shopId: Int? = null, page: Int = 1, pageSize: Int = 20): List<PrintJobResponse> {
        return api.getCustomerPrintJobs(status, shopId, page, pageSize)
    }
    
    suspend fun getCustomerPrintJobDetail(jobId: Int): PrintJobDetailResponse {
        return api.getCustomerPrintJobDetail(jobId)
    }
    
    suspend fun cancelPrintJob(jobId: Int): PrintJobResponse {
        return api.cancelPrintJob(jobId)
    }

    suspend fun createSecureAccessToken(jobId: Int): SecureTokenResponse {
        return api.createSecureAccessToken(jobId)
    }

    suspend fun getShopPrintJobs(status: String? = null, page: Int = 1, pageSize: Int = 20): List<PrintJobResponse> {
        return api.getShopPrintJobs(status, page, pageSize)
    }
    
    suspend fun getShopPrintJobDetail(jobId: Int): PrintJobDetailResponse {
        return api.getShopPrintJobDetail(jobId)
    }

    suspend fun acceptPrintJob(jobId: Int): PrintJobResponse {
        return api.acceptPrintJob(jobId)
    }

    suspend fun startPrintJob(jobId: Int): PrintJobResponse {
        return api.startPrintJob(jobId)
    }

    suspend fun completePrintJob(jobId: Int): PrintJobResponse {
        return api.completePrintJob(jobId)
    }
    
    suspend fun getAdminPrintJobs(status: String? = null, shopId: Int? = null, customerId: Int? = null, page: Int = 1, pageSize: Int = 20): List<PrintJobResponse> {
        return api.getAdminPrintJobs(status, shopId, customerId, page, pageSize)
    }
    
    suspend fun getAdminPrintJobDetail(jobId: Int): PrintJobDetailResponse {
        return api.getAdminPrintJobDetail(jobId)
    }
}
