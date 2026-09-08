package com.example.secureprint.ui.customer

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.PrintJobDetailResponse
import com.example.secureprint.data.model.PrintJobResponse
import com.example.secureprint.data.repository.PrintJobRepository
import kotlinx.coroutines.launch

sealed class PrintJobsUiState {
    object Loading : PrintJobsUiState()
    data class Success(val jobs: List<PrintJobResponse>, val isPaginating: Boolean = false) : PrintJobsUiState()
    data class Error(val message: String) : PrintJobsUiState()
}

sealed class PrintJobDetailUiState {
    object Loading : PrintJobDetailUiState()
    data class Success(val job: PrintJobDetailResponse) : PrintJobDetailUiState()
    data class Error(val message: String) : PrintJobDetailUiState()
}

class PrintJobViewModel : ViewModel() {
    private val repository = PrintJobRepository(RetrofitClient.printJobApi)
    
    var listUiState by mutableStateOf<PrintJobsUiState>(PrintJobsUiState.Loading)
        private set
        
    var detailUiState by mutableStateOf<PrintJobDetailUiState>(PrintJobDetailUiState.Loading)
        private set
        
    private var currentPage = 1
    private var currentStatusFilter: String? = null
    
    fun loadJobs(status: String? = null, reset: Boolean = false) {
        if (reset) {
            currentPage = 1
            currentStatusFilter = status
            listUiState = PrintJobsUiState.Loading
        } else {
            val currentState = listUiState
            if (currentState is PrintJobsUiState.Success) {
                listUiState = currentState.copy(isPaginating = true)
            }
        }
        
        viewModelScope.launch {
            try {
                val jobs = repository.getCustomerPrintJobs(status = currentStatusFilter, page = currentPage)
                val currentState = listUiState
                if (!reset && currentState is PrintJobsUiState.Success) {
                    listUiState = PrintJobsUiState.Success(currentState.jobs + jobs)
                } else {
                    listUiState = PrintJobsUiState.Success(jobs)
                }
                if (jobs.isNotEmpty()) currentPage++
            } catch (e: Exception) {
                if (reset) {
                    listUiState = PrintJobsUiState.Error(e.message ?: "Unknown error")
                } else {
                    val currentState = listUiState
                    if (currentState is PrintJobsUiState.Success) {
                        listUiState = currentState.copy(isPaginating = false)
                    }
                }
            }
        }
    }
    
    fun loadJobDetail(jobId: Int) {
        detailUiState = PrintJobDetailUiState.Loading
        viewModelScope.launch {
            try {
                val detail = repository.getCustomerPrintJobDetail(jobId)
                detailUiState = PrintJobDetailUiState.Success(detail)
            } catch (e: Exception) {
                detailUiState = PrintJobDetailUiState.Error(e.message ?: "Failed to load detail")
            }
        }
    }
    
    fun cancelJob(jobId: Int, onComplete: () -> Unit) {
        viewModelScope.launch {
            try {
                repository.cancelPrintJob(jobId)
                loadJobDetail(jobId) // refresh detail
                onComplete()
            } catch (e: Exception) {
                // Ignore for now or handle via UI events
            }
        }
    }
}
