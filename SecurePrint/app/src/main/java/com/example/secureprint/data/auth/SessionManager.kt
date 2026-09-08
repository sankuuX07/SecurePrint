package com.example.secureprint.data.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed class AuthState {
    object LoggedOut : AuthState()
    data class LoggedIn(val role: String) : AuthState()
}

object SessionManager {
    private const val PREFS_NAME = "secureprint_prefs"
    private const val KEY_TOKEN = "auth_token"
    private const val KEY_ROLE = "user_role"

    private lateinit var sharedPreferences: SharedPreferences

    private val _authState = MutableStateFlow<AuthState>(AuthState.LoggedOut)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    private val _logoutEvent = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val logoutEvent = _logoutEvent.asSharedFlow()

    fun init(context: Context) {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        
        sharedPreferences = EncryptedSharedPreferences.create(
            PREFS_NAME,
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )

        // Restore state on init
        val savedRole = getRole()
        if (getToken() != null && savedRole != null) {
            _authState.value = AuthState.LoggedIn(savedRole)
        }
    }

    fun saveSession(token: String, role: String) {
        sharedPreferences.edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_ROLE, role)
            .apply()
        _authState.value = AuthState.LoggedIn(role)
    }

    fun getToken(): String? = sharedPreferences.getString(KEY_TOKEN, null)

    fun getRole(): String? = sharedPreferences.getString(KEY_ROLE, null)

    fun clearSession() {
        sharedPreferences.edit().clear().apply()
        _authState.value = AuthState.LoggedOut
    }

    fun forceLogout() {
        if (_authState.value !is AuthState.LoggedOut) {
            clearSession()
            _logoutEvent.tryEmit(Unit)
        }
    }
}
