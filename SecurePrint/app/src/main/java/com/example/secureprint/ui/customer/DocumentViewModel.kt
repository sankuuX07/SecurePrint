package com.example.secureprint.ui.customer

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.model.DocumentResponse
import com.example.secureprint.data.repository.DocumentRepository
import kotlinx.coroutines.launch
import okhttp3.MultipartBody

sealed class DocumentUiState {
    object Idle : DocumentUiState()
    object Loading : DocumentUiState()
    data class Success(val documents: List<DocumentResponse>) : DocumentUiState()
    data class Error(val message: String) : DocumentUiState()
}

class DocumentViewModel(
    private val repository: DocumentRepository = DocumentRepository()
) : ViewModel() {

    var uiState by mutableStateOf<DocumentUiState>(DocumentUiState.Idle)
        private set
        
    var searchQuery by mutableStateOf("")
        private set
        
    var statusFilter by mutableStateOf<String?>(null)
        private set
        
    var deleteError by mutableStateOf<String?>(null)
        private set

    fun updateSearchQuery(query: String) {
        searchQuery = query
        loadDocuments()
    }
    
    fun updateStatusFilter(status: String?) {
        statusFilter = status
        loadDocuments()
    }
    
    fun clearDeleteError() {
        deleteError = null
    }

    fun loadDocuments() {
        viewModelScope.launch {
            uiState = DocumentUiState.Loading
            uiState = try {
                val response = repository.getMyDocuments(statusFilter, searchQuery.ifBlank { null })
                if (response.isSuccessful && response.body() != null) {
                    DocumentUiState.Success(response.body()!!)
                } else {
                    DocumentUiState.Error("Failed to load documents: ${response.message()}")
                }
            } catch (e: Exception) {
                DocumentUiState.Error("An error occurred: ${e.localizedMessage}")
            }
        }
    }

    fun uploadDocument(filePart: MultipartBody.Part) {
        viewModelScope.launch {
            uiState = DocumentUiState.Loading
            try {
                val response = repository.uploadDocument(filePart)
                if (response.isSuccessful) {
                    loadDocuments()
                } else {
                    uiState = DocumentUiState.Error("Upload failed: ${response.message()}")
                }
            } catch (e: Exception) {
                uiState = DocumentUiState.Error("An error occurred: ${e.localizedMessage}")
            }
        }
    }
    
    fun deleteDocument(id: String) {
        viewModelScope.launch {
            try {
                val response = repository.deleteDocument(id)
                if (response.isSuccessful) {
                    loadDocuments()
                } else {
                    deleteError = "Failed to delete: ${response.message()}"
                }
            } catch (e: Exception) {
                deleteError = "An error occurred: ${e.localizedMessage}"
            }
        }
    }
}
