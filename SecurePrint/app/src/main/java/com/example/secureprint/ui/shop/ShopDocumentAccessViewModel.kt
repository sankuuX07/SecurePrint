package com.example.secureprint.ui.shop

import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.TemporaryDocumentAccessResponse
import com.example.secureprint.data.repository.ShopDocumentAccessRepository
import com.example.secureprint.util.SecureFileDownloader
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

class ShopDocumentAccessViewModel(application: Application) : AndroidViewModel(application) {
    private val api = RetrofitClient.shopDocumentAccessApi
    private val repository = ShopDocumentAccessRepository(api)
    private val downloader = SecureFileDownloader(application, repository)

    private val _accessState = MutableStateFlow<AccessState>(AccessState.Idle)
    val accessState: StateFlow<AccessState> = _accessState.asStateFlow()
    
    private val _currentAccess = MutableStateFlow<TemporaryDocumentAccessResponse?>(null)
    val currentAccess: StateFlow<TemporaryDocumentAccessResponse?> = _currentAccess.asStateFlow()

    fun testGrantAccess(jobId: Int) {
        viewModelScope.launch {
            _accessState.value = AccessState.Loading
            try {
                val response = repository.testGrantAccess(jobId)
                if (response.isSuccessful && response.body() != null) {
                    _currentAccess.value = response.body()
                    _accessState.value = AccessState.Granted
                } else {
                    _accessState.value = AccessState.Error("Failed to request access: ${response.message()}")
                }
            } catch (e: Exception) {
                _accessState.value = AccessState.Error(e.message ?: "Unknown error")
            }
        }
    }
    
    fun getAccessMetadata(accessId: String) {
        viewModelScope.launch {
            try {
                val response = repository.getAccessMetadata(accessId)
                if (response.isSuccessful && response.body() != null) {
                    _currentAccess.value = response.body()
                    _accessState.value = AccessState.Granted
                }
            } catch (e: Exception) {
                // Background update failed, ignore or log
                Log.e("ShopDocAccessVM", "Failed to update metadata", e)
            }
        }
    }

    fun downloadAndOpenDocument(accessId: String, originalFilename: String) {
        viewModelScope.launch {
            _accessState.value = AccessState.Downloading
            try {
                val file = downloader.downloadSecureDocument(accessId, originalFilename)
                if (file != null) {
                    _accessState.value = AccessState.Downloaded(file)
                    openDocument(file)
                } else {
                    _accessState.value = AccessState.Error("Failed to download document securely.")
                }
            } catch (e: Exception) {
                _accessState.value = AccessState.Error(e.message ?: "Download error")
            }
        }
    }
    
    private fun openDocument(file: File) {
        try {
            val context = getApplication<Application>()
            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf") // Ensure PDF viewing
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            _accessState.value = AccessState.Error("No application found to view PDF files.")
        } catch (e: Exception) {
            _accessState.value = AccessState.Error("Could not open document: ${e.message}")
        }
    }

    override fun onCleared() {
        super.onCleared()
        // Clear secure cache when ViewModel is destroyed (e.g. user leaves the screen)
        viewModelScope.launch {
            downloader.clearSecureCache()
        }
    }
}

sealed class AccessState {
    object Idle : AccessState()
    object Loading : AccessState()
    object Granted : AccessState()
    object Downloading : AccessState()
    data class Downloaded(val file: File) : AccessState()
    data class Error(val message: String) : AccessState()
}
