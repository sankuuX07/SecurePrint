package com.example.secureprint.ui.shop

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.PrintJobDetailResponse
import com.example.secureprint.data.model.PrintJobResponse
import com.example.secureprint.data.model.PaymentResponse
import com.example.secureprint.data.repository.PrintJobRepository
import com.example.secureprint.data.repository.PaymentRepository
import kotlinx.coroutines.launch

sealed class ShopJobsUiState {
    object Loading : ShopJobsUiState()
    data class Success(val jobs: List<PrintJobResponse>, val isPaginating: Boolean = false) : ShopJobsUiState()
    data class Error(val message: String) : ShopJobsUiState()
}

sealed class ShopJobDetailUiState {
    object Loading : ShopJobDetailUiState()
    data class Success(val job: PrintJobDetailResponse, val payment: PaymentResponse? = null) : ShopJobDetailUiState()
    data class Error(val message: String) : ShopJobDetailUiState()
}

class ShopJobsViewModel : ViewModel() {
    private val repository = PrintJobRepository(RetrofitClient.printJobApi)
    private val paymentRepository = PaymentRepository()
    
    var listUiState by mutableStateOf<ShopJobsUiState>(ShopJobsUiState.Loading)
        private set
        
    var detailUiState by mutableStateOf<ShopJobDetailUiState>(ShopJobDetailUiState.Loading)
        private set
        
    private var currentPage = 1
    private var currentStatusFilter: String? = null
    
    fun loadJobs(status: String? = null, reset: Boolean = false) {
        if (reset) {
            currentPage = 1
            currentStatusFilter = status
            listUiState = ShopJobsUiState.Loading
        } else {
            val currentState = listUiState
            if (currentState is ShopJobsUiState.Success) {
                listUiState = currentState.copy(isPaginating = true)
            }
        }
        
        viewModelScope.launch {
            try {
                val jobs = repository.getShopPrintJobs(status = currentStatusFilter, page = currentPage)
                val currentState = listUiState
                if (!reset && currentState is ShopJobsUiState.Success) {
                    listUiState = ShopJobsUiState.Success(currentState.jobs + jobs)
                } else {
                    listUiState = ShopJobsUiState.Success(jobs)
                }
                if (jobs.isNotEmpty()) currentPage++
            } catch (e: Exception) {
                if (reset) {
                    listUiState = ShopJobsUiState.Error(e.message ?: "Unknown error")
                } else {
                    val currentState = listUiState
                    if (currentState is ShopJobsUiState.Success) {
                        listUiState = currentState.copy(isPaginating = false)
                    }
                }
            }
        }
    }
    
    fun loadJobDetail(jobId: Int) {
        detailUiState = ShopJobDetailUiState.Loading
        viewModelScope.launch {
            try {
                val detail = repository.getShopPrintJobDetail(jobId)
                val payment = try {
                    paymentRepository.getPaymentStatus(jobId)
                } catch (e: Exception) {
                    null
                }
                detailUiState = ShopJobDetailUiState.Success(detail, payment)
            } catch (e: Exception) {
                detailUiState = ShopJobDetailUiState.Error(e.message ?: "Failed to load detail")
            }
        }
    }
    
    fun markPaymentPaid(jobId: Int) {
        viewModelScope.launch {
            try {
                paymentRepository.markPaymentPaid(jobId)
                loadJobDetail(jobId)
            } catch (e: Exception) {
                // handle error
            }
        }
    }
    
    fun updateJobStatus(jobId: Int, action: String, onComplete: () -> Unit = {}) {
        viewModelScope.launch {
            try {
                when (action) {
                    "accept" -> repository.acceptPrintJob(jobId)
                    "start" -> repository.startPrintJob(jobId)
                    "complete" -> repository.completePrintJob(jobId)
                }
                loadJobDetail(jobId)
                onComplete()
            } catch (e: Exception) {
                // handle error
            }
        }
    }
}
