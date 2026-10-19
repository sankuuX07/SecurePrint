package com.example.secureprint.ui.login

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.api.NetworkErrorParser
import com.example.secureprint.data.model.AuthResponse
import com.example.secureprint.data.repository.AuthRepository
import kotlinx.coroutines.launch

sealed class LoginUiState {
    object Idle : LoginUiState()
    object Loading : LoginUiState()
    data class Success(val response: AuthResponse) : LoginUiState()
    data class Error(val message: String) : LoginUiState()
}

class LoginViewModel(
    private val repository: AuthRepository = AuthRepository()
) : ViewModel() {

    var uiState by mutableStateOf<LoginUiState>(LoginUiState.Idle)
        private set

    fun login(email: String, password: String) {
        viewModelScope.launch {
            uiState = LoginUiState.Loading
            try {
                val response = repository.login(email.trim(), password)
                if (response.isSuccessful && response.body() != null) {
                    uiState = LoginUiState.Success(response.body()!!)
                } else {
                    val errorMsg = NetworkErrorParser.parseError(response, "Login failed")
                    uiState = LoginUiState.Error(errorMsg)
                }
            } catch (e: Exception) {
                val errorMsg = NetworkErrorParser.parseException(e)
                uiState = LoginUiState.Error(errorMsg)
            }
        }
    }

    fun resetState() {
        uiState = LoginUiState.Idle
    }
}
