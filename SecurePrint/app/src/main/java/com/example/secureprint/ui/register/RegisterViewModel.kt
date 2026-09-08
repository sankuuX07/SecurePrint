package com.example.secureprint.ui.register

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.model.RegisterRequest
import com.example.secureprint.data.model.UserResponse
import com.example.secureprint.data.repository.AuthRepository
import kotlinx.coroutines.launch

sealed class RegisterUiState {
    object Idle : RegisterUiState()
    object Loading : RegisterUiState()
    data class Success(val response: UserResponse) : RegisterUiState()
    data class Error(val message: String) : RegisterUiState()
}

class RegisterViewModel(
    private val repository: AuthRepository = AuthRepository()
) : ViewModel() {

    var uiState by mutableStateOf<RegisterUiState>(RegisterUiState.Idle)
        private set

    fun register(request: RegisterRequest) {
        viewModelScope.launch {
            uiState = RegisterUiState.Loading
            try {
                val response = repository.register(request)
                if (response.isSuccessful && response.body() != null) {
                    uiState = RegisterUiState.Success(response.body()!!)
                } else {
                    uiState = RegisterUiState.Error("Registration failed: ${response.message()}")
                }
            } catch (e: Exception) {
                uiState = RegisterUiState.Error("An error occurred: ${e.localizedMessage}")
            }
        }
    }

    fun resetState() {
        uiState = RegisterUiState.Idle
    }
}
