package com.example.secureprint.ui.login

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
                val response = repository.login(email, password)
                if (response.isSuccessful && response.body() != null) {
                    uiState = LoginUiState.Success(response.body()!!)
                } else {
                    val errorMsg = when (response.code()) {
                        400 -> "Incorrect email or password"
                        403 -> "Account pending approval or inactive"
                        else -> "Login failed: ${response.message()}"
                    }
                    uiState = LoginUiState.Error(errorMsg)
                }
            } catch (e: Exception) {
                uiState = LoginUiState.Error("An error occurred: ${e.localizedMessage}")
            }
        }
    }

    fun resetState() {
        uiState = LoginUiState.Idle
    }
}
