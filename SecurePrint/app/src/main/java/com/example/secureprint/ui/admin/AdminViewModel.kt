package com.example.secureprint.ui.admin

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.model.UserResponse
import com.example.secureprint.data.repository.AuthRepository
import kotlinx.coroutines.launch

sealed class AdminUiState {
    object Idle : AdminUiState()
    object Loading : AdminUiState()
    data class Success(val shops: List<UserResponse>) : AdminUiState()
    data class Error(val message: String) : AdminUiState()
}

class AdminViewModel(
    private val repository: AuthRepository = AuthRepository()
) : ViewModel() {

    var uiState by mutableStateOf<AdminUiState>(AdminUiState.Idle)
        private set

    fun loadPendingShops() {
        viewModelScope.launch {
            uiState = AdminUiState.Loading
            try {
                val response = repository.getPendingShops()
                if (response.isSuccessful && response.body() != null) {
                    uiState = AdminUiState.Success(response.body()!!)
                } else {
                    uiState = AdminUiState.Error("Failed to load shops: ${response.message()}")
                }
            } catch (e: Exception) {
                uiState = AdminUiState.Error("An error occurred: ${e.localizedMessage}")
            }
        }
    }

    fun approveShop(shopId: Int) {
        viewModelScope.launch {
            try {
                val response = repository.approveShop(shopId)
                if (response.isSuccessful) {
                    loadPendingShops()
                }
            } catch (e: Exception) {
                // Handle error
            }
        }
    }

    fun rejectShop(shopId: Int) {
        viewModelScope.launch {
            try {
                val response = repository.rejectShop(shopId)
                if (response.isSuccessful) {
                    loadPendingShops()
                }
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
