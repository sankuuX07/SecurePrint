package com.example.secureprint.ui.admin

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

sealed class AdminJobsUiState {
    object Loading : AdminJobsUiState()
    data class Success(val jobs: List<PrintJobResponse>, val isPaginating: Boolean = false) : AdminJobsUiState()
    data class Error(val message: String) : AdminJobsUiState()
}

sealed class AdminJobDetailUiState {
    object Loading : AdminJobDetailUiState()
    data class Success(val job: PrintJobDetailResponse) : AdminJobDetailUiState()
    data class Error(val message: String) : AdminJobDetailUiState()
}

class AdminJobsViewModel : ViewModel() {
    private val repository = PrintJobRepository(RetrofitClient.printJobApi)
    
    var listUiState by mutableStateOf<AdminJobsUiState>(AdminJobsUiState.Loading)
        private set
        
    var detailUiState by mutableStateOf<AdminJobDetailUiState>(AdminJobDetailUiState.Loading)
        private set
        
    private var currentPage = 1
    private var currentStatusFilter: String? = null
    
    fun loadJobs(status: String? = null, reset: Boolean = false) {
        if (reset) {
            currentPage = 1
            currentStatusFilter = status
            listUiState = AdminJobsUiState.Loading
        } else {
            val currentState = listUiState
            if (currentState is AdminJobsUiState.Success) {
                listUiState = currentState.copy(isPaginating = true)
            }
        }
        
        viewModelScope.launch {
            try {
                val jobs = repository.getAdminPrintJobs(status = currentStatusFilter, page = currentPage)
                val currentState = listUiState
                if (!reset && currentState is AdminJobsUiState.Success) {
                    listUiState = AdminJobsUiState.Success(currentState.jobs + jobs)
                } else {
                    listUiState = AdminJobsUiState.Success(jobs)
                }
                if (jobs.isNotEmpty()) currentPage++
            } catch (e: Exception) {
                if (reset) {
                    listUiState = AdminJobsUiState.Error(e.message ?: "Unknown error")
                } else {
                    val currentState = listUiState
                    if (currentState is AdminJobsUiState.Success) {
                        listUiState = currentState.copy(isPaginating = false)
                    }
                }
            }
        }
    }
    
    fun loadJobDetail(jobId: Int) {
        detailUiState = AdminJobDetailUiState.Loading
        viewModelScope.launch {
            try {
                val detail = repository.getAdminPrintJobDetail(jobId)
                detailUiState = AdminJobDetailUiState.Success(detail)
            } catch (e: Exception) {
                detailUiState = AdminJobDetailUiState.Error(e.message ?: "Failed to load detail")
            }
        }
    }
}
